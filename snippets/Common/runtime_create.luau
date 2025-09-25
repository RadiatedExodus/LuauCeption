local runtime_initialize = (require)("@self/runtime")

local polyfill_create = require("./polyfill")
local utils_create = require("./utils")

return function()
    local utils, utils_ready = utils_create()
    local polyfill, polyfill_ready = polyfill_create(utils)

    local common_imports = { func_list = polyfill }
    local RuntimeInstance = runtime_initialize({
        env = common_imports,
        wasi_snapshot_preview1 = common_imports,
    })

    local rt, memory_at_0, cfns, INDIRECT_FUNCTIONS =
        RuntimeInstance.rt,
        RuntimeInstance.memory_list.memory,
        RuntimeInstance.func_list,
        RuntimeInstance.table_list.__indirect_function_table

    polyfill_ready(rt, memory_at_0, cfns, INDIRECT_FUNCTIONS)
    utils_ready(rt, memory_at_0, cfns, INDIRECT_FUNCTIONS)
    return rt, memory_at_0, cfns, INDIRECT_FUNCTIONS, utils, polyfill
end