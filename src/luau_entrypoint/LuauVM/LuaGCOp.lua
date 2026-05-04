--!strict
export type LuaGCOp = number
local LuaGCOp = table.freeze({
    LUA_GCSTOP = 0,
    LUA_GCRESTART = 1,
    LUA_GCCOLLECT = 2,
    LUA_GCCOUNT = 3,
    LUA_GCCOUNTB = 4,
    LUA_GCISRUNNING = 5,
    LUA_GCSETGOAL = 6,
    LUA_GCSETSTEPMUL = 7,
    LUA_GCSETSTEPSIZE = 8,
})
return LuaGCOp