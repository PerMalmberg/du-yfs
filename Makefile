.PHONY: clean test dev release
CLEAN_COV=if [ -e luacov.report.out ]; then rm luacov.report.out; fi; if [ -e luacov.stats.out ]; then rm luacov.stats.out; fi
PWD=$(shell pwd)

LUA_PATH := ./src/?.lua
LUA_PATH := $(LUA_PATH);$(PWD)/e/lib/src/?.lua
LUA_PATH := $(LUA_PATH);$(PWD)/e/render/src/?.lua
LUA_PATH := $(LUA_PATH);$(PWD)/e/render/e/stream/src/?.lua
LUA_PATH := $(LUA_PATH);$(PWD)/e/render/e/stream/e/serializer/?.lua
LUA_PATH := $(LUA_PATH);$(PWD)/e/STL/src/?.lua

LUA_PATH_TEST := $(LUA_PATH);$(PWD)/e/lib/src/builtin/du_provided/?.lua
LUA_PATH_TEST := $(LUA_PATH_TEST);$(PWD)/e/lib/external/du-unit-testing/src/?.lua
LUA_PATH_TEST := $(LUA_PATH_TEST);$(PWD)/e/lib/external/du-unit-testing/src/mocks/?.lua
LUA_PATH_TEST := $(LUA_PATH_TEST);$(PWD)/e/lib/external/du-unit-testing/external/du-luac/lua/?.lua
LUA_PATH_TEST := $(LUA_PATH_TEST);$(PWD)/e/lib/external/du-unit-testing/external/du-lua-examples/?.lua
LUA_PATH_TEST := $(LUA_PATH_TEST);$(PWD)/e/lib/external/du-unit-testing/external/du-lua-examples/api-mockup/?.lua
LUA_PATH_TEST := $(LUA_PATH_TEST);$(PWD)/e/lib/external/du-unit-testing/external/du-lua-examples/api-mockup/utils/?.lua


all: release

lua_path:
	@echo "$(LUA_PATH)"

clean_cov:
	@$(CLEAN_COV)

clean_report:
	@if [ -d ./luacov-html ]; then rm -rf ./luacov-html; fi

clean: clean_cov clean_report
	@rm -rf out

update_version:
	@./update_version_info.sh

test: clean
	@LUA_PATH="$(LUA_PATH_TEST)" busted -t "flight" . --exclude-pattern="serializer_spec.lua" --exclude-pattern="Stream_spec.lua"
	@luacov
	@$(CLEAN_COV)

dev: update_version test
	@LUA_PATH="$(LUA_PATH)" du-lua build --copy=development/variants/Unlimited

release: update_version test
	@LUA_PATH="$(LUA_PATH)" du-lua build --copy=release/variants/Unlimited

release-ci: update_version test
	jq 'del(.targets.development)' ./project.json > ./new_project.json
	mv ./new_project.json ./project.json
	@LUA_PATH="$(LUA_PATH)" du-lua build
