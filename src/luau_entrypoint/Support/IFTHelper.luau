--!strict
local WasmModuleType = require("./WasmModuleType")

local IFTHelper = {}
IFTHelper.__index = IFTHelper

type AnyFunction = (...any) -> (...any)
export type IFTHelper = typeof(setmetatable({} :: {
    Module:            WasmModuleType.WasmModule,
    IFT:               { [number]: AnyFunction },
    WrappedFunctions:  typeof(setmetatable({} :: { [AnyFunction]: AnyFunction }, { __mode = "kv" })), --// [wrapped]: original
    InsertedFunctions: typeof(setmetatable({} :: { AnyFunction }, { __mode = "v" })), --// [ift idx]: function
}, IFTHelper))

function IFTHelper.InsertFunction(self: IFTHelper, f: AnyFunction): number
    local idx = #self.IFT + 1
    self.IFT[idx] = f
    self.InsertedFunctions[idx] = f
    return idx
end

function IFTHelper.InsertWrappedFunction(self: IFTHelper, f: AnyFunction, original: AnyFunction): number
    self.WrappedFunctions[f] = original
    return self:InsertFunction(f)
end

function IFTHelper.GetOrInsertFunction(self: IFTHelper, f: AnyFunction | number): number
    if (typeof(f) == "number") then return f end
    local found = self:GetIndexFromFunction(f)
    return if (found) then found else self:InsertFunction(f)
end

function IFTHelper.GetOrInsertWrappedFunction(self: IFTHelper, f: AnyFunction, original: AnyFunction | number): number
    if (typeof(original) == "number") then return original end
    local found = self:GetIndexFromFunction(original)
    return if (found) then found else self:InsertWrappedFunction(f, original)
end

function IFTHelper.GetIndexFromFunction(self: IFTHelper, f: AnyFunction, ignoreWrap: boolean?): number?
    if (ignoreWrap) then
        for idx, fn in pairs(self.InsertedFunctions) do
            if (fn == f) then
                return idx
            end
        end
    end

    --// if this is was wrapped and were given the original,
    --// find the wrapped function
    for wrapped, original in pairs(self.WrappedFunctions) do
        if (original == f) then
            f = wrapped
        end
    end

    --// find it
    for idx, fn in pairs(self.InsertedFunctions) do
        if (fn == f) then
            return idx
        end
    end

    return nil
end

function IFTHelper.GetFunctionFromIndex(self: IFTHelper, idx: number, ignoreWrap: boolean?): AnyFunction?
    local found = self.InsertedFunctions[idx] :: AnyFunction
    if (not ignoreWrap) then
        for wrapped, original in pairs(self.WrappedFunctions) do
            if (wrapped == found) then
                found = original
                break
            end
        end
    end
    return found
end

return {
    new = function(module: WasmModuleType.WasmModule): IFTHelper
        return setmetatable({
            Module            = module,
            IFT               = module.__indirect_function_table :: any,
            WrappedFunctions  = setmetatable({}, { __mode = "kv" }),
            InsertedFunctions = setmetatable({}, { __mode = "v" }),
        }, IFTHelper)
    end
}