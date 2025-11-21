return function(rt: any, memory_at_0: any, cfns: any, INDIRECT_FUNCTIONS: any, utils: typeof(require("../Common/utils")()))
    local module = {}

    function module.luau_run(
        bytecode: string,
        chunkName: string?,
        safeEnv: boolean?
    ): boolean
        -- load bytecode and chunkName to memory
        local bytecode_ptr = utils.cstr(bytecode)
        local chunkName_ptr = utils.cstr(chunkName or "LuauCeptionChunk")

        -- setup Luau state
        local L = cfns.luaL_newstate()
        cfns.luaL_openlibs(L);
        if safeEnv then
            cfns.luaL_sandbox(L)
        end

        -- load bytecode
        local load_result = cfns.luau_load(L, chunkName_ptr, bytecode_ptr, #bytecode, 0)

        -- cleanup unused stuff
        cfns.free(bytecode_ptr)
        cfns.free(chunkName_ptr)

        -- check if load succeded
        if (load_result ~= 0) then
            cfns.lua_close(L)
        end
        assert(load_result == 0, "failed to load luau bytecode")

        -- call function
        local clRes = cfns.lua_pcall(L, 0, 0, 0)

        -- cleanup state
        cfns.lua_close(L)
        return clRes == 0
    end

    function module.luau_load(
        bytecode: string,
        chunkName: string?,
        safeEnv: boolean?
    ): () -> (boolean)
        return function()
            return module.luau_run(bytecode, chunkName, safeEnv)
        end
    end

    return module
end
