export type LuauCompileOptions = {
    OptimizationLevel: number,
    DebugLevel: number,
    TypeInfoLevel: number,
    CoverageLevel: number,

    VectorLibName: string?,
    VectorLibConstructor: string?,
    VectorType: string?,

    MutableGlobals: {string}?,
    DisabledBuiltins: {string}?,
}

return function(rt: any, memory_at_0: any, cfns: any, INDIRECT_FUNCTIONS: any, utils: typeof(require("../Common/utils")()))
    local module = {}

    local function construct_luau_CompileOptions(options: LuauCompileOptions): (number, () -> ())
        local compileOptions_ptr = cfns.malloc(52)
        local __freed = false

        local vectorLibName_ptr = if options.VectorLibName then utils.cstr(options.VectorLibName) else 0
        local vectorLibConstructor_ptr = if options.VectorLibConstructor then utils.cstr(options.VectorLibConstructor) else 0
        local vectorType_ptr = if options.VectorType then utils.cstr(options.VectorType) else 0

        local mutableGlobals_ptr = if options.MutableGlobals then utils.cstr_array(options.MutableGlobals) else 0
        local disabledBuiltins_ptr = if options.DisabledBuiltins then utils.cstr_array(options.DisabledBuiltins) else 0

        -- struct lua_CompileOptions (see luau/Compiler/include/luacode.h)
        rt.store.i32(memory_at_0, compileOptions_ptr + 0, options.OptimizationLevel) -- int optimizationLevel
        rt.store.i32(memory_at_0, compileOptions_ptr + 4, options.DebugLevel) -- int debugLevel
        rt.store.i32(memory_at_0, compileOptions_ptr + 8, options.TypeInfoLevel) -- int typeInfoLevel
        rt.store.i32(memory_at_0, compileOptions_ptr + 12, options.CoverageLevel) -- int coverageLevel
        rt.store.i32(memory_at_0, compileOptions_ptr + 16, vectorLibName_ptr) -- const char* vectorLib
        rt.store.i32(memory_at_0, compileOptions_ptr + 20, vectorLibConstructor_ptr) -- const char* vectorCtor
        rt.store.i32(memory_at_0, compileOptions_ptr + 24, vectorType_ptr) -- const char* vectorType
        rt.store.i32(memory_at_0, compileOptions_ptr + 28, mutableGlobals_ptr) -- const char* const* mutableGlobals
        rt.store.i32(memory_at_0, compileOptions_ptr + 32, 0) -- const char* const* userdataTypes
        rt.store.i32(memory_at_0, compileOptions_ptr + 36, 0) -- const char* const* librariesWithKnownMembers
        rt.store.i32(memory_at_0, compileOptions_ptr + 40, 0) -- lua_LibraryMemberTypeCallback libraryMemberTypeCb
        rt.store.i32(memory_at_0, compileOptions_ptr + 44, 0) -- lua_LibraryMemberConstantCallback libraryMemberConstantCb
        rt.store.i32(memory_at_0, compileOptions_ptr + 48, disabledBuiltins_ptr) -- const char* const* disabledBuiltins

        return compileOptions_ptr, function()
            if __freed then
                error("Already freed!")
            end
            __freed = true

            cfns.free(compileOptions_ptr)
            if vectorLibName_ptr ~= 0 then cfns.free(vectorLibName_ptr) end
            if vectorLibConstructor_ptr ~= 0 then cfns.free(vectorLibConstructor_ptr) end
            if vectorType_ptr ~= 0 then cfns.free(vectorType_ptr) end
            if disabledBuiltins_ptr ~= 0 then cfns.free(disabledBuiltins_ptr) end
            if mutableGlobals_ptr ~= 0 then cfns.free(mutableGlobals_ptr) end
        end
    end

    function module.luau_compile(source: string, options: LuauCompileOptions): (string, number)
        -- load source and luau_CompileOptions
        local luau_CompileOptions_ptr, compileOptions_free = construct_luau_CompileOptions(options)
        local source_ptr = utils.cstr(source)

        -- allocate for getting bytecode size
        local bytecodeSize_ptr = cfns.malloc(8)

        -- compile
        local bytecode_ptr = cfns.luau_compile(source_ptr, #source, luau_CompileOptions_ptr, bytecodeSize_ptr)
        local bytecodeSize = rt.load.i32(memory_at_0, bytecodeSize_ptr)
        local bytecode = rt.load.string(memory_at_0, bytecode_ptr, bytecodeSize)

        -- Cleanup
        compileOptions_free()
        cfns.free(source_ptr)
        cfns.free(bytecode_ptr)
        cfns.free(bytecodeSize_ptr)
        return bytecode, bytecodeSize
    end
    return module
end
