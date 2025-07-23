#!/bin/bash
mkdir build
cd build
emcmake cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build . --target Luau.LuauCeption.Compiler Luau.LuauCeption.VM Luau.LuauCeption.Full --config RelWithDebInfo -j 2
