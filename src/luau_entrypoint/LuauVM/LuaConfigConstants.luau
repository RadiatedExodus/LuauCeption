--!strict
local LuaStack = require("./LuaStack")
local LuaConfigConstants = table.freeze({
    LUA_IDSIZE            = 256,
    LUA_MINSTACK          = 20,
    LUAI_MAXCSTACK        = LuaStack.LUAI_MAXCSTACK,
    LUAI_MAXCALLS         = 20000,
    LUAI_MAXCCALLS        = 200,
    LUA_BUFFERSIZE        = 512,
    LUA_UTAG_LIMIT        = 128,
    LUA_LUTAG_LIMIT       = 128,
    LUA_SIZECLASSES       = 40,
    LUA_MEMORY_CATEGORIES = 256,
    LUA_MINSTRTABSIZE     = 32,
    LUA_MAXCAPTURES       = 32,
    LUA_VECTOR_SIZE       = 3,
    LUA_EXTRA_SIZE        = 1,
})
return LuaConfigConstants