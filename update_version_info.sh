#!/bin/bash
set -e -o pipefail
# Get tag, or fallback to short commit hash
git_info=$(git describe --exact-match --tags 2> /dev/null || git rev-parse --short HEAD)
date_info=$(date +'%Y%m%d %R')

cp ./src/version.lua ./src/version_out.lua

files=("./src/screen/layout_min.json" "./src/screen/offline_min.json" "./src/version_out.lua")
for f in ${files[@]}
do
    sed -i "s/GITINFO/${git_info}/g" ${f}
    sed -i "s/DATEINFO/${date_info}/g" ${f}
done