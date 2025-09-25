local task = task or (require)("@lune/task")

return function(utils: typeof(require("./utils")()))
    local rt, memory_at_0, cfns, INDIRECT_FUNCTIONS
    local polyfill = {}

    local NOW_TIME = os.time() * 1000
    local FILE_MAP = { {}, {} }
    local __TIMERS = {}
    local __EXIT_STATUS = nil
    local __ABORT_WASM = false
    local __NO_EXIT_RUNTIME = true
    local __RUNTIME_KEEPALIVE_COUNTER = 0

    local function fd_flush(file: {string})
        local final = table.concat(file)
        local last = 1
        for index, data in string.gmatch(final, '()([^\n]*)\n') do
            last = index + #data
            print(data)
        end
        table.clear(file)
        file[1] = string.sub(final, last + 1)
    end

    local function invokeHandler(index: number)
        return function(fnIndex: number, ...)
            local stack_ptr = cfns.emscripten_stack_get_current()
            local err, stacktrace = "N/A", "N/A"
            local success = xpcall(INDIRECT_FUNCTIONS.data[fnIndex], function(_e)err,stacktrace = _e,debug.traceback()end, ...)
            if success then
                return
            end

            cfns._emscripten_stack_restore(stack_ptr)
            if typeof(err) == "string" then
                error(`{err}\n\ninvoke stacktrace:\n{stacktrace}`, 2)
            end

            cfns.setThrew(1, 0)
        end
    end

    polyfill.invoke_vii = invokeHandler(1)
    polyfill._tzset_js = utils.stub("_tzset_js", 0)

    function polyfill.__cxa_throw(ptr, type, destructor)
        local info = utils.newCException(type)
        assert(false, `exception occured in c: {info:_UndecoratedName()} ({info:vfptr()})`)
    end

    function polyfill._abort_js(reason: any)
        assert(false, `Aborted({reason})`)
    end

    function polyfill.emscripten_date_now()
        return NOW_TIME + os.clock() * 1000
    end

    function polyfill._emscripten_throw_longjmp()
        return error("Infinity", 0)
    end

    function polyfill._emscripten_runtime_keepalive_clear()
        __NO_EXIT_RUNTIME, __RUNTIME_KEEPALIVE_COUNTER = false, 0
    end

    function polyfill.emscripten_resize_heap(_requestedSize: number)
        assert(false, "OOM")
    end

    function polyfill._setitimer_js(which, timeoutMs)
        if (not task) then
            print("program is using _setitimer_js but task library not found, timers will NOT work.")
            return 0
        end

        if (__TIMERS[which]) then
            task.cancel(__TIMERS[which].thread)
            __TIMERS[which] = nil
        end
        if (not timeoutMs or timeoutMs == 0) then
            return 0
        end

        local thread = task.delay(function()
            __TIMERS[which] = nil
            if (__ABORT_WASM) then
                return
            end

            local success, err = pcall(function()
                cfns._emscripten_timeout(which, os.clock())
                if (__NO_EXIT_RUNTIME or __RUNTIME_KEEPALIVE_COUNTER > 0) then
                    return
                end

                local exit_success, exit_err = pcall(polyfill.proc_exit, __EXIT_STATUS)
                if exit_success then
                    return
                end

                if (string.match(exit_err, "ExitStatus:") ~= nil or exit_err == "unwind") then
                    return __EXIT_STATUS
                end
                assert(false, exit_err)
            end)

            if (not success) then
                if (string.match(err, "ExitStatus:") ~= nil or err == "unwind") then
                    return
                end
                assert(false, err)
            end
        end, timeoutMs / 1000)

        __TIMERS[which] = { thread = thread, timeoutMs = timeoutMs }
        return 0
    end

    function polyfill._localtime_js(timer, buf)
        local tdata = os.date("*t", rt.i64.into_u64(timer))

        --// https://en.cppreference.com/w/cpp/chrono/c/tm
        rt.store.i32(memory_at_0, buf + 0, tdata.sec) --// int tm_sec
        rt.store.i32(memory_at_0, buf + 4, tdata.min) --// int tm_min
        rt.store.i32(memory_at_0, buf + 8, tdata.hour) --// int tm_hour
        rt.store.i32(memory_at_0, buf + 12, tdata.day) --// int tm_mday
        rt.store.i32(memory_at_0, buf + 16, tdata.month - 1) --// int tm_mon
        rt.store.i32(memory_at_0, buf + 20, tdata.year - 1900) --// int tm_year
        rt.store.i32(memory_at_0, buf + 24, tdata.wday) --// int tm_wday
        rt.store.i32(memory_at_0, buf + 28, tdata.yday) --// int tm_yday
        rt.store.i32(memory_at_0, buf + 32, if tdata.isdst then 1 else 0) --// int tm_isdst
    end

    function polyfill._gmtime_js(timer, buf)
        local tdata = os.date("!*t", rt.i64.into_u64(timer))

        --// https://en.cppreference.com/w/cpp/chrono/c/tm
        rt.store.i32(memory_at_0, buf + 0, tdata.sec) --// int tm_sec
        rt.store.i32(memory_at_0, buf + 4, tdata.min) --// int tm_min
        rt.store.i32(memory_at_0, buf + 8, tdata.hour) --// int tm_hour
        rt.store.i32(memory_at_0, buf + 12, tdata.day) --// int tm_mday
        rt.store.i32(memory_at_0, buf + 16, tdata.month - 1) --// int tm_mon
        rt.store.i32(memory_at_0, buf + 20, tdata.year - 1900) --// int tm_year
        rt.store.i32(memory_at_0, buf + 24, tdata.wday) --// int tm_wday
        rt.store.i32(memory_at_0, buf + 28, tdata.yday) --// int tm_yday
        rt.store.i32(memory_at_0, buf + 32, if tdata.isdst then 1 else 0) --// int tm_isdst
    end

    function polyfill.clock_time_get(clock_id: number, ignored_precision: boolean, ptime: number)
        if not (clock_id >= 0 and clock_id <= 3) then
            return 28
        end

        local time_now
        if clock_id == 0 then
            time_now = polyfill.emscripten_date_now()
        elseif true then -- if nowIsMonotonic is 1
            time_now = os.clock()
        end

        local nsec = math.round(time_now * 1000 * 1000)
        rt.store.i64(memory_at_0, ptime, rt.i64.from_u64(nsec))
        return 0
    end

    function polyfill.fd_write(fd, list, count, ret_pointer)
        local file = FILE_MAP[fd]
        if not file then return 8 end
        local total = 0
        for pointer = list, list + (count - 1) * 8, 8 do
            local start = rt.load.i32(memory_at_0, pointer)
            local len = rt.load.i32(memory_at_0, pointer + 4)
            local read = rt.load.string(memory_at_0, start, len)
            table.insert(file, read)
            total = total + #read
        end
        rt.store.i32(memory_at_0, ret_pointer, total)
        fd_flush(file)
        return 0
    end

    function polyfill.proc_exit(code: number)
        __EXIT_STATUS = code
        if (not (__NO_EXIT_RUNTIME or __RUNTIME_KEEPALIVE_COUNTER > 0)) then
            __ABORT_WASM = true
        end

        assert(false, `ExitStatus: Program exited with code ${code}`)
    end

    return polyfill, function(_rt: any, _memory_at_0: any, _cfns: any, _INDIRECT_FUNCTIONS: any)
        rt, memory_at_0, cfns, INDIRECT_FUNCTIONS = _rt, _memory_at_0, _cfns, _INDIRECT_FUNCTIONS
    end
end
