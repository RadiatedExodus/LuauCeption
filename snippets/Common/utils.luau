return function()
    local rt, memory_at_0, cfns, INDIRECT_FUNCTIONS
    local module = {}

    function module.cstr(value: string): number
        local str_len = #value
        local str_ptr = cfns.malloc(str_len + 1)
        rt.store.string(memory_at_0, str_ptr, value)
        rt.store.i32_n8(memory_at_0, str_ptr + str_len, 0)

        return str_ptr
    end

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
