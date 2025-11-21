return function()
    local rt, memory_at_0, cfns, INDIRECT_FUNCTIONS
    local module = {}

    function module.stub(name: string, ret: any)
        return function(...)
            if (STUB_WARN) then
                print(`[WARN]: stub function '{name}' called`)
            end

            return ret
        end
    end

    function module.insertCFunction(func: (...any) -> (...any)): number
        local ptr = #INDIRECT_FUNCTIONS.data + 1
        INDIRECT_FUNCTIONS.data[ptr] = func

        return ptr
    end

    function module.cstr(value: string): number
        local str_len = #value
        local str_ptr = cfns.malloc(str_len + 1)
        rt.store.string(memory_at_0, str_ptr, value)
        rt.store.i32_n8(memory_at_0, str_ptr + str_len, 0)

        return str_ptr
    end

    function module.cstr_array(array: {string}): number
        local array_len = #array
        local array_ptr = cfns.malloc((array_len + 1) * 4)

        for idx = 0, (array_len - 1) do
            local str_val = array[idx + 1]
            local str_len = #str_val
            local str_ptr = cfns.malloc(str_len + 1)

            rt.store.string(memory_at_0, str_ptr, str_val)
            rt.store.i32_n8(memory_at_0, str_ptr + str_len, 0)
            rt.store.i32(memory_at_0, array_ptr + (idx * 4), str_ptr)
        end

        rt.store.i32(memory_at_0, array_ptr + (array_len * 4), 0)
        return array_ptr
    end

    function module.free_array(array_ptr: number)
        local position = 0

        while true do
            local str_ptr = rt.load.i32(array_ptr + position)
            if str_ptr == 0 then
                break
            end

            cfns.free(str_ptr)
            position += 4
        end
        cfns.free(array_ptr)
    end

    function module.newCException(excPtr: number)
        local CException = {}
        CException.ptr = excPtr

        function CException._UndecoratedName(self)
            local name_ptr = rt.load.i32(memory_at_0, self.ptr + 4)
            return rt.load.string(memory_at_0, name_ptr, cfns.strlen(name_ptr))
        end

        function CException.vfptr(self)
            return rt.load.i32(memory_at_0, self.ptr)
        end
        return CException
    end

    return module, function(_rt: any, _memory_at_0: any, _cfns: any, _INDIRECT_FUNCTIONS: any)
        rt, memory_at_0, cfns, INDIRECT_FUNCTIONS = _rt, _memory_at_0, _cfns, _INDIRECT_FUNCTIONS
    end
end
