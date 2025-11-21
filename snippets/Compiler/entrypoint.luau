local api_flags_create = require("../Common/api_flags")
local runtime_create = require("../Common/runtime_create")
local compiler_common_init = require("../Compiler/common")
export type LuauCompileOptions = compiler_common_init.LuauCompileOptions

local rt, memory_at_0, cfns, INDIRECT_FUNCTIONS, utils = runtime_create(require("../Common/polyfill"))
local api_flags = api_flags_create(rt, memory_at_0, cfns, INDIRECT_FUNCTIONS, utils)
local compiler_common = compiler_common_init(rt, memory_at_0, cfns, INDIRECT_FUNCTIONS, utils)

return {
    luau_compile = compiler_common.luau_compile,
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
