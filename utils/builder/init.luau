local fs = require("@lune/fs")
local process = require("@lune/process")
local regex = require("@lune/regex")
local task = require("@lune/task")

local LUAU_GIT_HASH, LUAU_GIT_TAG = (function()
    local GIT_EXEC_OPTIONS = {
        cwd = "./luau"
    }

    local git_hash_proc = process.exec(
        "git", {"rev-parse", "HEAD"},
        GIT_EXEC_OPTIONS
    )
    if not git_hash_proc.ok then
        return error("Failed to get git commit hash of luau submodule!")
    end

    local git_tag_proc = process.exec(
        "git", {"describe", "--tags"},
        GIT_EXEC_OPTIONS
    )
    if not git_tag_proc.ok then
        return error("Failed to get git tag name of luau submodule!")
    end

    return string.gsub(git_hash_proc.stdout, "[\r\n]+", ""),
        (string.gsub(git_tag_proc.stdout, "[\r\n]+", "") or "UNKNOWN_TAG")
end)()

local WASYNTH_EXEC = "./utils/wasm2luau"
local WASM_OUTPUT_DIR = "./build"
local BUILD_DIR = "./output"

local FILE_PREFIX = "Luau.LuauCeption"

local function createHeaderSnippet(variant: BuildVariant): string
    local result = {
        `--// LuauCeption - {variant} Variant`,
        `--// Build from Luau {LUAU_GIT_TAG} ({LUAU_GIT_HASH})`,
        "\nlocal STUB_WARN = false\n",
    }
    return table.concat(result, "\n")
end

local VARIANT_BUILD_SNIPPET_ORDER = {
    ["Compiler"] = {
        {"goto", "end", "--!optimize 2"},
        {"putstring", createHeaderSnippet("Compiler")},
        {"putfile", "Common/vector3_compat.luau"},

        {"goto", "start", "return function\\(wasm\\)"},
        {"remove_to_end"},
        {"putfile", "Common/runtime_export.luau"},
        {"putfile", "Compiler/init.luau"},

        {"goto", "start", "--@@UTILS@@"},
        {"removeline"},
        {"putfile", "Common/utils.luau"},

        {"goto", "start", "--@@FLAGS@@"},
        {"removeline"},
        {"putfile", "Common/flags.luau"},
    },
    ["VM"] = {
        {"goto", "end", "--!optimize 2"},
        {"putstring", createHeaderSnippet("VM")},
        {"putfile", "Common/vector3_compat.luau"},

        {"goto", "start", "return function\\(wasm\\)"},
        {"remove_to_end"},
        {"putfile", "Common/runtime_export.luau"},
        {"putfile", "VM/init.luau"},

        {"goto", "start", "--@@MACROS@@"},
        {"removeline"},
        {"putfile", "VM/luau_macros.luau"},

        {"goto", "start", "--@@UTILS@@"},
        {"removeline"},
        {"putfile", "Common/utils.luau"},

        {"goto", "start", "--@@FLAGS@@"},
        {"removeline"},
        {"putfile", "Common/flags.luau"},
    },
    ["Full"] = {
        {"goto", "end", "--!optimize 2"},
        {"putstring", createHeaderSnippet("Full")},
        {"putfile", "Common/vector3_compat.luau"},

        {"goto", "start", "return function\\(wasm\\)"},
        {"remove_to_end"},
        {"putfile", "Common/runtime_export.luau"},
        {"putfile", "Full/init.luau"},

        {"goto", "start", "--@@MACROS@@"},
        {"removeline"},
        {"putfile", "VM/luau_macros.luau"},

        {"goto", "start", "--@@UTILS@@"},
        {"removeline"},
        {"putfile", "Common/utils.luau"},

        {"goto", "start", "--@@FLAGS@@"},
        {"removeline"},
        {"putfile", "Common/flags.luau"},
    },
}

local function getAbsolutePath(relative_path: string): string
    return `{process.cwd}/{relative_path}`
end

local function processSnippetOrder(snippet_orders: {{string}}, to_process: string): string
    local current_position = 0
    local result = to_process

    for _, order in snippet_orders do
        local command = order[1]

        if command == "goto" then
            local pattern = regex.new(order[3]):find(result)
            if not pattern then
                print(`Cannot find pattern '{order[3]}' on goto command`)
                continue
            end

            local position_mode = order[2]
            if position_mode == "start" then
                current_position = pattern.start
            elseif position_mode == "end" then
                current_position = pattern.finish + 1
            end
        elseif command == "remove_to_end" then
            result = string.sub(result, 1, current_position - 1)
        elseif command == "removeline" then
            local str_start = string.sub(result, 1, current_position)
            local str_end = string.sub(result, current_position)
            local pre = string.match(str_start, "^(.*)\n[^\n]*$") or ""
            local post = string.match(str_end, "^[^\n]*\n?(.*)$") or ""
            local corrected_pos = string.match(string.sub(result, 1, current_position - 1), ".*()\n")

            result = pre .. post
            current_position = corrected_pos or current_position
        elseif command == "putstring" or command == "putfile" then
            local content = order[2]
            if command == "putfile" then
                local file_path = getAbsolutePath(`./snippets/{order[2]}`)
                if not fs.isFile(file_path) then
                    return error(`Cannot find assigned file '{order[2]}' on putfile command!`)
                end

                content = fs.readFile(file_path)
            end

            local content_len = (utf8.len(content) :: number) + 1
            local str_start = string.sub(result, 1, current_position)
            local str_end = string.sub(result, current_position)

            result = str_start .. content .. "\n" .. str_end
            current_position += content_len
        end
    end
    return result
end

type BuildVariant = "Compiler" | "VM" | "Full"
local function createBuildVariant(variant: BuildVariant)
    local snippet_orders = VARIANT_BUILD_SNIPPET_ORDER[variant]
    if not snippet_orders then
        return error(`Invalid variant type '{variant}'`)
    end

    local file_name = `{FILE_PREFIX}.{variant}`
    local wasm_file = getAbsolutePath(`{WASM_OUTPUT_DIR}/{file_name}.wasm`)

    if not fs.isFile(wasm_file) then
        return error(`Build file of variant '{variant}' not found!`)
    end

    local wasynth_proc = process.create(WASYNTH_EXEC, {wasm_file})
    local wasynth_output = wasynth_proc.stdout:readToEnd()

    local processed_output = processSnippetOrder(snippet_orders, wasynth_output)
    if not processed_output then
        return error(`Failed to process variant '{variant}'`)
    end

    print(`Variant '{variant}' got wasm transpiled to luau successfully.`)
    fs.writeFile(getAbsolutePath(`{BUILD_DIR}/{file_name}.luau`), processed_output)
    print(`Variant '{variant}' processed successfully.`)
    return
end

do
    if not fs.isDir(getAbsolutePath(BUILD_DIR)) then
        fs.writeDir(getAbsolutePath(BUILD_DIR))
    end
    
    for _, variant in {"Compiler", "VM", "Full"} do
        createBuildVariant(variant)
    end
end
