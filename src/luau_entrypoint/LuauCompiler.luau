--!strict
local WasmModule      = require("./WasmModuleType")
local HelperInit      = require("./Helper")
local ImportTableInit = require("./ImportTable")

local LuauCompiler = {}
LuauCompiler.__index = LuauCompiler

export type LuauCompileOptions = {
    OptimizationLevel: number?,
    DebugLevel:        number?,
    TypeInfoLevel:     number?,
    CoverageLevel:     number?,

    VectorLibName:        string?,
    VectorLibConstructor: string?,
    VectorType:           string?,

    MutableGlobals:   { string }?,
    UserdataTypes:    { string }?,

    LibrariesWithKnownMembers:     { string }?,
    LibraryMemberTypeCallback:     number?, --// int (*lua_LibraryMemberTypeCallback)(const char* library, const char* member);
    LibraryMemberConstantCallback: number?, --// void (*lua_LibraryMemberConstantCallback)(const char* library, const char* member, lua_CompileConstant* constant);

    DisabledBuiltins: { string }?,
}

export type LuauCompiler = typeof(setmetatable({} :: {
    WASM:        WasmModule.WasmModule,
    Memory:      buffer,
    ImportTable: {[string]: (...any) -> (...any)},
    Helper:      typeof(HelperInit(nil :: any)),
}, LuauCompiler))

function LuauCompiler.Compile(self: LuauCompiler, source: string, options: LuauCompileOptions | number | nil): string
    local srcPtr = self.Helper.CreateString(source)
    local bcsPtr = self.WASM.malloc(8)
    
    local compileOptsPtr: number?
    local freeCompOpts:   () -> ()
    if (typeof(options) == "table") then
        compileOptsPtr, freeCompOpts = self:ConstructCompileOptions(options)
    else
        compileOptsPtr = options
    end

    local bcPtr        = self.WASM.luau_compile(srcPtr, #source, compileOptsPtr or 0, bcsPtr)
    local bytecodeSize = buffer.readi32(self.Memory, bcsPtr)
    local bytecode     = buffer.readstring(self.Memory, bcPtr, bytecodeSize)
    
    self.WASM.free(srcPtr)
    self.WASM.free(bcsPtr)
    self.WASM.free(bcPtr)
    if (freeCompOpts) then freeCompOpts() end
    return bytecode
end

function LuauCompiler.ConstructCompileOptions(self: LuauCompiler, options: LuauCompileOptions): (number, () -> ())
    local ptr   = self.WASM.malloc(52)
    local freed = false

    local vlnPtr = if (options.VectorLibName) then        self.Helper.CreateString(options.VectorLibName)        else 0
    local vlcPtr = if (options.VectorLibConstructor) then self.Helper.CreateString(options.VectorLibConstructor) else 0
    local vtPtr  = if (options.VectorType) then           self.Helper.CreateString(options.VectorType)           else 0

    local mgPtr   = if (options.MutableGlobals)            then self.Helper.CreateStringArray(options.MutableGlobals)            else 0
    local utPtr   = if (options.UserdataTypes)             then self.Helper.CreateStringArray(options.UserdataTypes)             else 0
    local lwkmPtr = if (options.LibrariesWithKnownMembers) then self.Helper.CreateStringArray(options.LibrariesWithKnownMembers) else 0
    local dbPtr   = if (options.DisabledBuiltins)          then self.Helper.CreateStringArray(options.DisabledBuiltins)          else 0

    --// struct lua_CompileOptions (see luau/Compiler/include/luacode.h)
    buffer.writei32(self.Memory, ptr + 0,  options.OptimizationLevel or 1)             --// int optimizationLevel
    buffer.writei32(self.Memory, ptr + 4,  options.DebugLevel        or 1)             --// int debugLevel
    buffer.writei32(self.Memory, ptr + 8,  options.TypeInfoLevel     or 0)             --// int typeInfoLevel
    buffer.writei32(self.Memory, ptr + 12, options.CoverageLevel     or 0)             --// int coverageLevel
    buffer.writei32(self.Memory, ptr + 16, vlnPtr)                                     --// const char* vectorLib
    buffer.writei32(self.Memory, ptr + 20, vlcPtr)                                     --// const char* vectorCtor
    buffer.writei32(self.Memory, ptr + 24, vtPtr)                                      --// const char* vectorType
    buffer.writei32(self.Memory, ptr + 28, mgPtr)                                      --// const char* const* mutableGlobals
    buffer.writei32(self.Memory, ptr + 32, utPtr)                                      --// const char* const* userdataTypes
    buffer.writei32(self.Memory, ptr + 36, lwkmPtr)                                    --// const char* const* librariesWithKnownMembers
    buffer.writei32(self.Memory, ptr + 40, options.LibraryMemberTypeCallback     or 0) --// lua_LibraryMemberTypeCallback libraryMemberTypeCb
    buffer.writei32(self.Memory, ptr + 44, options.LibraryMemberConstantCallback or 0) --// lua_LibraryMemberConstantCallback libraryMemberConstantCb
    buffer.writei32(self.Memory, ptr + 48, dbPtr)                                      --// const char* const* disabledBuiltins

    local function freeCompileOptions()
        assert(not freed, "compile options already freed")
        self.WASM.free(ptr)
        self.WASM.free(vlnPtr)
        self.WASM.free(vlcPtr)
        self.WASM.free(vtPtr)
        self.WASM.free(mgPtr)
        self.WASM.free(utPtr)
        self.WASM.free(lwkmPtr)
        self.WASM.free(dbPtr)
        return
    end

    return ptr, freeCompileOptions
end

return {
    new = function(): LuauCompiler
        local importOk: boolean, init: (any) -> (WasmModule.WasmModule) = pcall(require, "./CompilerModule")
        assert(importOk, `failed to import webassembly module: {init}`)

        --// import table proxy
        --// since we can't access memory before init, we have to
        --// proxy them (init has assertions for checking missing imports)
        local importTable = {} :: {[string]: (...any) -> (...any)}
        local proxyTable  = setmetatable({}, { __index = function(_, n: string) return function(...) return importTable[n](...) end end })
        local module = init({ env = proxyTable, wasi_snapshot_preview1 = proxyTable })

        --// initialize our stuff
        local helper          = HelperInit(module)
        local realImportTable = ImportTableInit(module, helper)
        for name: string, fn: (...any) -> (...any) in realImportTable :: any do
            importTable[name] = fn
        end

        return setmetatable({
            WASM        = module,
            Memory      = module.memory[1],
            ImportTable = importTable,
            Helper      = helper,
        }, LuauCompiler)
    end
}