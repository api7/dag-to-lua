OR_EXEC ?= $(shell which openresty)
LUA_JIT_DIR ?= $(shell ${OR_EXEC} -V 2>&1 | grep prefix | grep -Eo 'prefix=(.*?)/nginx' | grep -Eo '/.*/')luajit
LUAROCKS_VER ?= $(shell luarocks --version | grep -E -o  "luarocks [0-9]+.")
LUA_PATH ?= "./lib/?.lua;./deps/lib/lua/5.1/?.lua;./deps/share/lua/5.1/?.lua;;"
LUA_CPATH ?= "./deps/lib/lua/5.1/?.so;;"


### help:         Show Makefile rules.
.PHONY: help
help:
	@echo Makefile rules:
	@echo
	@grep -E '^### [-A-Za-z0-9_]+:' Makefile | sed 's/###/   /'


### dev:          Create a development ENV
.PHONY: deps
dev:
	mkdir -p deps
ifeq ($(LUAROCKS_VER),luarocks 3.)
	luarocks install --lua-dir=$(LUA_JIT_DIR) rockspec/script-generator-master-0.rockspec --only-deps --tree=deps --local
else
	luarocks install rockspec/script-generator-master-0.rockspec --only-deps --tree=deps --local
endif


### test:         Run the test case
test:
	LUA_PATH=$(LUA_PATH) LUA_CPATH=$(LUA_CPATH) resty t/default.lua > t/generated.lua
	luacheck t/generated.lua


### lint:             Lint Lua source code
.PHONY: lint
lint: utils
	./utils/check-lua-code-style.sh

### clean:        Clean the test case
.PHONY: clean
clean:
	@rm -rf deps

