--!strict
local ExceptionInfo = require("./ExceptionInfo")

type HelperTable = typeof(require("./Helper")(nil :: any))

return function(module: {[any]: any}, helper: HelperTable)
    local ljmp_sign = helper.LJMPThrowObject
    local memory    = module.memory[1]                 :: buffer
    local functions = module                           :: {[string]: (...any) -> (...any)}
    --// local ift       = module.__indirect_function_table :: {[number]: (...any) -> (...any)}
    local task      = helper.GetTaskLibrary()

    local fd_files           = { {}, {} } :: { { string } }
    local timers             = {}         :: { { thread: thread, timeoutMs: number } }
    local exitStatus         = nil        :: number?
    local aborted            = false      :: boolean
    local noExitRt           = true       :: boolean
    local rtKeepaliveCounter = 0          :: number

    local function fd_flush(file: {string})
        local final = table.concat(file)
        local last = 1
        for index, data in string.gmatch(final, '()([^\n]*)\n') do
            if (not data) then continue end
            last = index + #data
            print(data)
        end
        table.clear(file)
        file[1] = string.sub(final, last + 1)
    end

    local function fd_write(fd: number, list: number, count: number, retPtr: number): number
        local file = fd_files[fd]
        if not file then return 8 end
        local total = 0
        for pointer = list, list + (count - 1) * 8, 8 do
            local start = buffer.readi32(memory, pointer)
            local len   = buffer.readi32(memory, pointer + 4)
            local read  = buffer.readstring(memory, start, len)
            table.insert(file, read)
            total = total + #read
        end
        buffer.writei32(memory, retPtr, total)
        fd_flush(file)
        return 0
    end

    local function __cxa_throw(ptr: number, type: number, destructor: number): never
        local info = ExceptionInfo.new(memory, ptr)
        info:Initialize(type, destructor)
        error(`exception occured in c: {info:GetUndecoratedName(functions.strlen)} ({ptr})`, 0)
    end

    local function _abort_js(reason: any)
        error(`Aborted({reason})`, 0)
    end

    local function proc_exit(code: number)
        exitStatus = code
        if (not (noExitRt or rtKeepaliveCounter > 0)) then
            aborted = true
        end
        error(`ExitStatus: Program exited with code ${code}`, 0)
    end

    local function _emscripten_throw_longjmp()
        return error(ljmp_sign, 0)
    end

    local function _emscripten_runtime_keepalive_clear()
        noExitRt           = false
        rtKeepaliveCounter = 0
        return
    end

    local function emscripten_resize_heap(_requestedSize: number)
        error("OOM", 0)
    end

    local function _setitimer_js(which: number, timeoutMs: number): number?
        if (not task) then
            print("program is using _setitimer_js but task library not found, timers will NOT work.")
            return 0
        end

        if (timers[which]) then
            task.cancel(timers[which].thread)
            timers[which] = nil
        end

        if (not timeoutMs or timeoutMs == 0) then
            return 0
        end

        local thread = task.delay(timeoutMs / 1000, function()
            timers[which] = nil
            if (aborted) then
                return
            end

            local success, result = pcall(function()
                functions._emscripten_timeout(which, os.clock())
                if (noExitRt or rtKeepaliveCounter > 0) then return nil end

                --// dear luau, where is my (boolean, string?) ????????????????????????
                local exitOk: boolean, exitResult: string = (pcall :: any)(proc_exit, exitStatus :: number)
                if exitOk then return nil end

                if (string.match(exitResult, "ExitStatus:") ~= nil) or (exitResult == "unwind") then
                    return exitStatus
                end

                error(exitResult, 0)
            end :: () -> (number | string | nil))

            if (not success) then
                if ((typeof(result) == "string") and (string.match(result, "ExitStatus:") ~= nil)) or (result == "unwind") then
                    return
                end
                error(result, 0)
            end
        end)

        timers[which] = { thread = thread, timeoutMs = timeoutMs }
        return 0
    end

    return {
        fd_flush = fd_flush,
        fd_write = fd_write,

        __cxa_throw = __cxa_throw,
        _abort_js   = _abort_js,
        proc_exit   = proc_exit,

        _emscripten_throw_longjmp           = _emscripten_throw_longjmp,
        _emscripten_runtime_keepalive_clear = _emscripten_runtime_keepalive_clear,
        emscripten_resize_heap              = emscripten_resize_heap,

        _setitimer_js = _setitimer_js,
    }
end
