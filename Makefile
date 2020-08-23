#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

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
deps:
	mkdir -p deps
	luarocks install rockspec/dag-to-lua-master-0.rockspec --only-deps --tree=deps --local


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

