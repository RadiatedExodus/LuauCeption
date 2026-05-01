--!strict
local WasmModule      = require("./WasmModuleType")
local HelperInit      = require("./Helper")
local ImportTableInit = require("./ImportTable")
local SpiderRuntime   = require("./SpiderRuntime")

--// enums
local LuaStatus          = require("./LuauVM/LuaStatus")
local LuaCoStatus        = require("./LuauVM/LuaCoStatus")
local LuaGCOp            = require("./LuauVM/LuaGCOp")
local LuaConfigConstants = require("./LuauVM/LuaConfigConstants")
local LuaStack           = require("./LuauVM/LuaStack")
local LuaLibraryName     = require("./LuauVM/LuaLibraryName")
local LuaTypes           = require("./LuauVM/LuaTypes")
local LuaReferenceMacro  = require("./LuauVM/LuaReferenceMacro")

local LuauVM = {}
LuauVM.__index = LuauVM

export type Pointer         = number
export type LuaCFunction    = (Pointer) -> (number)
export type LuaContinuation = (Pointer, number) -> (number)
export type LuaDestructor   = (Pointer, number) -> (number)
export type LuaAlloc        = (Pointer, Pointer, number, number) -> (Pointer)

--// ChildStateVMs should be nil if it has a Parent
--// Parent should be nil if it has ChildStateVMs
export type LuauVM = typeof(setmetatable({} :: {
    WASM:          WasmModule.WasmModule,
    Memory:        buffer,
    ImportTable:   {[string]: (...any) -> (...any)},
    Helper:        typeof(HelperInit(nil :: any)),
    State:         number,
    ChildStateVMs: { LuauVM }?,
    Parent:        LuauVM?,
}, LuauVM))

--// LuauCeption - State manipulation additions
function LuauVM.IsMainState(self: LuauVM): boolean
    return self.ChildStateVMs ~= nil
end

function LuauVM.IsChildState(self: LuauVM): boolean
    return self.Parent ~= nil
end

--// State manipulation
function LuauVM.Close(self: LuauVM)
    --// a note that if this is a newthread state
    --// then closing would close the original state
    self.WASM.lua_close(self.State)

    if (self.Parent) then
        self.Parent.State = 0
        for _, vm in self.Parent.ChildStateVMs :: { LuauVM } do
            vm.State = 0
        end
    elseif (self.ChildStateVMs) then
        self.State = 0
        for _, vm in self.ChildStateVMs do
            vm.State = 0
        end
    end

    return
end

function LuauVM.NewThread(self: LuauVM): LuauVM
    local state = self.WASM.lua_newthread(self.State)
    local mainVM: LuauVM = self

    --// find main vm
    --// incase this was called from a newthread state
    --// which the parent would still be the original vm
    while (mainVM.Parent) do
        mainVM = mainVM.Parent
    end
    assert(mainVM.ChildStateVMs, `BUG: newthread - mainVM does not have ChildStateVMs`)

    local new   = setmetatable({
        WASM        = self.WASM,
        Memory      = self.Memory,
        ImportTable = self.ImportTable,
        Helper      = self.Helper,
        State       = state,
        Parent      = mainVM,
    }, LuauVM)
    table.insert(mainVM.ChildStateVMs, new)

    return new
end

function LuauVM.MainThread(self: LuauVM): LuauVM
    local mainState = self.WASM.lua_mainthread(self.State)

    --// find the main vm
    local mainVM: LuauVM = self
    while (mainVM.Parent) do
        mainVM = mainVM.Parent
    end
    assert(mainState == mainVM.State, "BUG: mainthread - parent state mismatch???")
    assert(mainVM.ChildStateVMs, `BUG: mainthread - mainVM does not have ChildStateVMs`)

    return mainVM
end

function LuauVM.ResetThread(self: LuauVM)
    self.WASM.lua_resetthread(self.State)
    return
end

function LuauVM.IsThreadReset(self: LuauVM): boolean
    return self.WASM.lua_isthreadreset(self.State) == 1
end

--// Basic stack manipulation
function LuauVM.AbsIndex(self: LuauVM, idx: number): number
    return self.WASM.lua_absindex(self.State, idx)
end

function LuauVM.GetTop(self: LuauVM): number
    return self.WASM.lua_gettop(self.State)
end

function LuauVM.SetTop(self: LuauVM, idx: number)
    self.WASM.lua_settop(self.State, idx)
    return
end

function LuauVM.PushValue(self: LuauVM, idx: number)
    self.WASM.lua_pushvalue(self.State, idx)
    return
end

function LuauVM.Remove(self: LuauVM, idx: number)
    self.WASM.lua_remove(self.State, idx)
    return
end

function LuauVM.Insert(self: LuauVM, idx: number)
    self.WASM.lua_insert(self.State, idx)
    return
end

function LuauVM.Replace(self: LuauVM, idx: number)
    self.WASM.lua_replace(self.State, idx)
end

function LuauVM.CheckStack(self: LuauVM, sz: number): number
    return self.WASM.lua_checkstack(self.State, sz)
end

function LuauVM.RawCheckStack(self: LuauVM, sz: number)
    self.WASM.lua_rawcheckstack(self.State, sz)
    return
end

function LuauVM.XMove(self: LuauVM, from: LuauVM, n: number)
    self.WASM.lua_xmove(from.State, self.State, n)
end

function LuauVM.XPush(self: LuauVM, from: LuauVM, idx: number)
    self.WASM.lua_xpush(from.State, self.State, idx)
    return
end

--// Access functions
function LuauVM.IsNumber(self: LuauVM, idx: number): boolean
    return self.WASM.lua_isnumber(self.State, idx) == 1
end

function LuauVM.IsString(self: LuauVM, idx: number): boolean
    return self.WASM.lua_isstring(self.State, idx) == 1
end

function LuauVM.IsInteger64(self: LuauVM, idx: number): boolean
    return self.WASM.lua_isinteger64(self.State, idx) == 1
end

function LuauVM.IsCFunction(self: LuauVM, idx: number): boolean
    return self.WASM.lua_iscfunction(self.State, idx) == 1
