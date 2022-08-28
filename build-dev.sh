#!/bin/bash
export LUA_PATH=$(pwd)/external/du-libs/src/?.lua
echo $LUA_PATH
du-lua build --copy=development/main
