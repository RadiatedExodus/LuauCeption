local fs = require("@lune/fs")
local process = require("@lune/process")
local regex = require("@lune/regex")

local argparse = require("@self/argparse/src/lib")

local VALID_FLAGS = {
    -- combines runtime and entrypoint into one file
    "BUILD_ONEFILE",
}

local PARSER = argparse("luauceptionbuilder")
PARSER:option("-f --flags", "Flags applied for this building process.", nil, nil, "*"):convert(function(value)
    if not table.find(VALID_FLAGS, value) then
        print(`[WARN]: Flag '{value}' is not defined as valid flag!`)
    end

    return value
end)
-- example: lune run utils/builder -f FLAG1 FLAG2 FLAG3

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

type BuilderFlags = {string}
type BuildVariant = "Compiler" | "VM" | "Full"
type SnippetOrder = {any}
type VariantSnippetInstructions = {
    runtime: SnippetOrder,
    entrypoint: SnippetOrder
}

local WASM2LUAU_EXEC: string? = (function()
    local STATIC_PATH = "./utils/wasm2luau"
    if fs.isFile(STATIC_PATH) then
        return STATIC_PATH
    end

    local which_process = process.exec("which", {"wasm2luau"})
    if not which_process.ok then
        return
    end

    return string.gsub(which_process.stdout, "[%s]+", "")
end)()

local HOME_VARIABLE = 
    if process.os == "windows" then process.env["USERPROFILE"]
    else process.env["HOME"]

local WASM_OUTPUT_DIR = "./build"
local BUILD_DIR = "./output"

local VARIANT_PREFIX = "Luau.LuauCeption"

local function getRokitExec(exec: string): string
	return `{HOME_VARIABLE}/.rokit/bin/{exec}`
end

local function createHeaderSnippet(variant: BuildVariant): string
    local result = {
        `--// LuauCeption - {variant} Variant`,
        `--// Built from Luau {LUAU_GIT_TAG} ({LUAU_GIT_HASH})\n\n`,
    }
    return table.concat(result, "\n")
end

local CONTENT_VARIABLE = newproxy(false)

local FLAGGED_PATCHES = {
    ["BUILD_ONEFILE"] = {
        ["IMPORT_PATTERN"] = "\\(require\\)\\(['\"]@self\\/runtime['\"]\\)",
        ["IMPORT_REPLACEMENT"] = "__LUAUCEPTION_RUNTIME__",
        ["RUNTIME_REPLACEMENT"] = "&RUNTIME&",
        ["ENCAPSULATION_CODE"] = "local __LUAUCEPTION_RUNTIME__ = (function()\n\n&RUNTIME&\nend)()\n",
    },
}

local FLAGGED_PATCHES_SNIPPET_ORDER = {
    ["BUILD_ONEFILE"] = {
        {"gotoline", 5},
        {"putstring", "\n\n"},
        {"putstring", FLAGGED_PATCHES.BUILD_ONEFILE.ENCAPSULATION_CODE},
        {"replaceall", FLAGGED_PATCHES.BUILD_ONEFILE.IMPORT_PATTERN, FLAGGED_PATCHES.BUILD_ONEFILE.IMPORT_REPLACEMENT},
        -- we can't use the replaceall instruction here because
        -- file would be modified by the regex, removing regex-unsafe strings
        -- which makes the runtime have unexpected errors
        {"goto", "end", FLAGGED_PATCHES.BUILD_ONEFILE.RUNTIME_REPLACEMENT},
        {"removelinecursor"},
        {"putstring", CONTENT_VARIABLE, "LUAUCEPTION_RUNTIME"},
    }
}

