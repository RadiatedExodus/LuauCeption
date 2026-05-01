--!strict
local LuaStack = table.freeze({
    LUAI_MAXCSTACK    = 8000,
    LUA_REGISTRYINDEX = -8000 - 2000,
    LUA_ENVIRONINDEX  = -8000 - 2001,
    LUA_GLOBALSINDEX  = -8000 - 2002,
})
return LuaStack