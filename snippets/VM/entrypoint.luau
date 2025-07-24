local api_flags_create = require("../Common/api_flags")
local runtime_create = require("../Common/runtime_create")

local rt, memory_at_0, cfns, INDIRECT_FUNCTIONS, utils = runtime_create()
local api_flags = api_flags_create(rt, memory_at_0, cfns, INDIRECT_FUNCTIONS, utils)

local function luau_run(
    bc: string,
    chunkName: string?,
    safeEnv: boolean?
): boolean
    --// Bytecode
    local bcPtr = utils.cstr(bc)

    --// Chunk name
    local cnPtr = utils.cstr(chunkName or "LuauCeptionChunk")

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

local function luau_load(
    bc: string,
    chunkName: string?,
    safeEnv: boolean?
): () -> (boolean)
    return function()
        return luau_run(bc, chunkName, safeEnv)
    end
end

return {
    luau_run = luau_run,
    luau_load = luau_load,
    luau_setflag = api_flags.luau_setflag,
    luau_setallflags = api_flags.luau_setallflags,
    luau_resetflags = api_flags.luau_resetflags,
    macros = require("../Common/luau_macros")(rt, memory_at_0, cfns, INDIRECT_FUNCTIONS),
    wasm = {
        rt = rt,
        cfns = cfns,
        indirect_function_table = INDIRECT_FUNCTIONS,
        memory = memory_at_0,
        insertCFunction = utils.insertCFunction,
        cstr = utils.cstr,
    }
}
