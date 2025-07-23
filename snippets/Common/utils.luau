local CException = {} do
    local CExcInternal = {}
    CExcInternal.__index = CExcInternal

    function CExcInternal:_UndecoratedName()
        local name_ptr = rt.load.i32(memory_at_0, self.ptr + 4);
        return rt.load.string(memory_at_0, name_ptr, cfns.strlen(name_ptr))
    end

    function CExcInternal:vfptr()
        local vfptr = rt.load.i32(memory_at_0, self.ptr);
        return vfptr
    end

    function CException.new(excPtr)
        local self = {}
        self.excPtr = excPtr
        self.ptr = excPtr - 24

        return setmetatable(self, CExcInternal)
    end
end

local function cstr(str)
    local strLen = #str
    local strPtr = cfns.malloc(strLen + 1)
    rt.store.string(memory_at_0, strPtr, str)
    rt.store.i32_n8(memory_at_0, strPtr + strLen, 0)
    return strPtr
end

local function stub(name, ret)
    return function(...)
        if (STUB_WARN) then
            print(`[WARN]: stub function '{name}' called`)
        end

        return ret
    end
end

local __LONGJMP_THROW_SIGN = newproxy(false)
local function invokeHandler(index)
    return function(fnIndex, ...)
        local sp = cfns.emscripten_stack_get_current()
        local e, stacktrace = "N/A", "N/A"
        local success = xpcall(
            INDIRECT_FUNCTIONS.data[fnIndex],
            function(a) e = a; stacktrace = debug.traceback() end,
            ...
        )
        if (not success) then
            cfns._emscripten_stack_restore(sp)
            assert(e == __LONGJMP_THROW_SIGN, `{e}\n\ninvoke stacktrace:\n{stacktrace}`)
            cfns.setThrew(1, 0)
        end
    end
end

local function insertCFunction(f)
    local ptr = #INDIRECT_FUNCTIONS.data + 1
    INDIRECT_FUNCTIONS.data[ptr] = f
    return ptr
end
