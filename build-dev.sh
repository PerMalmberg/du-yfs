#!/bin/bash
set -e -o pipefail

clean_cov() {
  if [[ -e luacov.report.out ]]; then
      rm luacov.report.out
    fi

    if [[ -e luacov.stats.out ]]; then
     rm luacov.stats.out
    fi
}

clean_report() {
  if [[ -d ./luacov-html ]]; then
    rm -rf ./luacov-html
  fi
}

clean_cov
clean_report
busted .
luacov
clean_cov

LUA_PATH="$(pwd)/external/du-libs/src/?.lua"
export LUA_PATH
echo "$LUA_PATH"
du-lua build --copy=development/main