end

function LuauVM.IsLFunction(self: LuauVM, idx: number): boolean
    return self.WASM.lua_isLfunction(self.State, idx) == 1
end

function LuauVM.IsUserdata(self: LuauVM, idx: number): boolean
    return self.WASM.lua_isuserdata(self.State, idx) == 1
end

function LuauVM.Type(self: LuauVM, idx: number): number
    return self.WASM.lua_type(self.State, idx)
end

function LuauVM.TypeName(self: LuauVM, tp: number): string
    local ptr = self.WASM.lua_typename(self.State, tp)
    local len = self.WASM.strlen(ptr)
    return buffer.readstring(self.Memory, ptr, len)
end

function LuauVM.Equal(self: LuauVM, idx1: number, idx2: number): boolean
    return self.WASM.lua_equal(self.State, idx1, idx2) == 1
end

function LuauVM.RawEqual(self: LuauVM, idx1: number, idx2: number): boolean
    return self.WASM.lua_rawequal(self.State, idx1, idx2) == 1
end

function LuauVM.LessThan(self: LuauVM, idx1: number, idx2: number): boolean
    return self.WASM.lua_lessthan(self.State, idx1, idx2) == 1
end

function LuauVM.ToNumberX(self: LuauVM, idx: number): (boolean, number)
    local isNumPtr  = self.WASM.malloc(4)
    local result    = self.WASM.lua_tonumberx(self.State, idx, isNumPtr)
    local convertOk = buffer.readi32(self.Memory, isNumPtr) == 1
    self.WASM.free(isNumPtr)
    return convertOk, result
end

function LuauVM.ToIntegerX(self: LuauVM, idx: number): (boolean, number)
    local isNumPtr  = self.WASM.malloc(4)
    local result    = self.WASM.lua_tointegerx(self.State, idx, isNumPtr)
    local convertOk = buffer.readi32(self.Memory, isNumPtr) == 1
    self.WASM.free(isNumPtr)
    return convertOk, result
end

function LuauVM.ToUnsignedX(self: LuauVM, idx: number): (boolean, number)
    local isNumPtr  = self.WASM.malloc(4)
    local result    = self.WASM.lua_tounsignedx(self.State, idx, isNumPtr)
    local convertOk = buffer.readi32(self.Memory, isNumPtr) == 1
    self.WASM.free(isNumPtr)
    return convertOk, result
end

function LuauVM.ToVector(self: LuauVM, idx: number): (number, number, number)
    return table.unpack(self.Helper.ReadVectorFloatArray(self.WASM.lua_tovector(self.State, idx)))
end

function LuauVM.ToBoolean(self: LuauVM, idx: number): boolean
    return (self.WASM.lua_toboolean(self.State, idx) == 1)
end

function LuauVM.ToInteger64(self: LuauVM, idx: number): (boolean, number)
    local isIntegerPtr = self.WASM.malloc(4)
    local resultRaw    = self.WASM.lua_tointeger64(self.State, idx, isIntegerPtr)
    local convertOk    = buffer.readi32(self.Memory, isIntegerPtr) == 1
    local result, _    = SpiderRuntime.from_bits_i64(SpiderRuntime.rt_load_i64(self.WASM.memory, resultRaw))
    self.WASM.free(isIntegerPtr)
    return convertOk, result
end

function LuauVM.ToLString(self: LuauVM, idx: number): string
    local lenPtr = self.WASM.malloc(4)
    local strPtr = self.WASM.lua_tolstring(self.State, idx, lenPtr)
    local length = buffer.readi32(self.Memory, lenPtr)
    self.WASM.free(lenPtr)
    return buffer.readstring(self.Memory, strPtr, length)
end

function LuauVM.ToStringAtom(self: LuauVM, idx: number): (Pointer, number)
    local atomPtr = self.WASM.malloc(4)
    local result  = self.WASM.lua_tostringatom(self.State, idx, atomPtr)
    local atom    = buffer.readi32(self.Memory, atomPtr)
    self.WASM.free(atomPtr)
    return result, atom
end

function LuauVM.ToLStringAtom(self: LuauVM, idx: number): (string, number)
    local atomPtr = self.WASM.malloc(4)
    local lenPtr  = self.WASM.malloc(4)
    local strPtr  = self.WASM.lua_tolstringatom(self.State, idx, lenPtr, atomPtr)
    local atom    = buffer.readi32(self.Memory, atomPtr)
    local length  = buffer.readi32(self.Memory, lenPtr)
    self.WASM.free(atomPtr)
    self.WASM.free(lenPtr)
    return buffer.readstring(self.Memory, strPtr, length), atom
end

function LuauVM.NamecallAtom(self: LuauVM, idx: number): (Pointer, number)
    local atomPtr = self.WASM.malloc(4)
    local result  = self.WASM.lua_namecallatom(self.State, idx, atomPtr)
    local atom    = buffer.readi32(self.Memory, atomPtr)
    self.WASM.free(atomPtr)
    return result, atom
end

function LuauVM.ObjLen(self: LuauVM, idx: number): number
    return self.WASM.lua_objlen(self.State, idx)
end

function LuauVM.ToCFunction(self: LuauVM, idx: number): LuaCFunction
    return self.WASM.__indirect_function_table[self.WASM.lua_tocfunction(self.State, idx)]
end

function LuauVM.ToLightUserdata(self: LuauVM, idx: number): Pointer
    return self.WASM.lua_tolightuserdata(self.State, idx)
end

function LuauVM.ToLightUserdataTagged(self: LuauVM, idx: number, tag: number): Pointer
    return self.WASM.lua_tolightuserdatatagged(self.State, idx, tag)
end

function LuauVM.ToUserdata(self: LuauVM, idx: number): Pointer
    return self.WASM.lua_touserdata(self.State, idx)
end

function LuauVM.ToUserdataTagged(self: LuauVM, idx: number, tag: number): Pointer
    return self.WASM.lua_touserdatatagged(self.State, idx, tag)
end

