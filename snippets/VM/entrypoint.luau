local api_flags_create = require("../Common/api_flags")
local runtime_create = require("../Common/runtime_create")
local vm_common_init = require("../VM/common")

local rt, memory_at_0, cfns, INDIRECT_FUNCTIONS, utils = runtime_create(require("../VM/polyfill"))
local api_flags = api_flags_create(rt, memory_at_0, cfns, INDIRECT_FUNCTIONS, utils)
local vm_common = vm_common_init(rt, memory_at_0, cfns, INDIRECT_FUNCTIONS, utils)

return {
    luau_run = vm_common.luau_run,
    luau_load = vm_common.luau_load,
    luau_setflag = api_flags.luau_setflag,
    luau_setallflags = api_flags.luau_setallflags,
    luau_resetflags = api_flags.luau_resetflags,
    macros = require("../VM/luau_macros")(rt, memory_at_0, cfns, INDIRECT_FUNCTIONS, utils),
    wasm = {
        rt = rt,
        cfns = cfns,
        indirect_function_table = INDIRECT_FUNCTIONS,
        memory = memory_at_0,
        insertCFunction = utils.insertCFunction,
        cstr = utils.cstr,
    }
}
