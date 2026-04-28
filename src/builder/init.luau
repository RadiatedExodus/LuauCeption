--!strict
local argparse = require("@argparse/lib")
local process  = require("@lune/process")
local fs       = require("@lune/fs")

--// Git utilities
local function GitGetTag(cwd: string?): string
    cwd = cwd or "."
    local result = process.exec("git", {"describe", "--abbrev=0", "--tags"}, {
        cwd = cwd
    })
    assert(result.ok, `failed to get git tag from '{cwd}'`)
    return string.split(result.stdout, "\n")[1]
end

local function GitGetCommit(cwd: string?): string
    cwd = cwd or "."
    local result = process.exec("git", {"rev-parse", "HEAD"}, {
        cwd = cwd
    })
    assert(result.ok, `failed to get git commit from '{cwd}'`)
    return string.split(result.stdout, "\n")[1]
end

--// Spider
local function RunSpider(wasmFile: string): string
    local result = process.exec("spider-cli", {
        "--optimize",
        "--source", "web-assembly",
        "--target", "luau",
        wasmFile
    })
    assert(result.ok, `spider failed to transpile webassembly module:\n{result.stderr}`)
    return result.stdout
end

--// check if we're running in the root of the repository
local cwdCheckOk, cwdResult = pcall(fs.isDir, "./src")
assert(cwdCheckOk and cwdResult, `please run the builder from the root of the repository`)

--// argparse
local parserCmdLine = argparse("src/builder", "LuauCeption Builder Script")
parserCmdLine:option("-f --file", "Path to WebAssembly file")
parserCmdLine:option("-t --type", "Type of the module (compiler, vm)")
local args = parserCmdLine:parse(process.args)

--// argument checks
local wasmModuleCheckOk, wasmModuleCheckResult = pcall(fs.isFile, args["file"])
assert(wasmModuleCheckOk and wasmModuleCheckResult, `specified webassembly module '{args["file"]}' is not a file or unreadable`)
assert((string.lower(args["type"]) == "compiler") or (string.lower(args["type"]) == "vm"), "module type must be 'vm' or 'compiler'")

--// constants
local WASM_MODULE_PATH  = args["file"]
local MODULE_TYPE       = string.lower(args["type"]) :: "compiler" | "vm"
local LUAU_GIT_TAG      = GitGetTag("./extern/luau/")
local LUAU_GIT_COMMIT   = GitGetCommit("./extern/luau/")
local VECTOR_COMPAT     = fs.readFile("./src/builder/VectorCompat.luau")

--// transpile using spider
--// TODO: convert this to function for reusability
--// TODO: add argument to exclude adding vector compat
local transpiledModuleStrings = {} :: {string}
table.insert(transpiledModuleStrings, "--!nocheck")
table.insert(transpiledModuleStrings, `--// LuauCeption - module: {MODULE_TYPE}`)
table.insert(transpiledModuleStrings, `--// Luau {LUAU_GIT_TAG} ({LUAU_GIT_COMMIT})`)
table.insert(transpiledModuleStrings, VECTOR_COMPAT)
table.insert(transpiledModuleStrings, RunSpider(WASM_MODULE_PATH))
table.insert(transpiledModuleStrings, "return module")

--// TODO: argument to specify where to output the "built file structure"
--// TODO: remove -t argument and replace it with --compiler-module (-cm) and --vm-module (-vm)
--// TODO: output found luau tag and version to stdout
fs.writeFile("./src/luau_entrypoint/CompilerModule.luau", table.concat(transpiledModuleStrings, "\n"))