local VARIANT_BUILD_SNIPPET_ORDER: {[string]: VariantSnippetInstructions} = {
    ["Compiler"] = {
        ["runtime"] = {
            {"jmpifflag", 2, "BUILD_ONEFILE", "defined"},
            {"goto", "end", "--!optimize 2\n"},
            {"putstring", createHeaderSnippet("Compiler")},
            {"jmpifflag", 2, "BUILD_ONEFILE", "undefined"},
            {"gotopos", 1},
            {"removelinecursor"},
            {"putfile", "Common/vector3_compat.luau"},
        },
        ["entrypoint"] = {
            {"putfile", "Compiler/entrypoint.luau"},
            {"process", "./src/builder/build.darklua.json"},

            {"gotopos", 1},
            {"putstring", "--!optimize 2\n"},
            {"putstring", createHeaderSnippet("Compiler")},
            {"putstring", "local STUB_WARN = false\n"},
        },
    },
    ["VM"] = {
        ["runtime"] = {
            {"jmpifflag", 2, "BUILD_ONEFILE", "defined"},
            {"goto", "end", "--!optimize 2\n"},
            {"putstring", createHeaderSnippet("Compiler")},
            {"jmpifflag", 2, "BUILD_ONEFILE", "undefined"},
            {"gotopos", 1},
            {"removelinecursor"},
            {"putfile", "Common/vector3_compat.luau"},
        },
        ["entrypoint"] = {
            {"putfile", "VM/entrypoint.luau"},
            {"process", "./src/builder/build.darklua.json"},

            {"gotopos", 1},
            {"putstring", "--!optimize 2\n"},
            {"putstring", createHeaderSnippet("VM")},
            {"putstring", "local STUB_WARN = false\n"},
        },
    },
    ["Full"] = {
        ["runtime"] = {
            {"jmpifflag", 2, "BUILD_ONEFILE", "defined"},
            {"goto", "end", "--!optimize 2\n"},
            {"putstring", createHeaderSnippet("Compiler")},
            {"jmpifflag", 2, "BUILD_ONEFILE", "undefined"},
            {"gotopos", 1},
            {"removelinecursor"},
            {"putfile", "Common/vector3_compat.luau"},
        },
        ["entrypoint"] = {
            {"putfile", "Full/entrypoint.luau"},
            {"process", "./src/builder/build.darklua.json"},

            {"gotopos", 1},
            {"putstring", "--!optimize 2\n"},
            {"putstring", createHeaderSnippet("Full")},
            {"putstring", "local STUB_WARN = false\n"},
        },
    },
}

local function getAbsolutePath(relative_path: string): string
    return `{process.cwd}/{relative_path}`
end

