--!strict
export type LuaStatus = number
local LuaStatus = table.freeze({
    LUA_OK = 0,
    LUA_YIELD = 1,
    LUA_ERRRUN = 2,
    LUA_ERRSYNTAX = 3,
    LUA_ERRMEM = 4,
    LUA_ERRERR = 5,
    LUA_BREAK = 6,
})
return LuaStatus