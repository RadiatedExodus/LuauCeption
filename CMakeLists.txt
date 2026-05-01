cmake_minimum_required(VERSION 3.10)
project(Luau.LuauCeption LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 17)

# luau configuration
option(LUAU_BUILD_CLI "Build CLI" OFF)
option(LUAU_BUILD_TESTS "Build tests" OFF)
option(LUAU_BUILD_WEB "Build Web module" OFF)
option(LUAU_WERROR "Warnings as errors" OFF)
option(LUAU_STATIC_CRT "Link with the static CRT (/MT)" OFF)
option(LUAU_EXTERN_C "Use extern C for all APIs" OFF) # we need to handle it ourselves
option(LUAU_BUILD_SHARED "Build as a shared library" OFF)
add_subdirectory(extern/luau)

# luau processor configuration
set(EMSCRIPTEN_EXPORT "extern \"C\" __attribute__((used))")
target_compile_definitions(Luau.Compiler PUBLIC LUA_USE_LONGJMP=1 LUA_VECTOR_SIZE=3 LUACODE_API=${EMSCRIPTEN_EXPORT} LUACODEGEN_API=${EMSCRIPTEN_EXPORT})
target_compile_definitions(Luau.VM PUBLIC LUA_USE_LONGJMP=1 LUA_VECTOR_SIZE=3 LUA_API=${EMSCRIPTEN_EXPORT})

# compiler and linker flags
set(LUAUCEPTION_CC_OPTS)
set(LUAUCEPTION_LN_OPTS)
list(APPEND LUAUCEPTION_CC_OPTS -Oz -flto)
list(APPEND LUAUCEPTION_LN_OPTS -Oz -flto -sINITIAL_MEMORY=67108864 -sEVAL_CTORS=2 -sEXPORTED_FUNCTIONS=['_strlen','_malloc','_free'] -sBINARYEN_EXTRA_PASSES='vacuum,simplify-locals,simplify-globals,optimize-instructions,optimize-stack-ir,fast-math,strip-dwarf,code-folding,duplicate-function-elimination,duplicate-import-elimination,rse,type-ssa')

# compiler
add_executable(Luau.LuauCeption.Compiler)
target_sources(Luau.LuauCeption.Compiler PRIVATE src/glue/entrypoint_compiler.cpp src/glue/flags.cpp src/glue/flags.h)
target_link_libraries(Luau.LuauCeption.Compiler PUBLIC Luau.Compiler)
target_compile_features(Luau.LuauCeption.Compiler PUBLIC cxx_std_17)
target_compile_definitions(Luau.LuauCeption.Compiler PUBLIC LUAUCEPTION_API=${EMSCRIPTEN_EXPORT})
target_compile_options(Luau.LuauCeption.Compiler PUBLIC ${LUAUCEPTION_CC_OPTS})
target_link_options(Luau.LuauCeption.Compiler PUBLIC ${LUAUCEPTION_LN_OPTS})

# vm
add_executable(Luau.LuauCeption.VM)
target_sources(Luau.LuauCeption.VM PRIVATE src/glue/entrypoint_vm.cpp src/glue/flags.cpp src/glue/flags.h)
target_link_libraries(Luau.LuauCeption.VM PUBLIC Luau.Compiler Luau.VM)
target_compile_features(Luau.LuauCeption.VM PUBLIC cxx_std_17)
target_compile_definitions(Luau.LuauCeption.VM PUBLIC LUAUCEPTION_API=${EMSCRIPTEN_EXPORT})
target_compile_options(Luau.LuauCeption.VM PUBLIC ${LUAUCEPTION_CC_OPTS})
target_link_options(Luau.LuauCeption.VM PUBLIC ${LUAUCEPTION_LN_OPTS})