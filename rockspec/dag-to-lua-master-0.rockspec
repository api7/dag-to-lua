package = "dag-to-lua"
version = "master-0"
source = {
  url = "git://github.com/api7/dag-to-lua.git",
  branch = "master",
}

description = {
  summary = "This is a library for generating Apache APISIX Lua scripts from DAG",
  detailed = [[
]],
  homepage = "https://github.com/api7/dag-to-lua",
  license = "Apache License 2.0"
}

dependencies = {
}

build = {
  type = "builtin",
  modules = {
    ["dag-to-lua"] = "lib/dag-to-lua.lua",
  }
}