function LuauVM.UserdataTag(self: LuauVM, idx: number): number
    return self.WASM.lua_userdatatag(self.State, idx)
end

function LuauVM.LightUserdataTag(self: LuauVM, idx: number): number
    return self.WASM.lua_lightuserdatatag(self.State, idx)
end

function LuauVM.ToThread(self: LuauVM, idx: number): LuauVM
    local statePtr = self.WASM.lua_tothread(self.State, idx)

    --// find LuauVM object for this state
    local foundVM: LuauVM
    if (self.ChildStateVMs) then
        for _, vm in self.ChildStateVMs do
            if (vm.State == statePtr) then
                foundVM = vm
                break
            end
        end
    elseif (self.Parent) then
        for _, vm in self.Parent.ChildStateVMs :: { LuauVM } do
            if (vm.State == statePtr) then
                foundVM = vm
                break
            end
        end
    else --// assume theres no LuauVM yet so make a new one
        local parentVM: LuauVM = (if (self.ChildStateVMs) then self else self.Parent) :: any
        foundVM = setmetatable({
            WASM        = self.WASM,
            Memory      = self.Memory,
            ImportTable = self.ImportTable,
            Helper      = self.Helper,
            State       = statePtr,
            Parent      = parentVM,
        }, LuauVM)
        table.insert(parentVM.ChildStateVMs :: { LuauVM }, foundVM)
    end

    return foundVM
end

function LuauVM.ToBuffer(self: LuauVM, idx: number): (Pointer, number)
    local lenPtr = self.WASM.malloc(4)
    local result = self.WASM.lua_tobuffer(self.State, idx, lenPtr)
    local length = buffer.readi32(self.Memory, lenPtr)
    self.WASM.free(lenPtr)
    return result, length
end

function LuauVM.ToPointer(self: LuauVM, idx: number): Pointer
    return self.WASM.lua_topointer(self.State, idx)
end

--// Push functions
function LuauVM.PushNil(self: LuauVM)
    self.WASM.lua_pushnil(self.State)
    return
end

function LuauVM.PushNumber(self: LuauVM, n: number)
    self.WASM.lua_pushnumber(self.State, n)
    return
end

function LuauVM.PushInteger(self: LuauVM, n: number)
    self.WASM.lua_pushinteger(self.State, n)
    return
end

function LuauVM.PushInteger64(self: LuauVM, n: number)
    self.WASM.lua_pushinteger64(self.State, SpiderRuntime.into_bits_i64(n, 0))
    return
end

function LuauVM.PushUnsigned(self: LuauVM, n: number)
    self.WASM.lua_pushunsigned(self.State, n)
    return
end

function LuauVM.PushVector(self: LuauVM, x: number, y: number, z: number)
    self.WASM.lua_pushvector(self.State, SpiderRuntime.into_bits_f32(x), SpiderRuntime.into_bits_f32(y), SpiderRuntime.into_bits_f32(z))
    return
end

function LuauVM.PushLString(self: LuauVM, s: Pointer, l: Pointer)
    self.WASM.lua_pushlstring(self.State, s, l)
    return
end

function LuauVM.PushString(self: LuauVM, s: string)
    local sPtr = self.Helper.CreateString(s)
    self.WASM.lua_pushstring(self.State, sPtr)
    self.WASM.free(sPtr)
    return
end

function LuauVM.PushVFString(self: LuauVM, fmt: string, argp: Pointer): string
    local fmtPtr = self.Helper.CreateString(fmt)
    local result = self.WASM.lua_pushvfstring(self.State, fmtPtr, argp)
    local length = self.WASM.strlen(result)
    self.WASM.free(fmtPtr)
    return buffer.readstring(self.Memory, result, length)
end

function LuauVM.PushFStringL(self: LuauVM, fmt: string, ...): string
    local fmtPtr = self.Helper.CreateString(fmt)
    local result = self.WASM.lua_pushfstringL(self.State, fmtPtr, ...)
    local length = self.WASM.strlen(result)
    self.WASM.free(fmtPtr)
    return buffer.readstring(self.Memory, result, length)
end

function LuauVM.PushCClosureK(self: LuauVM, fn: LuaCFunction, debugName: string, nup: number, cont: LuaContinuation | number)
    local fnIdx = self.Helper.InjectFunction(fn)
    local ctIdx = if (typeof(cont) == "number") then cont else self.Helper.InjectFunction(cont)
    local dnPtr = self.Helper.CreateString(debugName)
    self.WASM.lua_pushcclosurek(self.State, fnIdx, dnPtr, nup, ctIdx)
    self.WASM.free(dnPtr)
    return
end

function LuauVM.PushBoolean(self: LuauVM, b: boolean)
    self.WASM.lua_pushboolean(self.State, if (b) then 1 else 0)
    return
end

function LuauVM.PushThread(self: LuauVM): number
    return self.WASM.lua_pushthread(self.State)
end

function LuauVM.PushLightUserdataTagged(self: LuauVM, p: Pointer, tag: number)
    self.WASM.lua_pushlightuserdatatagged(self.State, p, tag)
    return
end

function LuauVM.NewUserdataTagged(self: LuauVM, sz: number, tag: number): Pointer
    local result = self.WASM.lua_newuserdatatagged(self.State, sz, tag)
    return result
end

function LuauVM.NewUserdataTaggedWithMetatable(self: LuauVM, sz: number, tag: number): Pointer
    local result = self.WASM.lua_newuserdatataggedwithmetatable(self.State, sz, tag)
    return result
end

function LuauVM.NewUserdataWithDestructor(self: LuauVM, sz: number, dtor: (number) -> ()): Pointer
    local dtorIdx = self.Helper.InjectFunction(dtor)
    local result = self.WASM.lua_newuserdatadtor(self.State, sz, dtorIdx)
    return result
end

function LuauVM.NewBuffer(self: LuauVM, sz: number): Pointer
    return self.WASM.lua_newbuffer(self.State, sz)
end

--// Get functions
function LuauVM.GetTable(self: LuauVM, idx: number): number
    return self.WASM.lua_gettable(self.State, idx)
