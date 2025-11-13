return function(rt: any, memory_at_0: any, cfns: any, INDIRECT_FUNCTIONS: any, utils: typeof(require("./utils")()))
    local module = {}

    function module.luau_setflag(name: string, state: boolean)
        --// Flag name
        local flagNamePtr = utils.cstr(name)

        --// Set the flag
        cfns.set_flag(flagNamePtr, if (state) then 1 else 0)

        --// Cleanup
        cfns.free(flagNamePtr)
        return
    end

    function module.luau_setallflags(state: boolean)
        cfns.set_all_flags(if (state) then 1 else 0)
        return
    end

    function module.luau_resetflags()
        cfns.reset_flags()
        return
    end

    return module
end
