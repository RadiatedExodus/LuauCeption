--!strict
local WasmModule      = require("./Support/WasmModuleType")
local HelperInit      = require("./Support/Helper")
local ImportTableInit = require("./Support/ImportTable")

local LuauAnalysis = {}
LuauAnalysis.__index = LuauAnalysis

export type LuauAnalysis = typeof(setmetatable({} :: {
    WASM:           WasmModule.WasmModule,
    Memory:         buffer,
    ImportTable:    {[string]: (...any) -> (...any)},
    Helper:         typeof(HelperInit(nil :: any)),
    FileResolver:   number,
    ConfigResolver: number,
    Frontend:       number,
}, LuauAnalysis))

function LuauAnalysis.Destroy(self: LuauAnalysis)
    self.WASM.luauception_analysis_frontend_free(self.Frontend)
    self.WASM.luauception_analysis_fileresolver_free(self.FileResolver)
    self.WASM.luauception_analysis_configresolver_free(self.ConfigResolver)
    self.Frontend       = 0
    self.FileResolver   = 0
    self.ConfigResolver = 0
    return
end

function LuauAnalysis.AddFile(self: LuauAnalysis, name: string, source: string)
    local namePtr   = self.Helper.CreateString(name)
    local sourcePtr = self.Helper.CreateString(source)
    self.WASM.luauception_analysis_fileresolver_add(self.FileResolver, namePtr, sourcePtr)
    self.WASM.free(namePtr)
    self.WASM.free(sourcePtr)
    return
end

function LuauAnalysis.DeleteFile(self: LuauAnalysis, name: string)
    local namePtr = self.Helper.CreateString(name)
    self.WASM.luauception_analysis_fileresolver_delete(self.FileResolver, namePtr)
    self.WASM.free(namePtr)
    return
end

function LuauAnalysis.ClearFiles(self: LuauAnalysis)
    self.WASM.luauception_analysis_fileresolver_clear(self.FileResolver)
    return
end

function LuauAnalysis.ListFileNames(self: LuauAnalysis): { string }
    return self.Helper.ReadStringArray(self.WASM.luauception_analysis_fileresolver_listnames(self.FileResolver))
end

function LuauAnalysis.GetFileSource(self: LuauAnalysis, name: string): string
    local namePtr = self.Helper.CreateString(name)
    local result  = self.WASM.luauception_analysis_fileresolver_get(self.FileResolver, namePtr)
    local length  = self.WASM.strlen(result)
    self.WASM.free(namePtr)
    return buffer.readstring(self.Memory, result, length)
end

function LuauAnalysis.SetNewSolverMode(self: LuauAnalysis, enabled: boolean)
    self.WASM.luauception_analysis_frontend_setsolvermode(self.Frontend, if (enabled) then 1 else 0)
    return
end

function LuauAnalysis.SetStrictMode(self: LuauAnalysis, enabled: boolean)
    self.WASM.luauception_analysis_configresolver_setstrict(self.ConfigResolver, if (enabled) then 1 else 0)
    return
end

function LuauAnalysis.RegisterDefaultGlobals(self: LuauAnalysis)
    self.WASM.luauception_analysis_frontend_registerglobals(self.Frontend)
    return
end

function LuauAnalysis.ResetFrontend(self: LuauAnalysis)
    self.WASM.luauception_analysis_frontend_reset(self.Frontend)
    return
end

function LuauAnalysis.Check(self: LuauAnalysis, fileName: string): string
    local namePtr = self.Helper.CreateString(fileName)
    local lenPtr  = self.WASM.malloc(4)
    local result  = self.WASM.luauception_analysis_frontend_check(self.Frontend, namePtr, lenPtr)
    local length  = buffer.readi32(self.Memory, lenPtr)
    self.WASM.free(lenPtr)
    self.WASM.free(namePtr)
    return buffer.readstring(self.Memory, result, length)
end

return {
    new = function(): LuauAnalysis
        local importOk: boolean, init: (any) -> (WasmModule.WasmModule) = pcall(require, "./Modules/AnalysisModule")
        assert(importOk, `failed to import webassembly module: {init}`)

        --// import table proxy
        --// since we can't access memory before init, we have to
        --// proxy them (init has assertions for checking missing imports)
        local importTable: {[string]: (...any) -> (...any)}
        local proxyTable  = setmetatable({}, { __index = function(_, n: string) return function(...) assert(importTable[n], `BUG: import '{n}' does not exist`); return importTable[n](...) end end })
        local module = init({ env = proxyTable, wasi_snapshot_preview1 = proxyTable })

        --// initialize our stuff
        local helper = HelperInit(module)
        importTable  = ImportTableInit(module, helper)

        --// invoke functions
        importTable["invoke_vii"] = helper.CreateInvoke()

        --// create the frontend resolvers
        local frPtr = module.luauception_analysis_fileresolver_create()
        local crPtr = module.luauception_analysis_configresolver_create()

        return setmetatable({
            WASM           = module,
            Memory         = module.memory[1],
            ImportTable    = importTable,
            Helper         = helper,
            FileResolver   = frPtr,
            ConfigResolver = crPtr,
            Frontend       = module.luauception_analysis_frontend_create(frPtr, crPtr),
        }, LuauAnalysis)
    end
}