end

function LuauVM.GetField(self: LuauVM, idx: number, k: string): number
    local kPtr   = self.Helper.CreateString(k)
    local result = self.WASM.lua_getfield(self.State, idx, kPtr)
    self.WASM.free(kPtr)
    return result
end

function LuauVM.RawGetField(self: LuauVM, idx: number, k: string): number
    local kPtr   = self.Helper.CreateString(k)
    local result = self.WASM.lua_rawgetfield(self.State, idx, kPtr)
    self.WASM.free(kPtr)
    return result
end

function LuauVM.RawGet(self: LuauVM, idx: number): number
    return self.WASM.lua_rawget(self.State, idx)
end

function LuauVM.RawGetI(self: LuauVM, idx: number, n: number): number
    return self.WASM.lua_rawgeti(self.State, idx, n)
end

function LuauVM.RawGetPtagged(self: LuauVM, idx: number, p: Pointer, tag: number): number
    return self.WASM.lua_rawgetptagged(self.State, idx, p, tag)
end

function LuauVM.CreateTable(self: LuauVM, nArr: number, nRec: number)
    self.WASM.lua_createtable(self.State, nArr, nRec)
    return
end

function LuauVM.SetReadOnly(self: LuauVM, idx: number, enabled: boolean)
    self.WASM.lua_setreadonly(self.State, idx, if (enabled) then 1 else 0)
    return
end

function LuauVM.GetReadOnly(self: LuauVM, idx: number): boolean
    return self.WASM.lua_getreadonly(self.State, idx) == 1
end

function LuauVM.SetSafeEnv(self: LuauVM, idx: number, enabled: boolean)
    self.WASM.lua_setsafeenv(self.State, idx, if (enabled) then 1 else 0)
    return
end

function LuauVM.GetMetatable(self: LuauVM, objIndex: number): number
    return self.WASM.lua_getmetatable(self.State, objIndex)
end

function LuauVM.GetFunctionEnvironment(self: LuauVM, idx: number)
    self.WASM.lua_getfenv(self.State, idx)
    return
end

--// Set functions
function LuauVM.SetTable(self: LuauVM, idx: number)
    self.WASM.lua_settable(self.State, idx)
    return
end

function LuauVM.SetField(self: LuauVM, idx: number, k: string)
    local kPtr = self.Helper.CreateString(k)
    self.WASM.lua_setfield(self.State, idx, kPtr)
    self.WASM.free(kPtr)
    return
end

function LuauVM.RawSetField(self: LuauVM, idx: number, k: string)
    local kPtr = self.Helper.CreateString(k)
    self.WASM.lua_rawsetfield(self.State, idx, kPtr)
    self.WASM.free(kPtr)
    return
end

function LuauVM.RawSet(self: LuauVM, idx: number)
    self.WASM.lua_rawset(self.State, idx)
    return
end

function LuauVM.RawSetI(self: LuauVM, idx: number)
    self.WASM.lua_rawseti(self.State, idx)
    return
end

function LuauVM.RawSetPtagged(self: LuauVM, idx: number, p: Pointer, tag: number)
    self.WASM.lua_rawsetptagged(self.State, idx, p, tag)
    return
end

function LuauVM.SetMetatable(self: LuauVM, objIndex: number): number
    return self.WASM.lua_setmetatable(self.State, objIndex)
end

function LuauVM.SetFunctionEnvironment(self: LuauVM, idx: number): number
    return self.WASM.lua_setfenv(self.State, idx)
end

