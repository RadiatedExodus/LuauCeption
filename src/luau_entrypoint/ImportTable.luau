--!strict
local ExceptionInfo  = require("./ExceptionInfo")
local SpiderRuntime  = require("./SpiderRuntime")
local WasmModuleType = require("./WasmModuleType")

type HelperTable = typeof(require("./Helper")(nil :: any))

return function(module: WasmModuleType.WasmModule, helper: HelperTable)
    local ljmp_sign = helper.LJMPThrowObject
    local memory    = module.memory[1]                 :: buffer
    local functions = module                           :: WasmModuleType.WasmModule
    --// local ift       = module.__indirect_function_table :: {[number]: (...any) -> (...any)}
    local task      = helper.GetTaskLibrary()

    local fd_files           = { {}, {} } :: { { string } }
    local timers             = {}         :: { { thread: thread, timeoutMs: number } }
    local exitStatus         = nil        :: number?
    local aborted            = false      :: boolean
    local noExitRt           = true       :: boolean
    local rtKeepaliveCounter = 0          :: number
    local startClock         = os.clock()
    local nowTime            = os.time() * 1000

    local function fd_flush(file: {string}): number
        local final = table.concat(file)
        local last = 1
        for index, data in string.gmatch(final, '()([^\n]*)\n') do
            if (not data) then continue end
            last = index + #data
            print(data)
        end
        table.clear(file)
        file[1] = string.sub(final, last + 1)
        return 0
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

    local function _mmap_js(len: number, prot: number, flags: number, fd: number, offset: number, allocated: number, addr: number): number
        return -52
    end

    local function _munmap_js(addr: number, len: number, prot: number, flags: number, fd: number, offset: number): number
        return 0
    end

    local function __cxa_throw(ptr: number, type: number, destructor: number): never
        local info = ExceptionInfo.new(memory, ptr)
        info:Initialize(type, destructor)
        error(`exception occured in c: {info:GetUndecoratedName(functions.strlen)} ({ptr})`, 0)
    end

    local function _abort_js(reason: any): never
        error(`Aborted({reason})`, 0)
    end

    local function proc_exit(code: number): never
        exitStatus = code
        if (not (noExitRt or rtKeepaliveCounter > 0)) then
            aborted = true
        end
        error(`ExitStatus: Program exited with code ${code}`, 0)
    end

    local function _emscripten_throw_longjmp(): never
        return error(ljmp_sign, 0)
    end

    local function _emscripten_runtime_keepalive_clear(): number
        noExitRt           = false
        rtKeepaliveCounter = 0
        return 0
    end

    local function emscripten_resize_heap(_requestedSize: number)
        error("OOM", 0)
    end

    local function emscripten_get_now(): number
        return os.clock() - startClock
    end

    local function emscripten_date_now(): number
        return nowTime + emscripten_get_now() * 1000
    end

    local function _setitimer_js(which: number, timeoutMs: number): number | never
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
                    return 0
                end
                error(result, 0)
            end
        end)

        timers[which] = { thread = thread, timeoutMs = timeoutMs }
        return 0
    end

    local function _localtime_js(time: number, tmPtr: number): number
        time = SpiderRuntime.from_bits_i64(time)
        local now = os.time()
        local localData = os.date("*t", time)
        local gmtOffset = os.difftime(now, os.time(os.date("!*t", time)))

        --// reference: https://en.cppreference.com/w/cpp/chrono/c/tm
        buffer.writei32(memory, tmPtr + 0,  localData.sec)                      --// int tm_sec
        buffer.writei32(memory, tmPtr + 4,  localData.min)                      --// int tm_min
        buffer.writei32(memory, tmPtr + 8,  localData.hour)                     --// int tm_hour
        buffer.writei32(memory, tmPtr + 12, localData.day)                      --// int tm_mday
        buffer.writei32(memory, tmPtr + 16, localData.month - 1)                --// int tm_mon
        buffer.writei32(memory, tmPtr + 20, localData.year - 1900)              --// int tm_year
        buffer.writei32(memory, tmPtr + 24, localData.wday - 1)                 --// int tm_wday
        buffer.writei32(memory, tmPtr + 28, localData.yday - 1)                 --// int tm_yday
        buffer.writei32(memory, tmPtr + 32, if (localData.isdst) then 1 else 0) --// int tm_isdst
        buffer.writei32(memory, tmPtr + 36, gmtOffset)                          --// long tm_gmtoff

        return 0
    end

    local function _gmtime_js(time: number, tmPtr: number): number
        time = SpiderRuntime.from_bits_i64(time)
        local now = os.time()
        local utcData = os.date("!*t", time)
        local gmtOffset = os.difftime(now, os.time(utcData))

        --// reference: https://en.cppreference.com/w/cpp/chrono/c/tm
        buffer.writei32(memory, tmPtr + 0,  utcData.sec)                      --// int tm_sec
        buffer.writei32(memory, tmPtr + 4,  utcData.min)                      --// int tm_min
        buffer.writei32(memory, tmPtr + 8,  utcData.hour)                     --// int tm_hour
        buffer.writei32(memory, tmPtr + 12, utcData.day)                      --// int tm_mday
        buffer.writei32(memory, tmPtr + 16, utcData.month - 1)                --// int tm_mon
        buffer.writei32(memory, tmPtr + 20, utcData.year - 1900)              --// int tm_year
        buffer.writei32(memory, tmPtr + 24, utcData.wday - 1)                 --// int tm_wday
        buffer.writei32(memory, tmPtr + 28, utcData.yday - 1)                 --// int tm_yday
        buffer.writei32(memory, tmPtr + 32, if (utcData.isdst) then 1 else 0) --// int tm_isdst
        buffer.writei32(memory, tmPtr + 36, gmtOffset)                        --// long tm_gmtoff

        return 0
    end

    local function _tzset_js(timezone: number, daylight: number, stdName: number, dstName: number): number
        local currentYear       = os.date("*t").year
        local winter            = os.time({ year = currentYear, month = 1, day = 1, hour = 0, min = 0, sec = 0 })
        local summer            = os.time({ year = currentYear, month = 7, day = 1, hour = 0, min = 0, sec = 0 })
        local winterOffset      = math.round(os.difftime(os.time(os.date("!*t", winter)), os.time(os.date("*t", winter))) / 60)
        local summerOffset      = math.round(os.difftime(os.time(os.date("!*t", summer)), os.time(os.date("*t", summer))) / 60)
        local stdTimezoneOffset = math.max(winterOffset, summerOffset)
        local winterName        = helper.ExtractZone(winterOffset)
        local summerName        = helper.ExtractZone(summerOffset)

        buffer.writeu32(memory, bit32.rshift(timezone, 2), stdTimezoneOffset * 60)
        buffer.writei32(memory, bit32.rshift(daylight, 2), if (winterOffset ~= summerOffset) then 1 else 0)

        if (summerOffset < winterOffset) then
            buffer.writestring(memory, stdName, winterName.."\0")
            buffer.writestring(memory, dstName, summerName.."\0")
        else
            buffer.writestring(memory, dstName, summerName.."\0")
            buffer.writestring(memory, stdName, winterName.."\0")
        end
        
        return 0
    end

    local function clock_time_get(clkId: number, ignoredPrecision: boolean, pTime: number): number
        if (not (clkId >= 0 and clkId <= 3)) then return 28 end

        local now: number
        if (clkId == 0) then
            now = emscripten_date_now()
        else
            now = emscripten_get_now()
        end

        local nsec = SpiderRuntime.from_bits_i64(math.round(now * 1000 * 1000))
        SpiderRuntime.rt_store_i64(module.memory, pTime + 0, nsec)
        return 0
    end

    return {
        fd_flush   = fd_flush,
        fd_write   = fd_write,
        _mmap_js   = _mmap_js,
        _munmap_js = _munmap_js,

        __cxa_throw = __cxa_throw,
        _abort_js   = _abort_js,
        proc_exit   = proc_exit,

        _emscripten_throw_longjmp           = _emscripten_throw_longjmp,
        _emscripten_runtime_keepalive_clear = _emscripten_runtime_keepalive_clear,
        emscripten_resize_heap              = emscripten_resize_heap,
        emscripten_get_now                  = emscripten_get_now,
        emscripten_date_now                 = emscripten_date_now,

        _setitimer_js  = _setitimer_js,
        _localtime_js  = _localtime_js,
        _gmtime_js     = _gmtime_js,
        _tzset_js      = _tzset_js,
        clock_time_get = clock_time_get,
    }
end
