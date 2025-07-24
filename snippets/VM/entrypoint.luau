local polyfill_init = require("../Common/polyfill")
local utils_init = require("../Common/utils")
local api_flags_init = require("../Common/api_flags")

local runtime_init = require("@self/runtime")

local utils: typeof(utils_init())
local api_flags: typeof(api_flags_init())
local rt, memory_at_0, cfns, INDIRECT_FUNCTIONS

do
    local _utils, utils_ready = utils_init()
    local polyfill, polyfill_ready = polyfill_init(_utils)

    local RuntimeInstance = runtime_init({
        env = {
            func_list = {
                _tzset_js = _utils.stub("_tzset_js"),
                invoke_vii = _utils.invokeHandler(1),
                _abort_js = polyfill._abort_js,
                __cxa_throw = polyfill.__cxa_throw,
                emscripten_date_now = polyfill.emscripten_date_now,
                emscripten_resize_heap = polyfill.emscripten_resize_heap,
                _emscripten_runtime_keepalive_clear = polyfill._emscripten_runtime_keepalive_clear,
                _emscripten_throw_longjmp = polyfill._emscripten_throw_longjmp,
                _setitimer_js = polyfill._setitimer_js,
                _localtime_js = polyfill._localtime_js,
                _gmtime_js = polyfill._gmtime_js,
            }
        },
        wasi_snapshot_preview1 = {
            func_list = {
                clock_time_get = polyfill.clock_time_get,
                proc_exit = polyfill.proc_exit,
                fd_write = polyfill.fd_write,
            }
        }
    })

    rt, memory_at_0, cfns, INDIRECT_FUNCTIONS =
        RuntimeInstance.rt,
        RuntimeInstance.memory_list.memory,
        RuntimeInstance.func_list,
        RuntimeInstance.table_list.__indirect_function_table

    polyfill_ready(rt, memory_at_0, cfns, INDIRECT_FUNCTIONS)
    utils_ready(rt, memory_at_0, cfns, INDIRECT_FUNCTIONS)
    utils, api_flags = _utils, api_flags_init(rt, memory_at_0, cfns, INDIRECT_FUNCTIONS, _utils)
end

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
    macros = require("../Common/luau_macros"),
    wasm = {
        rt = rt,
        cfns = cfns,
        indirect_function_table = INDIRECT_FUNCTIONS,
        memory = memory_at_0,
        insertCFunction = utils.insertCFunction,
        cstr = utils.cstr,
    }
}