local function processSnippetOrder(
    snippet_orders: {SnippetOrder},
    flags: BuilderFlags,
    variables: {string}?,
    input: string
): (string, number)
    local _VARS: {string} = variables or {}
    local exit_code = 0
    local pc, contentpos = 0, 1
    local result = input

    while true do
        if pc >= #snippet_orders then
            break 
        end

        pc += 1
        local order = table.clone(snippet_orders[pc])
        local command = table.remove(order, 1)

        if command == "goto" then
            local pattern = regex.new(order[2]):find(result)
            if not pattern then
                print(`Cannot find pattern '{order[2]}' on goto command`)
                continue
            end

            local position_mode = order[1]
            if position_mode == "start" then
                contentpos = pattern.start - 1
            elseif position_mode == "end" then
                contentpos = pattern.finish + 1
            end
        elseif command == "runsnippet" then
            local snippets = table.clone(order[1])
            table.move(snippets, 1, #snippets, #snippet_orders, snippet_orders)
        elseif command == "jmpifflag" then
            local pos_offset, flag_name, action = unpack(order)
            if not table.find(VALID_FLAGS, flag_name) then
                print(`[WARN]: Flag '{flag_name}' is not valid flag, but is included in snippet ordering!`)
                continue
            end

            local flag_defined = not not table.find(flags, flag_name)

            if action == "defined" then
                pc += if (flag_defined) then pos_offset else 0
            elseif action == "undefined" then
                pc += if (not flag_defined) then pos_offset else 0
            end
        elseif command == "gotopos" then
            contentpos = order[1]
        elseif command == "gotoline" then
            local newline_pos = 0

            for _ = 1, order[1] do
                local start_pos, end_pos = string.find(result, "[^\n]*\n", newline_pos + 1)
                if not start_pos then
                    error("Provided line count exceeded!")
                end

                newline_pos = end_pos
            end
            contentpos = newline_pos
        elseif command == "removelinecursor" then
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
            local content: string
            if command == "putfile" then
                local file_path = getAbsolutePath(`./snippets/{order[1]}`)
                if not fs.isFile(file_path) then
                    return error(`Cannot find assigned file '{order[1]}' on putfile command!`)
                end

                content = fs.readFile(file_path) .. "\n"
            else
                content = if order[1] == CONTENT_VARIABLE then _VARS[order[2]] else order[1]
            end

            local content_len = (utf8.len(content) :: number) + 1
            local str_start = string.sub(result, 0, contentpos - 1)
            local str_end = string.sub(result, contentpos)

            result = str_start .. content .. str_end
            contentpos = #str_start + content_len
        elseif command == "replaceall" then
            local pattern = regex.new(order[1])
            result = pattern:replaceAll(result, if order[2] == CONTENT_VARIABLE then _VARS[order[3]] else order[2])
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
            local temp_file_result_path = getAbsolutePath(`./utils/_tempresult{process_id}.luau`)

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
            error(`Unknown instruction '{command}' provided!`)
        end
    end
    return result, exit_code
end

local function createBuildVariant(variant: BuildVariant, flags: BuilderFlags)
    local snippet_orders = VARIANT_BUILD_SNIPPET_ORDER[variant]
    if not snippet_orders then
        return error(`Invalid variant type '{variant}'`)
    end

    local variant_id = `{VARIANT_PREFIX}.{variant}`
    local wasm_file = getAbsolutePath(`{WASM_OUTPUT_DIR}/{variant_id}.wasm`)
    local variant_path = getAbsolutePath(`{BUILD_DIR}/{variant_id}`)

    if not fs.isFile(wasm_file) then
        return error(`Variant '{variant}' WASM output not found!`)
    end

    local wasynth_proc = process.create(WASM2LUAU_EXEC :: string, {wasm_file})
    local wasynth_output = wasynth_proc.stdout:readToEnd()
    if not wasynth_proc:status().ok then
        return error(`Failed to transpile WASM output of variant '{variant}'`)
    end
    print(`Variant '{variant}' got transpiled to luau successfully.`)

    local processed_runtime = processSnippetOrder(snippet_orders.runtime, flags, nil, wasynth_output)
    if not processed_runtime then
        return error(`Failed to process runtime of variant '{variant}'`)
    end
    print(`Successfully processed transpiled runtime of variant '{variant}'!`)

    local processed_entrypoint = processSnippetOrder(snippet_orders.entrypoint, flags, nil, "")
    if not processed_entrypoint then
        return error(`Failed to process variant '{variant}'`)
    end
    print(`Successfully processed entrypoint of variant '{variant}'!`)

    if not table.find(flags, "BUILD_ONEFILE") then
        local __VARIANT_FILE = `{variant_path}.luau`
        if fs.isFile(__VARIANT_FILE) then
            fs.removeFile(__VARIANT_FILE)
        end

        if not fs.isDir(variant_path) then
            fs.writeDir(variant_path)
        end

        fs.writeFile(`{variant_path}/runtime.luau`, processed_runtime)
        fs.writeFile(`{variant_path}/init.luau`, processed_entrypoint)
        return
    end

    local onefile_result = processSnippetOrder(
        FLAGGED_PATCHES_SNIPPET_ORDER.BUILD_ONEFILE,
        flags,
        {
            LUAUCEPTION_RUNTIME = processed_runtime
        },
        processed_entrypoint
    )
    if fs.isDir(variant_path) then
        fs.removeDir(variant_path)
    end

    fs.writeFile(`{variant_path}.luau`, onefile_result)
    return
end

do
    if not WASM2LUAU_EXEC then
        print("Please install wasm2luau by running ./utils/setup_wasm2luau.sh first!")
        return
    end

    local args = PARSER:parse()
    if not fs.isDir(getAbsolutePath(BUILD_DIR)) then
        fs.writeDir(getAbsolutePath(BUILD_DIR))
    end

    for _, variant in {"Compiler", "VM", "Full"} do
        createBuildVariant(variant, args.flags or {})
    end
end
