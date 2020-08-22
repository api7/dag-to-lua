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
	luarocks install rockspec/script-generator-master-0.rockspec --only-deps --tree=deps --local


### test:         Run the test case
test:
	LUA_PATH=$(LUA_PATH) LUA_CPATH=$(LUA_CPATH) lua t/conf-err.lua
	LUA_PATH=$(LUA_PATH) LUA_CPATH=$(LUA_CPATH) lua t/missing-config.lua
	LUA_PATH=$(LUA_PATH) LUA_CPATH=$(LUA_CPATH) lua t/no-root.lua
	LUA_PATH=$(LUA_PATH) LUA_CPATH=$(LUA_CPATH) lua t/single-child.lua
	LUA_PATH=$(LUA_PATH) LUA_CPATH=$(LUA_CPATH) lua t/empty-child.lua
	LUA_PATH=$(LUA_PATH) LUA_CPATH=$(LUA_CPATH) lua t/no-child.lua
	LUA_PATH=$(LUA_PATH) LUA_CPATH=$(LUA_CPATH) lua t/multi-no-condition-children.lua
	LUA_PATH=$(LUA_PATH) LUA_CPATH=$(LUA_CPATH) lua t/default.lua > t/generated.lua
	luacheck t/generated.lua
	luacheck -q lib

### lint:             Lint Lua source code
.PHONY: lint
lint: utils
	./utils/check-lua-code-style.sh

### clean:        Clean the test case
.PHONY: clean
clean:
	@rm -rf deps

