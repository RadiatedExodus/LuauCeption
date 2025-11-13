local common_polyfill_create = require("../Common/polyfill")

return function(utils: typeof(require("../Common/utils")()))
    local rt, memory_at_0, cfns, INDIRECT_FUNCTIONS
    local polyfill, common_polyfill_ready = common_polyfill_create(utils)

    local NOW_TIME = os.time() * 1000

    function polyfill.emscripten_date_now()
        return NOW_TIME + os.clock() * 1000
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

    return polyfill, function(_rt: any, _memory_at_0: any, _cfns: any, _INDIRECT_FUNCTIONS: any)
        rt, memory_at_0, cfns, INDIRECT_FUNCTIONS = _rt, _memory_at_0, _cfns, _INDIRECT_FUNCTIONS
        common_polyfill_ready(_rt, _memory_at_0, _cfns, _INDIRECT_FUNCTIONS)
    end
end
