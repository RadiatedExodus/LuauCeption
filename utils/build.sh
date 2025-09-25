#!/bin/bash
BUILDER_SCRIPT="$(realpath "./utils/builder")"
MAIN_DIR="$(realpath "./")" # assuming that the script is ran on LuauCeption/ directory

mkdir build
cd build
emcmake cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build . --target Luau.LuauCeption.Compiler Luau.LuauCeption.VM Luau.LuauCeption.Full --config RelWithDebInfo -j 2

cd "$MAIN_DIR" 
lune run "$BUILDER_SCRIPT" -f BUILD_ONEFILE
