--!strict
return function(module: {[any]: any})
    local ljmp_sign = newproxy(false)
    local memory    = module.memory[1]                 :: buffer
    local functions = module                           :: {[string]: (...any) -> (...any)}
    local ift       = module.__indirect_function_table :: {[number]: (...any) -> (...any)}

    local function CreateString(str): number
        local strPtr = functions.malloc(#str + 1)
        buffer.writestring(memory, strPtr, str)
        buffer.writei8(memory, strPtr + #str, 0)
        return strPtr
    end

    local function CreateStringArray(array: {string}): number
        local arrayLength = #array
        local arrayPtr = functions.malloc((arrayLength + 1) * 4)

        for idx = 0, (arrayLength - 1) do
            local strVal = array[idx + 1]
            local strLen = #strVal
            local strPtr = functions.malloc(strLen + 1)
            buffer.writestring(memory, strPtr, strVal)
            buffer.writei8(memory, strPtr + strLen, 0)
            buffer.writei32(memory, arrayPtr + (idx * 4), strPtr)
        end

        buffer.writei32(memory, arrayPtr + (arrayLength * 4), 0)
        return arrayPtr
    end

    local function CreateStub(ret: number, name: string): (...any) -> (number)
        return function(...)
            print(`stub: {name} called -> {ret}`)
            return ret
        end
    end

    local function CreateInvoke()
        return function(index: number, ...)
            local stackPtr   = functions.emscripten_stack_get_current()
            local errorWasm  = "N/A"
            local stacktrace = "N/A"
            local success = xpcall(ift[index], function(_e) errorWasm = _e; stacktrace = debug.traceback() end, ...)
            if success then return end
            functions._emscripten_stack_restore(stackPtr)
            assert(errorWasm == ljmp_sign, `{errorWasm}\n\ninvoke stacktrace:\n{stacktrace}`)
            functions.setThrew(1, 0)
        end
    end

    local function FreeStringArray(arrayPtr: number)
        local position = 0
        while true do
            local strPtr = buffer.readi32(memory, arrayPtr + position)
            if (strPtr == 0) then break end
            functions.free(strPtr)
            position += 4
        end
        functions.free(arrayPtr)
        return
    end

    local function InjectFunction(f)
        local ptr = #ift + 1
        ift[ptr] = f
        return ptr
    end

    local function GetTaskLibrary(): typeof(require("@lune/task"))?
        if (task) then return task end
        local ok, res = pcall(require, "@lune/task")
        if (ok) then return res end
        return nil
    end

    return {
        CreateString      = CreateString,
        CreateStringArray = CreateStringArray,
        CreateStub        = CreateStub,
        CreateInvoke      = CreateInvoke,
        FreeStringArray   = FreeStringArray,
        InjectFunction    = InjectFunction,
        GetTaskLibrary    = GetTaskLibrary,
        LJMPThrowObject   = ljmp_sign,
    }
end
