local common_polyfill_create = require("../Common/polyfill")

return function(utils: typeof(require("../Common/utils")()))
    local rt, memory_at_0, cfns, INDIRECT_FUNCTIONS
    local polyfill, common_polyfill_ready = common_polyfill_create(utils)

    local START_CLOCK, NOW_TIME = os.clock(), os.time() * 1000

    -- returns time since the instance was initialized
    local function now_clock(): number
        return os.clock() - START_CLOCK
    end

    function polyfill.emscripten_date_now()
        return NOW_TIME + now_clock() * 1000
    end
    
    function polyfill._localtime_js(timer, buf)
        local now = os.time()
        local local_tdata = os.date("*t", rt.i64.into_u64(timer))
        local gmt_offset = os.difftime(now, os.time(os.date("!*t", rt.i64.into_u64(timer))))

        --// https://en.cppreference.com/w/cpp/chrono/c/tm
        rt.store.i32(memory_at_0, buf + 0, local_tdata.sec) --// int tm_sec
        rt.store.i32(memory_at_0, buf + 4, local_tdata.min) --// int tm_min
        rt.store.i32(memory_at_0, buf + 8, local_tdata.hour) --// int tm_hour
        rt.store.i32(memory_at_0, buf + 12, local_tdata.day) --// int tm_mday
        rt.store.i32(memory_at_0, buf + 16, local_tdata.month - 1) --// int tm_mon
        rt.store.i32(memory_at_0, buf + 20, local_tdata.year - 1900) --// int tm_year
        rt.store.i32(memory_at_0, buf + 24, local_tdata.wday - 1) --// int tm_wday
        rt.store.i32(memory_at_0, buf + 28, local_tdata.yday - 1) --// int tm_yday
        rt.store.i32(memory_at_0, buf + 32, if local_tdata.isdst then 1 else 0) --// int tm_isdst
        rt.store.i32(memory_at_0, buf + 36, gmt_offset) --// long tm_gmtoff
    end

    function polyfill._gmtime_js(timer, buf)
        local now = os.time()
        local utc_tdata = os.date("!*t", rt.i64.into_u64(timer))
        local gmt_offset = os.difftime(now, os.time(utc_tdata))

        --// https://en.cppreference.com/w/cpp/chrono/c/tm
        rt.store.i32(memory_at_0, buf + 0, utc_tdata.sec) --// int tm_sec
        rt.store.i32(memory_at_0, buf + 4, utc_tdata.min) --// int tm_min
        rt.store.i32(memory_at_0, buf + 8, utc_tdata.hour) --// int tm_hour
        rt.store.i32(memory_at_0, buf + 12, utc_tdata.day) --// int tm_mday
        rt.store.i32(memory_at_0, buf + 16, utc_tdata.month - 1) --// int tm_mon
        rt.store.i32(memory_at_0, buf + 20, utc_tdata.year - 1900) --// int tm_year
        rt.store.i32(memory_at_0, buf + 24, utc_tdata.wday - 1) --// int tm_wday
        rt.store.i32(memory_at_0, buf + 28, utc_tdata.yday - 1) --// int tm_yday
        rt.store.i32(memory_at_0, buf + 32, if utc_tdata.isdst then 1 else 0) --// int tm_isdst
        rt.store.i32(memory_at_0, buf + 36, gmt_offset) --// long tm_gmtoff
    end

    function polyfill.clock_time_get(clock_id: number, _ignored_precision: boolean, ptime: number)
        if not (clock_id >= 0 and clock_id <= 3) then
            return 28
        end

        local time_now
        if clock_id == 0 then
            time_now = polyfill.emscripten_date_now()
        elseif true then -- if nowIsMonotonic is 1
            time_now = now_clock()
        end

        local nsec = math.round(time_now * 1000 * 1000)
        rt.store.i64(memory_at_0, ptime + 0, rt.i64.from_u64(nsec))
        return 0
    end

    return polyfill, function(_rt: any, _memory_at_0: any, _cfns: any, _INDIRECT_FUNCTIONS: any)
        rt, memory_at_0, cfns, INDIRECT_FUNCTIONS = _rt, _memory_at_0, _cfns, _INDIRECT_FUNCTIONS
        common_polyfill_ready(_rt, _memory_at_0, _cfns, _INDIRECT_FUNCTIONS)
    end
end
