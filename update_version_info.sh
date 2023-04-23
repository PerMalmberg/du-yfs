#!/bin/bash
set -e -o pipefail
# Get tag, or fallback to short commit hash
git_info=$(git describe --exact-match --tags 2> /dev/null || git rev-parse --short HEAD)
date_info=$(date +'%Y%m%d %R')

# Files without .lua extension
files=("./src/version" "./src/screen/layout")
for f in ${files[@]}
do
    cp "${f}.lua" "${f}_out.lua"
    sed -i "s/GITINFO/${git_info}/g" "${f}_out.lua"
    sed -i "s/DATEINFO/${date_info}/g" "${f}_out.lua"
done