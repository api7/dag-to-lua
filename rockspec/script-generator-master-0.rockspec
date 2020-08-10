package = "script-generator"
version = "master-0"
source = {
  url = "git://github.com/api7/script-generator.git",
  branch = "master",
}

description = {
  summary = "This is a lib for generating Apache APISIX Script",
  detailed = [[
]],
  homepage = "https://github.com/api7/script-generator",
  license = "Apache License 2.0"
}

dependencies = {
}

build = {
  type = "builtin",
  modules = {
    ["script-generator"] = "lib/script-generator.lua",
  }
}
