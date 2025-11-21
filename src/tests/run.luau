local frktest = require("@frktest/frktest")
local console_reporter = require("@frktest/reporters/console_reporter")
local process = require("@lune/process")

require("./suites/compiler")
require("./suites/vm")
require("./suites/full")

console_reporter.init()
local testOk = frktest.run()
if (not testOk) then
    process.exit(1)
end
