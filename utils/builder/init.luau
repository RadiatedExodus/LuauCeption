local fs = require("@lune/fs")
local process = require("@lune/process")
local regex = require("@lune/regex")

local FLAGS = {
    -- this workaround is temporary!!!
    -- see: https://github.com/seaofvoices/darklua/pull/300
    EXPERIMENTAL_BUNDLED_MODULES_TYPES_FIX = true,
}

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

type BuildVariant = "Compiler" | "VM" | "Full"
type SnippetOrder = {any}
type VariantSnippetInstructions = {
    runtime: SnippetOrder,
    entrypoint: SnippetOrder
}

local WASYNTH_EXEC = "./utils/wasm2luau"
local WASM_OUTPUT_DIR = "./build"
local BUILD_DIR = "./output"

local VARIANT_PREFIX = "Luau.LuauCeption"

local function getRokitExec(exec: string): string
	if process.os == "windows" then
		return exec
	end

	return `{process.env["HOME"]}/.rokit/bin/{exec}`
end

local function createHeaderSnippet(variant: BuildVariant): string
    local result = {
        `--// LuauCeption - {variant} Variant`,
        `--// Build from Luau {LUAU_GIT_TAG} ({LUAU_GIT_HASH})\n\n`,
    }
    return table.concat(result, "\n")
end

local DARKLUA_PATCHES = {
    ["IMPORT_PATTERN"] = "__LUAUCEPTION__\\.load\\('([\\w+])'\\)",
    ["IMPORT_REPLACEMENT"] = "__LUAUCEPTION__[\"$1\"]()",
    ["IMPORT_LOADER"] =[[
local __CACHE__LUAUCEPTION__ = {}
local __LUAUCEPTION__ = setmetatable({}, {
    __index = function(self, m)
        if not __CACHE__LUAUCEPTION__[m] then
            local module = rawget(self, m)()
            __CACHE__LUAUCEPTION__[m] = function()
                return module
            end
        end
        return __CACHE__LUAUCEPTION__[m] or rawget(self, m)
    end
})
]],
}
local VARIANT_BUILD_SNIPPET_ORDER: {[string]: VariantSnippetInstructions} = {
    ["Compiler"] = {
        ["runtime"] = {
            {"goto", "end", "--!optimize 2\n"},
            {"putstring", createHeaderSnippet("Compiler")},
            {"putfile", "Common/vector3_compat.luau"},
        },
        ["entrypoint"] = {
            {"putfile", "Compiler/entrypoint.luau"},
            {"process", "./utils/builder/build.darklua.json"},

            {"gotopos", 1},
            {"putstring", "--!optimize 2\n"},
            {"putstring", createHeaderSnippet("Compiler")},
            {"putstring", "local STUB_WARN = false\n"},

            {"pcjumpif", 4, not FLAGS.EXPERIMENTAL_BUNDLED_MODULES_TYPES_FIX},
            {"goto", "start", "local __LUAUCEPTION__"},
            {"removelines", 14},
            {"putstring", DARKLUA_PATCHES.IMPORT_LOADER},
            {"replaceall", DARKLUA_PATCHES.IMPORT_PATTERN, DARKLUA_PATCHES.IMPORT_REPLACEMENT}
        },
    },
    ["VM"] = {
        ["runtime"] = {
            {"goto", "end", "--!optimize 2\n"},
            {"putstring", createHeaderSnippet("VM")},
            {"putfile", "Common/vector3_compat.luau"},
        },
        ["entrypoint"] = {
            {"putfile", "VM/entrypoint.luau"},
            {"process", "./utils/builder/build.darklua.json"},

            {"gotopos", 1},
            {"putstring", "--!optimize 2\n"},
            {"putstring", createHeaderSnippet("VM")},
            {"putstring", "local STUB_WARN = false\n"},

            {"pcjumpif", 4, not FLAGS.EXPERIMENTAL_BUNDLED_MODULES_TYPES_FIX},
            {"goto", "start", "local __LUAUCEPTION__"},
            {"removelines", 14},
            {"putstring", DARKLUA_PATCHES.IMPORT_LOADER},
            {"replaceall", DARKLUA_PATCHES.IMPORT_PATTERN, DARKLUA_PATCHES.IMPORT_REPLACEMENT}
        },
    },
    ["Full"] = {
        ["runtime"] = {
            {"goto", "end", "--!optimize 2\n"},
            {"putstring", createHeaderSnippet("Full")},
            {"putfile", "Common/vector3_compat.luau"},
        },
        ["entrypoint"] = {
            {"putfile", "Full/entrypoint.luau"},
            {"process", "./utils/builder/build.darklua.json"},

            {"gotopos", 1},
            {"putstring", "--!optimize 2\n"},
            {"putstring", createHeaderSnippet("Full")},
            {"putstring", "local STUB_WARN = false\n"},

            {"pcjumpif", 4, not FLAGS.EXPERIMENTAL_BUNDLED_MODULES_TYPES_FIX},
            {"goto", "start", "local __LUAUCEPTION__"},
            {"removelines", 14},
            {"putstring", DARKLUA_PATCHES.IMPORT_LOADER},
            {"replaceall", DARKLUA_PATCHES.IMPORT_PATTERN, DARKLUA_PATCHES.IMPORT_REPLACEMENT}
        },
    },
}

local function getAbsolutePath(relative_path: string): string
    return `{process.cwd}/{relative_path}`
end

