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

local function luau_compile(
    src: string,
    optLevel: number?,
    dbgLevel: number?,
    typInfLevel: number?,
    covLevel: number?
): (string, number)
    --// Source string
    local srcPtr = utils.cstr(src)

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

return {
    luau_compile = luau_compile,
    luau_setflag = api_flags.luau_setflag,
    luau_setallflags = api_flags.luau_setallflags,
    luau_resetflags = api_flags.luau_resetflags,
    wasm = {
        rt = rt,
        cfns = cfns,
        indirect_function_table = INDIRECT_FUNCTIONS,
        memory = memory_at_0,
        insertCFunction = utils.insertCFunction,
        cstr = utils.cstr,
    }
}
