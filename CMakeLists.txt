cmake_minimum_required(VERSION 3.19)
project(Luau.LuauCeption LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 17)

# Import Luau
option(LUAU_BUILD_CLI "Build CLI" OFF)
option(LUAU_BUILD_TESTS "Build tests" OFF)
option(LUAU_BUILD_WEB "Build Web module" OFF)
option(LUAU_WERROR "Warnings as errors" OFF)
option(LUAU_STATIC_CRT "Link with the static CRT (/MT)" OFF)
option(LUAU_EXTERN_C "Use extern C for all APIs" ON)
add_subdirectory(luau)

# Compiler variant compile & link options
set(COMPILER_CC_OPTS)
list(APPEND COMPILER_CC_OPTS -Oz -flto)
set(COMPILER_LN_OPTS)
list(APPEND COMPILER_LN_OPTS -Oz -flto -sEVAL_CTORS=2 -sEXPORTED_FUNCTIONS=['_strlen','_malloc','_free'] -sBINARYEN_EXTRA_PASSES='vacuum,simplify-locals,simplify-globals,optimize-instructions,optimize-stack-ir,fast-math,strip-dwarf,code-folding,duplicate-function-elimination,duplicate-import-elimination,rse,type-ssa')

# VM variant compile & link options
set(VM_CC_OPTS)
list(APPEND VM_CC_OPTS -Oz -flto)
set(VM_LN_OPTS)
list(APPEND VM_LN_OPTS -Oz -flto -sEVAL_CTORS=2 -sEXPORTED_FUNCTIONS=['_strlen','_malloc','_free'] -sBINARYEN_EXTRA_PASSES='vacuum,simplify-locals,simplify-globals,optimize-instructions,optimize-stack-ir,fast-math,strip-dwarf,code-folding,duplicate-function-elimination,duplicate-import-elimination,rse,type-ssa')

# Full variant compile & link options
set(FULL_CC_OPTS)
list(APPEND FULL_CC_OPTS -Oz -flto)
set(FULL_LN_OPTS)
list(APPEND FULL_LN_OPTS -Oz -flto -sEVAL_CTORS=2 -sEXPORTED_FUNCTIONS=['_strlen','_malloc','_free'] -sBINARYEN_EXTRA_PASSES='vacuum,simplify-locals,simplify-globals,optimize-instructions,optimize-stack-ir,fast-math,strip-dwarf,code-folding,duplicate-function-elimination,duplicate-import-elimination,rse,type-ssa')

# Compiler variant
add_executable(Luau.LuauCeption.Compiler)
target_sources(Luau.LuauCeption.Compiler PRIVATE src/Compiler.cpp src/LuauCeptionFlags.cpp src/LuauCeptionFlags.h)
target_link_libraries(Luau.LuauCeption.Compiler PUBLIC Luau.Compiler)

# VM variant
add_executable(Luau.LuauCeption.VM)
target_sources(Luau.LuauCeption.VM PRIVATE src/VM.cpp src/LuauCeptionFlags.cpp src/LuauCeptionFlags.h)
target_link_libraries(Luau.LuauCeption.VM PUBLIC Luau.VM)

# Full variant
add_executable(Luau.LuauCeption.Full)
target_sources(Luau.LuauCeption.Full PRIVATE src/Full.cpp src/LuauCeptionFlags.cpp src/LuauCeptionFlags.h)
target_link_libraries(Luau.LuauCeption.Full PUBLIC Luau.Compiler Luau.VM)

# Compiler variant configuration
target_compile_features(Luau.LuauCeption.Compiler PUBLIC cxx_std_17)
target_compile_options(Luau.LuauCeption.Compiler PUBLIC ${COMPILER_CC_OPTS})
target_link_options(Luau.LuauCeption.Compiler PUBLIC ${COMPILER_LN_OPTS})

# VM variant configuration
target_compile_features(Luau.LuauCeption.VM PUBLIC cxx_std_17)
target_compile_options(Luau.LuauCeption.VM PUBLIC ${VM_CC_OPTS})
target_link_options(Luau.LuauCeption.VM PUBLIC ${VM_LN_OPTS})

# Full variant configuration
target_compile_features(Luau.LuauCeption.Full PUBLIC cxx_std_17)
target_compile_options(Luau.LuauCeption.Full PUBLIC ${FULL_CC_OPTS})
target_link_options(Luau.LuauCeption.Full PUBLIC ${FULL_LN_OPTS})

# Definition to make Lua C APIs dynamically exported | __attribute__((used)) = EMSCRIPTEN_KEEPALIVE
set(EXPORTED_EXTERN "extern \"C\" __attribute__((used))")
target_compile_definitions(Luau.Compiler PUBLIC LUACODE_API=${EXPORTED_EXTERN})
target_compile_definitions(Luau.VM PUBLIC LUA_USE_LONGJMP=1 LUA_API=${EXPORTED_EXTERN})
