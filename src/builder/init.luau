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
--// TODO: Runtime dumper function (runtime dump option not on stable branch yet!)
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

--// Filesystem
local function CheckFileReadable(path: string)
    local asuccess, exists = pcall(fs.isFile, path)
    local bsuccess, readOk = pcall(fs.readFile, path)
    assert(asuccess and exists, `file '{path}' doesn't exist`)
    assert(bsuccess and readOk, `file '{path}' is unreadable`)
    return
end

local function PathShouldEndInSlash(path: string): string
    if (string.sub(path, #path, #path) ~= "/") then
        return `{path}/`
    end
    return path
end

--// check if we're running in the root of the repository
local cwdCheckOk, cwdResult = pcall(fs.isDir, "./src")
assert(cwdCheckOk and cwdResult, `please run the builder from the root of the repository`)

--// argparse
local parserCmdLine = argparse("src/builder", "LuauCeption Builder Script")
parserCmdLine:option("-cm --compiler-module",  "Path to Luau.LuauCeption.Compiler WebAssembly file")
parserCmdLine:option("-vm --vm-module",        "Path to Luau.LuauCeption.VM WebAssembly file")
parserCmdLine:option("-am --analysis-module",  "Path to Luau.LuauCeption.Analysis WebAssembly file")
parserCmdLine:option("-of --output-folder",    "The path where the 'built' LuauCeption module will be put at")
local args = parserCmdLine:parse(process.args)

--// constants
local COMPILER_WASM_MODULE  = args["compiler_module"]
local VM_WASM_MODULE        = args["vm_module"]
local ANALYSIS_WASM_MODULE  = args["analysis_module"]
local OUTPUT_FOLDER_PATH    = PathShouldEndInSlash(args["output_folder"])
local LUAU_GIT_TAG          = GitGetTag("./extern/luau/")
local LUAU_GIT_COMMIT       = GitGetCommit("./extern/luau/")

--// module processing
--// put down here because they need constants
local function ProcessModule(type: "compiler" | "vm" | "analysis", path: string): string
    local transpiledModuleStrings = {} :: {string}
    table.insert(transpiledModuleStrings, "--!nocheck")
    table.insert(transpiledModuleStrings, `--// LuauCeption - module: {type}`)
    table.insert(transpiledModuleStrings, `--// Luau {LUAU_GIT_TAG} ({LUAU_GIT_COMMIT})`)
    table.insert(transpiledModuleStrings, "")
    table.insert(transpiledModuleStrings, RunSpider(path))
    table.insert(transpiledModuleStrings, "return module")
    return table.concat(transpiledModuleStrings, "\n")
end

--// file check
CheckFileReadable(COMPILER_WASM_MODULE)
CheckFileReadable(VM_WASM_MODULE)
CheckFileReadable(ANALYSIS_WASM_MODULE)

--// some logging
print("LuauCeption Builder")
print(`  Luau version detected: {LUAU_GIT_TAG} ({LUAU_GIT_COMMIT})`)
print(`  Compiler module path:  {COMPILER_WASM_MODULE}`)
print(`  VM module path:        {VM_WASM_MODULE}`)
print(`  Analysis module path:  {ANALYSIS_WASM_MODULE}`)
print(`  Output folder path:    {OUTPUT_FOLDER_PATH}`)

--// setup output folder
if (not fs.isDir(OUTPUT_FOLDER_PATH)) then
    fs.writeDir(OUTPUT_FOLDER_PATH)
end

--// copy over luau entrypoint files from src
for _, fileName in fs.readDir("./src/luau_entrypoint/") do
    print(`Found luau entrypoint file/folder -> {fileName}`)
    fs.copy(`./src/luau_entrypoint/{fileName}`, `{OUTPUT_FOLDER_PATH}{fileName}`, true)
end

--// processing
print("Processing compiler module")
fs.writeFile(`{OUTPUT_FOLDER_PATH}CompilerModule.luau`, ProcessModule("compiler", COMPILER_WASM_MODULE))
print("Processing VM module")
fs.writeFile(`{OUTPUT_FOLDER_PATH}VMModule.luau`, ProcessModule("vm", VM_WASM_MODULE))
print("Processing analysis module")
fs.writeFile(`{OUTPUT_FOLDER_PATH}AnalysisModule.luau`, ProcessModule("analysis", ANALYSIS_WASM_MODULE))

--// ok
print("Build OK")