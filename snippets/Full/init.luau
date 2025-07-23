--!optimize 2
local STUB_WARN = false

--@@VM_COMMONS@@

local function luau_compile(src: string, optLevel: number?, dbgLevel: number?, typInfLevel: number?, covLevel: number?): (string, number)
    --// Source string
    local srcPtr = cstr(src)

    --// Struct lua_CompileOptions (see luau/Compiler/include/luacode.h)
    local compileOptsPtr = cfns.malloc(36)
    rt.store.i32(memory_at_0, compileOptsPtr + 0, optLevel or 1) --// int optimizationLevel
    rt.store.i32(memory_at_0, compileOptsPtr + 4, dbgLevel or 1) --// int debugLevel
    rt.store.i32(memory_at_0, compileOptsPtr + 8, typInfLevel or 0) --// int typeInfoLevel
    rt.store.i32(memory_at_0, compileOptsPtr + 12, covLevel or 0) --// int coverageLevel
    rt.store.i32(memory_at_0, compileOptsPtr + 16, 0) --// const char* vectorLib
    rt.store.i32(memory_at_0, compileOptsPtr + 20, 0) --// const char* vectorCtor
    rt.store.i32(memory_at_0, compileOptsPtr + 24, 0) --// const char* vectorType
    rt.store.i32(memory_at_0, compileOptsPtr + 28, 0) --// const char* const* mutableGlobals
    rt.store.i32(memory_at_0, compileOptsPtr + 32, 0) --// const char* const* userdataTypes

    --// Bytecode size
    local bcSizePtr = cfns.malloc(8)

    --// Compile
    local bcPtr = cfns.luau_compile(srcPtr, #src, compileOptsPtr, bcSizePtr)
    local bcSize = rt.load.i32(memory_at_0, bcSizePtr)
    local bc = rt.load.string(memory_at_0, bcPtr, bcSize)

    --// Cleanup
    cfns.free(srcPtr)
	cfns.free(bcPtr)
    cfns.free(bcSizePtr)
    cfns.free(compileOptsPtr)

    return bc, bcSize
end

local function luau_run(bc: string, chunkName: string?, safeEnv: boolean?)
    --// Bytecode
    local bcPtr = cstr(bc)

    --// Chunk name
    local cnPtr = cstr(chunkName or "LuauCeptionChunk")

    --// State setup
    local L = cfns.luaL_newstate()
    cfns.luaL_openlibs(L);
    if (safeEnv) then cfns.luaL_sandbox(L) end

    --// Load bytecode
    local ldRes = cfns.luau_load(L, cnPtr, bcPtr, #bc, 0)

    --// Cleanup unused stuff
    cfns.free(bcPtr)
    cfns.free(cnPtr)

    --// Check if load succeded
    if (ldRes ~= 0) then cfns.lua_close(L) end
    assert(ldRes == 0, "failed to load luau bytecode")

    --// Call function
    local clRes = cfns.lua_pcall(L, 0, 0, 0)

    --// Cleanup state
    cfns.lua_close(L)

    return clRes == 0
end

local function luau_load(bc: string, chunkName: string?, safeEnv: boolean?): () -> (boolean)
    return function()
        return luau_run(bc, chunkName, safeEnv)
    end
end

--@@FLAGS@@

--@@MACROS@@

return {
	luau_compile = luau_compile,
    luau_run = luau_run,
    luau_load = luau_load,
    luau_setflag = luau_setflag,
    luau_setallflags = luau_setallflags,
    luau_resetflags = luau_resetflags,
    macros = macros,
	wasm = {
		rt = rt,
		cfns = cfns,
		indirect_function_table = INDIRECT_FUNCTIONS,
		memory = memory_at_0,
        insertCFunction = insertCFunction,
        cstr = cstr
	}
}