--// Call functions
function LuauVM.Load(self: LuauVM, bytecode: string, chunkName: string?, env: number?): boolean
    chunkName = chunkName or "LuauCeptionChunk"
    env       = env or 0

    local bcPtr   = self.Helper.CreateString(bytecode)
    local cnPtr   = self.Helper.CreateString(chunkName :: string)
    local success = self.WASM.luau_load(self.State, cnPtr, bcPtr, #bytecode, env)

    self.WASM.free(bcPtr)
    self.WASM.free(cnPtr)
    return success == 0
end

function LuauVM.Call(self: LuauVM, nArgs: number?, nResults: number?)
    self.WASM.lua_call(self.State, nArgs, nResults)
    return
end

function LuauVM.ProtectedCall(self: LuauVM, nArgs: number?, nResults: number?, errFunc: number?): LuaStatus.LuaStatus
    return self.WASM.lua_pcall(self.State, nArgs or 0, nResults or 0, errFunc or 0)
end

function LuauVM.CProtectedCall(self: LuauVM, func: LuaCFunction | number, ud: Pointer?): LuaStatus.LuaStatus
    return self.WASM.lua_cpcall(self.State, if (typeof(func) == "number") then func else self.Helper.InjectFunction(func), ud or 0)
end

--// Coroutine functions
function LuauVM.Yield(self: LuauVM, nResults: number): number
    return self.WASM.lua_yield(self.State, nResults)
end

function LuauVM.Break(self: LuauVM): number
    return self.WASM.lua_break(self.State)
end

function LuauVM.Resume(self: LuauVM, from: LuauVM, nArg: number): LuaStatus.LuaStatus
    return self.WASM.lua_resume(self.State, from.State, nArg)
end

function LuauVM.ResumeError(self: LuauVM, from: LuauVM): LuaStatus.LuaStatus
    return self.WASM.lua_resumeerror(self.State, from.State)
end

function LuauVM.Status(self: LuauVM): LuaStatus.LuaStatus
    return self.WASM.lua_status(self.State)
end

function LuauVM.IsYieldable(self: LuauVM): boolean
    return self.WASM.lua_isyieldable(self.State) == 1
end

function LuauVM.GetThreadData(self: LuauVM): Pointer
    return self.WASM.lua_getthreaddata(self.State)
end

function LuauVM.SetThreadData(self: LuauVM, data: Pointer)
    self.WASM.lua_setthreaddata(self.State, data)
    return
end

function LuauVM.CoStatus(self: LuauVM, co: LuauVM): LuaCoStatus.LuaCoStatus
    return self.WASM.lua_costatus(self.State, co.State)
end

--// Garbage collector
function LuauVM.GarbageCollector(self: LuauVM, what: LuaGCOp.LuaGCOp, data: number): number
    return self.WASM.lua_gc(self.State, what, data)
end

--// Memory statistics
function LuauVM.SetMemoryCategory(self: LuauVM, category: number)
    self.WASM.lua_setmemcat(self.State, category)
    return
end

function LuauVM.TotalBytes(self: LuauVM, category: number): number
    return buffer.readi32(self.Memory, self.WASM.lua_totalbytes(self.State, category))
end

--// Miscellaneous functions
function LuauVM.Error(self: LuauVM)
    self.WASM.lua_error(self.State)
    --// no return because will error both host and wasm
end

function LuauVM.Next(self: LuauVM, idx: number): number
    return self.WASM.lua_next(self.State, idx)
end

function LuauVM.RawIter(self: LuauVM, idx: number, iter: number): number
    return self.WASM.lua_rawiter(self.State, idx, iter)
end

function LuauVM.Concat(self: LuauVM, n: number)
    self.WASM.lua_concat(self.State, n)
    return
end

function LuauVM.EncodePointer(self: LuauVM, p: Pointer): Pointer
    return self.WASM.lua_encodepointer(self.State, p)
end

function LuauVM.Clock(self: LuauVM): number
    return self.WASM.lua_clock(self.State)
end

function LuauVM.SetUserdataTag(self: LuauVM, idx: number, tag: number)
    self.WASM.lua_setuserdatatag(self.State, idx, tag)
    return
end

function LuauVM.SetUserdataDestructor(self: LuauVM, tag: number, dtor: LuaDestructor | number)
    local dtIdx = if (typeof(dtor) == "number") then dtor else self.Helper.InjectFunction(dtor)
    self.WASM.lua_setuserdatadtor(self.State, tag, dtIdx)
    return
end

function LuauVM.GetUserdataDestructor(self: LuauVM, tag: number): LuaDestructor
    local dtIdx = self.WASM.lua_getuserdatadtor(self.State, tag)
    return self.WASM.__indirect_function_table[dtIdx] :: LuaDestructor
end

function LuauVM.SetUserdataMetatable(self: LuauVM, tag: number)
    self.WASM.lua_setuserdatametatable(self.State, tag)
    return
end

function LuauVM.GetUserdataMetatable(self: LuauVM, tag: number)
    self.WASM.lua_getuserdatametatable(self.State, tag)
    return
end

function LuauVM.SetLightUserdataName(self: LuauVM, tag: number, name: string)
    local namePtr = self.Helper.CreateString(name)
    self.WASM.lua_setlightuserdataname(self.State, tag, namePtr)
    self.WASM.free(namePtr)
    return
end

function LuauVM.GetLightUserdataName(self: LuauVM, tag: number): string
    local namePtr = self.WASM.lua_getlightuserdataname(self.State, tag)
    local len     = self.WASM.strlen(namePtr)
    return buffer.readstring(self.Memory, namePtr, len)
end

function LuauVM.CloneFunction(self: LuauVM, idx: number)
    self.WASM.lua_clonefunction(self.State, idx)
    return
end

function LuauVM.ClearTable(self: LuauVM, idx: number)
    self.WASM.lua_cleartable(self.State, idx)
    return
end

function LuauVM.CloneTable(self: LuauVM, idx: number)
    self.WASM.lua_clonetable(self.State, idx)
    return
end

function LuauVM.GetAllocFunction(self: LuauVM, ud: Pointer): LuaAlloc
    local idx = self.WASM.lua_getallocf(self.State, ud)
    assert(self.WASM.__indirect_function_table[idx], "BUG: getallocf - could not find host function form in indirect function table")
    return self.WASM.__indirect_function_table[idx] :: LuaAlloc
end

function LuauVM.Ref(self: LuauVM, idx: number): number
    return self.WASM.lua_ref(self.State, idx)
end

function LuauVM.Unref(self: LuauVM, ref: number)
    self.WASM.lua_unref(self.State, ref)
    return
end

--// Macros
function LuauVM.UpvalueIndex(self: LuauVM, i: number): number
    return (LuaStack.LUA_GLOBALSINDEX - i)
end

function LuauVM.IsPsuedo(self: LuauVM, i: number): boolean
    return (i <= LuaStack.LUA_REGISTRYINDEX)
end

function LuauVM.GetRef(self: LuauVM, ref: number): number
    return self:RawGetI(LuaStack.LUA_REGISTRYINDEX, ref)
end

function LuauVM.ToNumber(self: LuauVM, i: number): number
    local _, res = self:ToNumberX(i)
    return res
end

function LuauVM.ToInteger(self: LuauVM, i: number): number
    local _, res = self:ToIntegerX(i)
    return res
end

function LuauVM.ToUnsigned(self: LuauVM, i: number): number
    local _, res = self:ToUnsignedX(i)
    return res
end

function LuauVM.Pop(self: LuauVM, n: number)
    return self:SetTop(-n - 1)
end

function LuauVM.NewTable(self: LuauVM)
    return self:CreateTable(0, 0)
end

function LuauVM.NewUserdata(self: LuauVM, sz: number): number
    return self:NewUserdataTagged(sz, 0)
end

function LuauVM.StringLength(self: LuauVM, i: number): number
    return self:ObjLen(i)
end

function LuauVM.IsTypeFunction(self: LuauVM, n: number): boolean
    return (self:Type(n) == LuaTypes.LUA_TFUNCTION)
end

function LuauVM.IsTypeTable(self: LuauVM, n: number): boolean
    return (self:Type(n) == LuaTypes.LUA_TTABLE)
end

function LuauVM.IsTypeLightUserdata(self: LuauVM, n: number): boolean
    return (self:Type(n) == LuaTypes.LUA_TLIGHTUSERDATA)
end

function LuauVM.IsTypeNil(self: LuauVM, n: number): boolean
    return (self:Type(n) == LuaTypes.LUA_TNIL)
end

function LuauVM.IsTypeBoolean(self: LuauVM, n: number): boolean
    return (self:Type(n) == LuaTypes.LUA_TBOOLEAN)
end

function LuauVM.IsTypeInteger64(self: LuauVM, n: number): boolean
    return (self:Type(n) == LuaTypes.LUA_TINTEGER)
end

function LuauVM.IsTypeVector(self: LuauVM, n: number): boolean
    return (self:Type(n) == LuaTypes.LUA_TVECTOR)
end

function LuauVM.IsTypeThread(self: LuauVM, n: number): boolean
    return (self:Type(n) == LuaTypes.LUA_TTHREAD)
end

function LuauVM.IsTypeBuffer(self: LuauVM, n: number): boolean
    return (self:Type(n) == LuaTypes.LUA_TBUFFER)
end

function LuauVM.IsTypeNone(self: LuauVM, n: number): boolean
    return (self:Type(n) == LuaTypes.LUA_TNONE)
end

function LuauVM.IsTypeNoneOrNil(self: LuauVM, n: number): boolean
    return (self:Type(n) <= LuaTypes.LUA_TNIL)
end

function LuauVM.PushLiteral(self: LuauVM, s: string)
    local sPtr = self.Helper.CreateString(s)
    self:PushLString(sPtr, #s)
    self.WASM.free(sPtr)
    return
end

function LuauVM.PushCFunction(self: LuauVM, fn: LuaCFunction, debugName: string)
    return self:PushCClosureK(fn, debugName, 0, 0)
end

function LuauVM.PushCClosure(self: LuauVM, fn: LuaCFunction, debugName: string, nUp: number)
    return self:PushCClosureK(fn, debugName, nUp, 0)
end

function LuauVM.PushLightUserdata(self: LuauVM, p: Pointer)
    return self:PushLightUserdataTagged(p, 0)
end

function LuauVM.RawGetP(self: LuauVM, idx: number, p: Pointer)
    return self:RawGetPtagged(idx, p, 0)
end

function LuauVM.RawSetP(self: LuauVM, idx: number, p: Pointer)
    return self:RawSetPtagged(idx, p, 0)
end

function LuauVM.SetGlobal(self: LuauVM, s: string)
    return self:SetField(LuaStack.LUA_GLOBALSINDEX, s)
end

function LuauVM.GetGlobal(self: LuauVM, s: string)
    return self:GetField(LuaStack.LUA_GLOBALSINDEX, s)
end

function LuauVM.ToString(self: LuauVM, i: number)
    return self:ToLString(i)
end

--[[
function LuauVM.PushFString(self: LuauVM)    
end
--]]

--// Library functions
function LuauVM.LRegister(self: LuauVM, libName: string, regName: string, regFunc: LuaCFunction | number)
    local libNamePtr = self.Helper.CreateString(libName)
    local regNamePtr = self.Helper.CreateString(regName)
    local regFuncIdx = if (typeof(regFunc) == "number") then regFunc else self.Helper.InjectFunction(regFunc)

    --// reference: struct luaL_Reg (lualib.h)
    local regPtr = self.WASM.malloc(8)
    buffer.writei32(self.Memory, regPtr,     regNamePtr) --// const char* name
    buffer.writei32(self.Memory, regPtr + 4, regFuncIdx) --// lua_CFunction func

    self.WASM.luaL_register(self.State, libNamePtr, regPtr)

    self.WASM.free(regPtr)
    self.WASM.free(libNamePtr)
    self.WASM.free(regNamePtr)
    return
end

function LuauVM.LGetMetaField(self: LuauVM, obj: number, e: string): number
    local ePtr   = self.Helper.CreateString(e)
    local result = self.WASM.luaL_getmetafield(self.State, obj, ePtr)
    self.WASM.free(ePtr)
    return result
end

function LuauVM.LCallMeta(self: LuauVM, obj: number, e: string): boolean
    local ePtr   = self.Helper.CreateString(e)
    local result = self.WASM.luaL_callmeta(self.State, obj, ePtr)
    self.WASM.free(ePtr)
    return (result == 1)
end

function LuauVM.LTypeErrorL(self: LuauVM, nArg: number, tName: string)
    local tNamePtr = self.Helper.CreateString(tName)
    self.WASM.luaL_typeerrorL(self.State, nArg, tNamePtr)
    --// no return because will error both host and wasm
end

function LuauVM.LArgErrorL(self: LuauVM, nArg: number, extraMsg: string)
    local extraMsgPtr = self.Helper.CreateString(extraMsg)
    self.WASM.luaL_argerrorL(self.State, nArg, extraMsgPtr)
    --// no return because will error both host and wasm
end

function LuauVM.LCheckLString(self: LuauVM, numArg: number): string
    local lenPtr = self.WASM.malloc(4)
    local result = self.WASM.luaL_checklstring(self.State, numArg, lenPtr)
    local length = buffer.readi32(self.Memory, lenPtr)
    self.WASM.free(lenPtr)
    return buffer.readstring(self.Memory, result, length)
end

function LuauVM.LOptionalLString(self: LuauVM, numArg: number, def: string?): string
    local defPtr = if (def) then self.Helper.CreateString(def) else 0
    local lenPtr = self.WASM.malloc(4)
    local result = self.WASM.luaL_optlstring(self.State, numArg, defPtr, lenPtr)
    local length = buffer.readi32(self.Memory, lenPtr)
    self.WASM.free(lenPtr)
    if (def) then self.WASM.free(defPtr) end
    return buffer.readstring(self.Memory, result, length)
end

function LuauVM.LCheckNumber(self: LuauVM, numArg: number): number
    return self.WASM.luaL_checknumber(self.State, numArg)
end

function LuauVM.LOptionalNumber(self: LuauVM, nArg: number, def: number?): number
    return self.WASM.luaL_optnumber(self.State, nArg, def or 0)
end

function LuauVM.LCheckBoolean(self: LuauVM, nArg: number): boolean
    return (self.WASM.luaL_checkboolean(self.State, nArg) == 1)
end

function LuauVM.LOptionalBoolean(self: LuauVM, nArg: number, def: boolean): boolean
    return (self.WASM.luaL_optboolean(self.State, nArg, if (def) then 1 else 0) == 1)
end

function LuauVM.LCheckInteger(self: LuauVM, numArg: number): number
    return self.WASM.luaL_checkinteger(self.State, numArg)
end

function LuauVM.LCheckInteger64(self: LuauVM, numArg: number): number
    local result, _ = SpiderRuntime.from_bits_i64(self.WASM.luaL_checkinteger64(self.State, numArg))
    return result
end

function LuauVM.LOptionalInteger(self: LuauVM, nArg: number, def: number): number
    return self.WASM.luaL_optinteger(self.State, nArg, def)
end

function LuauVM.LOptionalInteger64(self: LuauVM, nArg: number, def: number): number
    local result, _ = SpiderRuntime.from_bits_i64(self.WASM.luaL_checkinteger64(self.State, nArg, SpiderRuntime.into_bits_i64(def, 0)))
    return result
end

function LuauVM.LCheckUnsigned(self: LuauVM, numArg: number): number
    return self.WASM.luaL_checkunsigned(self.State, numArg)
end

function LuauVM.LOptionalUnsigned(self: LuauVM, numArg: number, def: number): number
    return self.WASM.luaL_optunsigned(self.State, numArg, def)
end

function LuauVM.LCheckVector(self: LuauVM, nArg: number): (number, number, number)
    return table.unpack(self.Helper.ReadVectorFloatArray(self.WASM.luaL_checkvector(self.State, nArg)))
end

function LuauVM.LOptionalVector(self: LuauVM, nArg: number, defX: number, defY: number, defZ: number): (number, number, number)
    local defPtr = self.Helper.CreateVectorFloatArray({ defX, defY, defZ })
    local result = self.Helper.ReadVectorFloatArray(self.WASM.luaL_optvector(self.State, nArg, defPtr))
    self.WASM.free(defPtr)
    return table.unpack(result)
end

function LuauVM.LCheckStack(self: LuauVM, sz: number, msg: string)
    local msgPtr = self.Helper.CreateString(msg)
    self.WASM.luaL_checkstack(self.State, sz, msgPtr)
    self.WASM.free(msgPtr)
    return
end

function LuauVM.LCheckType(self: LuauVM, nArg: number, t: number)
    self.WASM.luaL_checktype(self.State, nArg, t)
    return
end

function LuauVM.LCheckAny(self: LuauVM, nArg: number)
    self.WASM.luaL_checkany(self.State, nArg)
    return
end

function LuauVM.LNewMetatable(self: LuauVM, tName: string): boolean
    local tNamePtr = self.Helper.CreateString(tName)
    local result   = self.WASM.luaL_newmetatable(self.State, tNamePtr)
    self.WASM.free(tNamePtr)
    return (result == 1)
end

function LuauVM.LCheckUserdata(self: LuauVM, ud: Pointer, tName: string): Pointer
    local tNamePtr = self.Helper.CreateString(tName)
    local result   = self.WASM.luaL_checkudata(self.State, ud, tNamePtr)
    self.WASM.free(tNamePtr)
    return result
end

function LuauVM.LCheckBuffer(self: LuauVM, nArg: number): (Pointer, number)
    local lenPtr = self.WASM.malloc(4)
    local result = self.WASM.luaL_checkbuffer(self.State, nArg, lenPtr)
    local length = buffer.readi32(self.Memory, lenPtr)
    self.WASM.free(lenPtr)
    return result, length
end

function LuauVM.LWhere(self: LuauVM, lvl: number)
    self.WASM.luaL_where(self.State, lvl)
    return
end

function LuauVM.LErrorL(self: LuauVM, fmt: string, ...)
    local fmtPtr = self.Helper.CreateString(fmt)
    self.WASM.luaL_errorL(self.State, fmtPtr, ...)
    --// no return because will error both host and wasm
end

function LuauVM.LCheckOption(self: LuauVM, nArg: number, def: string, lst: { string }): number
    local defPtr = self.Helper.CreateString(def)
    local lstPtr = self.Helper.CreateStringArray(lst)
    local result = self.WASM.luaL_checkoption(self.State, nArg, defPtr, lstPtr)
    self.WASM.free(defPtr)
    self.Helper.FreeStringArray(lstPtr)
    return result
end

function LuauVM.LToLString(self: LuauVM, idx: number): string
    local lenPtr = self.WASM.malloc(4)
    local result = self.WASM.luaL_tolstring(self.State, idx, lenPtr)
    local length = buffer.readi32(self.Memory, lenPtr)
    self.WASM.free(lenPtr)
    return buffer.readstring(self.Memory, result, length)
end

function LuauVM.LFindTable(self: LuauVM, idx: number, fName: string, szHint: number): string
    local fNamePtr = self.Helper.CreateString(fName)
    local result   = self.WASM.luaL_findtable(self.State, idx, fNamePtr, szHint)
    local length   = self.WASM.strlen(result)
    self.WASM.free(fNamePtr)
    return buffer.readstring(self.Memory, result, length)
end

function LuauVM.LTypeName(self: LuauVM, idx: number): string
    local result = self.WASM.luaL_typename(self.State, idx)
    local length = self.WASM.strlen(result)
    return buffer.readstring(self.Memory, result, length)
end

function LuauVM.LCallYieldable(self: LuauVM, nArgs: number, nResults: number): number
    return self.WASM.luaL_callyieldable(self.State, nArgs, nResults)
end

function LuauVM.LTraceback(self: LuauVM, L1: LuauVM, msg: string, level: number)
    local msgPtr = self.Helper.CreateString(msg)
    self.WASM.luaL_traceback(self.State, L1.State, msgPtr, level)
    self.WASM.free(msgPtr)
    return
end

function LuauVM.LBufferInit(self: LuauVM, B: Pointer)
    self.WASM.luaL_buffinit(self.State, B)
    return
end

function LuauVM.LBufferInitSize(self: LuauVM, B: Pointer, size: number): Pointer
    return self.WASM.luaL_buffinitsize(self.State, B, size)
end

function LuauVM.LBufferPrepareSize(self: LuauVM, B: Pointer, size: number): Pointer
    return self.WASM.luaL_preparebuffsize(B, size)
end

function LuauVM.LBufferAddLString(self: LuauVM, B: Pointer, s: string)
    local sPtr = self.Helper.CreateString(s)
    self.WASM.luaL_addlstring(B, sPtr, #s)
    self.WASM.free(sPtr)
    return
end

function LuauVM.LBufferAddValue(self: LuauVM, B: Pointer)
    self.WASM.luaL_addvalue(B)
    return
end

function LuauVM.LBufferAddValueAny(self: LuauVM, B: Pointer, idx: number)
    self.WASM.luaL_addvalueany(B, idx)
    return
end

function LuauVM.LBufferPushResult(self: LuauVM, B: Pointer)
    self.WASM.luaL_pushresult(B)
    return
end

function LuauVM.LBufferPushResultSize(self: LuauVM, B: Pointer, size: number)
    self.WASM.luaL_pushresultsize(B, size)
    return
end

function LuauVM.OpenBase(self: LuauVM)
    self.WASM.luaopen_base(self.State)
    return
end

function LuauVM.OpenCoroutine(self: LuauVM)
    self.WASM.luaopen_coroutine(self.State)
    return
end

function LuauVM.OpenTable(self: LuauVM)
    self.WASM.luaopen_table(self.State)
    return
end

function LuauVM.OpenOs(self: LuauVM)
    self.WASM.luaopen_os(self.State)
    return
end

function LuauVM.OpenString(self: LuauVM)
    self.WASM.luaopen_string(self.State)
    return
end

function LuauVM.OpenBit32(self: LuauVM)
    self.WASM.luaopen_bit32(self.State)
    return
end

function LuauVM.OpenBuffer(self: LuauVM)
    self.WASM.luaopen_buffer(self.State)
    return
end

function LuauVM.OpenUtf8(self: LuauVM)
    self.WASM.luaopen_utf8(self.State)
    return
end

function LuauVM.OpenMath(self: LuauVM)
    self.WASM.luaopen_math(self.State)
    return
end

function LuauVM.OpenDebug(self: LuauVM)
    self.WASM.luaopen_debug(self.State)
    return
end

function LuauVM.OpenVector(self: LuauVM)
    self.WASM.luaopen_vector(self.State)
    return
end

function LuauVM.OpenInteger(self: LuauVM)
    self.WASM.luaopen_integer(self.State)
    return
end

function LuauVM.LOpenLibs(self: LuauVM)
    self.WASM.luaL_openlibs(self.State)
    return
end

function LuauVM.LSandbox(self: LuauVM)
    self.WASM.luaL_sandbox(self.State)
    return
end

function LuauVM.LSandboxThread(self: LuauVM)
    self.WASM.luaL_sandboxthread(self.State)
    return
end

--// Library macros
function LuauVM.LGetMetatable(self: LuauVM, n: string): number
    return self:GetField(LuaStack.LUA_REGISTRYINDEX, n)
end

return {
    new = function(): LuauVM
        local importOk: boolean, init: (any) -> (WasmModule.WasmModule) = pcall(require, "./VMModule")
        assert(importOk, `failed to import webassembly module: {init}`)

        --// import table proxy
        --// since we can't access memory before init, we have to
        --// proxy them (init has assertions for checking missing imports)
        local importTable: {[string]: (...any) -> (...any)}
        local proxyTable  = setmetatable({}, { __index = function(_, n: string) return function(...) assert(importTable[n], `BUG: import '{n}' does not exist`); return importTable[n](...) end end })
        local module = init({ env = proxyTable, wasi_snapshot_preview1 = proxyTable })

        --// initialize our stuff
        local helper = HelperInit(module)
        importTable  = ImportTableInit(module, helper)

        --// invoke functions
        importTable["invoke_vii"] = helper.CreateInvoke()

        return setmetatable({
            WASM          = module,
            Memory        = module.memory[1],
            ImportTable   = importTable,
            Helper        = helper,
            State         = module.luaL_newstate(),
            ChildStateVMs = {},
        }, LuauVM)
    end,

    fromExistingModule = function(module: WasmModule.WasmModule, helper: typeof(HelperInit(nil :: any)), importTable: { [string]: (...any) -> (...any) }): LuauVM
        return setmetatable({
            WASM          = module,
            Memory        = module.memory[1],
            ImportTable   = importTable,
            Helper        = helper,
            State         = module.luaL_newstate(),
            ChildStateVMs = {},
        }, LuauVM)
    end,

    fromExistingMainState = function(module: WasmModule.WasmModule, helper: typeof(HelperInit(nil :: any)), importTable: { [string]: (...any) -> (...any) }, statePtr: number): LuauVM
        return setmetatable({
            WASM          = module,
            Memory        = module.memory[1],
            ImportTable   = importTable,
            Helper        = helper,
            State         = statePtr,
            ChildStateVMs = {},
        }, LuauVM)
    end,

    fromExistingChildState = function(module: WasmModule.WasmModule, helper: typeof(HelperInit(nil :: any)), importTable: { [string]: (...any) -> (...any) }, statePtr: number, parent: LuauVM): LuauVM
        local vm = setmetatable({
            WASM          = module,
            Memory        = module.memory[1],
            ImportTable   = importTable,
            Helper        = helper,
            State         = statePtr,
            Parent        = parent
        }, LuauVM)
        table.insert(parent.ChildStateVMs :: { LuauVM }, vm)
        return vm
    end,

    --// enum exports
    LuaStatus          = LuaStatus,
    LuaCoStatus        = LuaCoStatus,
    LuaGCOp            = LuaGCOp,
    LuaConfigConstants = LuaConfigConstants,
    LuaStack           = LuaStack,
    LuaLibraryName     = LuaLibraryName,
    LuaTypes           = LuaTypes,
    LuaReferenceMacro  = LuaReferenceMacro,
}