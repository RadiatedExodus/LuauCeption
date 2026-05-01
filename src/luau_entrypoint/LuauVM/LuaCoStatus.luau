--!strict
export type LuaCoStatus = number
local LuaCoStatus = table.freeze({
    LUA_CORUN = 0,
    LUA_COSUS = 1,
    LUA_CONOR = 2,
    LUA_COFIN = 3,
    LUA_COERR = 4,
})
return LuaCoStatus