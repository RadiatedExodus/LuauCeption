--!strict
local ExceptionInfo = {}
ExceptionInfo.__index = ExceptionInfo

export type ExceptionInfo = typeof(setmetatable({} :: {
    Memory:  buffer,
    Pointer: number,
}, ExceptionInfo))

function ExceptionInfo.SetType(self: ExceptionInfo, type: number)
    buffer.writeu32(self.Memory, bit32.rshift(self.Pointer + 4, 2), type)
    return
end

function ExceptionInfo.GetType(self: ExceptionInfo): number
    return buffer.readu32(self.Memory, bit32.rshift(self.Pointer + 4, 2))
end

function ExceptionInfo.SetDestructor(self: ExceptionInfo, destructor: number)
    buffer.writeu32(self.Memory, bit32.rshift(self.Pointer + 8, 2), destructor)
    return
end

function ExceptionInfo.GetDestructor(self: ExceptionInfo): number
    return buffer.readu32(self.Memory, bit32.rshift(self.Pointer + 8, 2))
end

function ExceptionInfo.SetCaught(self: ExceptionInfo, caught: boolean)
    buffer.writeu8(self.Memory, self.Pointer + 12, if (caught) then 1 else 0)
    return
end

function ExceptionInfo.GetCaught(self: ExceptionInfo): boolean
    return buffer.readu8(self.Memory, self.Pointer + 12) ~= 0
end

function ExceptionInfo.SetRethrown(self: ExceptionInfo, rethrown: boolean)
    buffer.writeu8(self.Memory, self.Pointer + 13, if (rethrown) then 1 else 0)
    return
end

function ExceptionInfo.GetRethrown(self: ExceptionInfo): boolean
    return buffer.readu8(self.Memory, self.Pointer + 13) ~= 0
end

function ExceptionInfo.Initialize(self: ExceptionInfo, type: number, destructor: number)
    self:SetAdjustedPtr(0)
    self:SetType(type)
    self:SetDestructor(destructor)
    return
end

function ExceptionInfo.SetAdjustedPtr(self: ExceptionInfo, adjustedPtr: number)
    buffer.writeu32(self.Memory, bit32.rshift(self.Pointer + 16, 2), adjustedPtr)
    return
end

function ExceptionInfo.GetAdjustedPtr(self: ExceptionInfo): number
    return buffer.readu32(self.Memory, bit32.rshift(self.Pointer + 16, 2))
end

function ExceptionInfo.GetUndecoratedName(self: ExceptionInfo, strlen: (number) -> (number)): string
    local namePtr = buffer.readi32(self.Memory, self:GetType() + 4)
    return buffer.readstring(self.Memory, namePtr, strlen(namePtr))
end

return {
    new = function(memory: buffer, ptr: number): ExceptionInfo
        return setmetatable({
            Memory  = memory,
            Pointer = ptr - 24,
        }, ExceptionInfo)
    end
}