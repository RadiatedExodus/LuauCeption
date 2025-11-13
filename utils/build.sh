#!/bin/bash
BUILDER_SCRIPT="$(realpath "./src/builder")"
MAIN_DIR="$(realpath "./")" # assuming that the script is ran on LuauCeption/ directory

if ! which wasm2luau > /dev/null 2>&1; then
    WASM2LUAU_EXEC="$(realpath "./utils/wasm2luau")"

    if [ -f "$WASM2LUAU_EXEC" ]; then
        export PATH="$PATH:$(dirname "$WASM2LUAU_EXEC")"
    fi
fi

mkdir build
cd build
emcmake cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build . --target Luau.LuauCeption.Compiler Luau.LuauCeption.VM Luau.LuauCeption.Full --config RelWithDebInfo -j 2

cd "$MAIN_DIR" 
lune run "$BUILDER_SCRIPT" -f BUILD_ONEFILE