local function processSnippetOrder(snippet_orders: {{string}}, to_process: string): string
    local pc, contentpos = 0, 0
    local result = to_process

    while pc < #snippet_orders do
        pc += 1
        local order = snippet_orders[pc]
        local command = table.remove(order, 1)

        if command == "goto" then
            local pattern = regex.new(order[2]):find(result)
            if not pattern then
                print(`Cannot find pattern '{order[2]}' on goto command`)
                continue
            end

            local position_mode = order[1]
            if position_mode == "start" then
                contentpos = pattern.start
            elseif position_mode == "end" then
                contentpos = pattern.finish + 1
            end
        elseif command == "pcjumpif" then
            local pos_offset, flag = unpack(order)

            if flag then
                pc += pos_offset
            end
        elseif command == "gotopos" then
            contentpos = order[1]
        elseif command == "removeline" then
            local str_start = string.sub(result, 1, contentpos - 1)
            local str_end = string.sub(result, contentpos)
            local pre = string.match(str_start, "^(.*)\n[^\n]*$") or ""
            local post = string.match(str_end, "^[^\n]*\n?(.*)$") or ""
            local corrected_pos = string.match(str_start, ".*()\n")

            result = pre .. post
            contentpos = corrected_pos or contentpos
        elseif command == "removelines" then
            local current_str = string.sub(result, contentpos)
            local newline_pos = 0

            for _ = 1, order[1] do
                local start_pos, end_pos = string.find(current_str, "[^\n]*\n", newline_pos + 1)
                if not start_pos then
                    error("Provided line count exceeded!")
                end

                newline_pos = end_pos
            end
            result = string.sub(result, 1, contentpos - 1) .. string.sub(result, contentpos + newline_pos)
        elseif command == "putstring" or command == "putfile" then
            local content = order[1]
            if command == "putfile" then
                local file_path = getAbsolutePath(`./snippets/{order[1]}`)
                if not fs.isFile(file_path) then
                    return error(`Cannot find assigned file '{order[1]}' on putfile command!`)
                end

                content = fs.readFile(file_path) .. "\n"
            end

            local content_len = (utf8.len(content) :: number) + 1
            local str_start = string.sub(result, 1, contentpos - 1)
            local str_end = string.sub(result, contentpos)

            result = str_start .. content .. str_end
            contentpos = #str_start + content_len
        elseif command == "replaceall" then
            local pattern = regex.new(order[1])
            result = pattern:replaceAll(result, order[2])
        elseif command == "process" then
            local temp_dir_path = getAbsolutePath("./snippets/_temp")
            if not fs.isDir(temp_dir_path) then
                fs.writeDir(temp_dir_path)
            end

            local darklua_file_path = getRokitExec("darklua")
            if not fs.isFile(darklua_file_path) then
                return error("Cannot find darklua executable file which is needed on process command!")
            end

            local config_file = getAbsolutePath(order[1])
            if not fs.isFile(config_file) then
                return error(`Cannot find provided darklua config file '{order[1]}' on process command!`)
            end

            local process_id = os.time()
            local temp_file_path = `{temp_dir_path}/__{process_id}.luau`
            local temp_file_result_path = getAbsolutePath(`./utils/builder/_tempresult{process_id}.luau`)

            fs.writeFile(temp_file_path, result)

            local exec_result = process.exec(
                darklua_file_path,
                {
                    "process",
                    temp_file_path,
                    temp_file_result_path,
                    "-c",
                    config_file
                }
            )
            if exec_result.ok then
                result = fs.readFile(temp_file_result_path)
                fs.removeFile(temp_file_path)
                fs.removeFile(temp_file_result_path)
            else
                fs.readFile(temp_file_path)
                return error(`Process command failed, log:\n{exec_result.stderr}`, 0)
            end
        else
            error(`Unknown instruction '{order}' provided!`)
        end
    end
    return result
end

local function createBuildVariant(variant: BuildVariant)
    local snippet_orders = VARIANT_BUILD_SNIPPET_ORDER[variant]
    if not snippet_orders then
        return error(`Invalid variant type '{variant}'`)
    end

    local variant_id = `{VARIANT_PREFIX}.{variant}`
    local wasm_file = getAbsolutePath(`{WASM_OUTPUT_DIR}/{variant_id}.wasm`)
    local variant_container = getAbsolutePath(`{BUILD_DIR}/{variant_id}`)

    if not fs.isFile(wasm_file) then
        return error(`Variant '{variant}' WASM output not found!`)
    end

    local wasynth_proc = process.create(WASYNTH_EXEC, {wasm_file})
    local wasynth_output = wasynth_proc.stdout:readToEnd()
    if not wasynth_proc:status().ok then
        return error(`Failed to transpile WASM output of variant '{variant}'`)
    end
    print(`Variant '{variant}' got transpiled to luau successfully.`)

    if not fs.isDir(variant_container) then
        fs.writeDir(variant_container)
    end

    local processed_runtime = processSnippetOrder(snippet_orders.runtime, wasynth_output)
    if not processed_runtime then
        return error(`Failed to process runtime of variant '{variant}'`)
    end
    print(`Successfully processed transpiled runtime of variant '{variant}'!`)
    fs.writeFile(`{variant_container}/runtime.luau`, processed_runtime)

    local processed_entrypoint = processSnippetOrder(snippet_orders.entrypoint, "")
    if not processed_entrypoint then
        return error(`Failed to process variant '{variant}'`)
    end
    print(`Successfully processed entrypoint of variant '{variant}'!`)
    fs.writeFile(`{variant_container}/init.luau`, processed_entrypoint)
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
