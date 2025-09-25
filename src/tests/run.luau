local frktest = require("@frktest/frktest")
local lune_console_reporter = require("@frktest/reporters/lune_console_reporter")
local process = require("@lune/process")

require("./suites/compiler")
require("./suites/vm")
require("./suites/full")

lune_console_reporter.init()
local testOk = frktest.run()
if (not testOk) then
    process.exit(1)
end
