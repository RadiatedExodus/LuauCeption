--!strict
local LuaTypes = table.freeze({
    LUA_TNONE          = -1,
    LUA_TNIL           = 0,
    LUA_TBOOLEAN       = 1,
    LUA_TLIGHTUSERDATA = 2,
    LUA_TNUMBER        = 3,
    LUA_TINTEGER       = 4,
    LUA_TVECTOR        = 5,
    LUA_TSTRING        = 6,
    LUA_TTABLE         = 7,
    LUA_TFUNCTION      = 8,
    LUA_TUSERDATA      = 9,
    LUA_TTHREAD        = 10,
    LUA_TBUFFER        = 11,
    LUA_TPROTO         = 12,
    LUA_TUPVAL         = 13,
    LUA_TDEADKEY       = 14,
    LUA_T_COUNT        = 12, --// the same as LUA_TPROTO
})
return LuaTypes