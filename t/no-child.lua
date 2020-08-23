local dag_to_lua = require 'dag-to-lua'

local script = [[
{
    "rule":{
        "root": "node1",
        "node1":[
        ]
    },
    "conf":{
        "node1":{
            "name": "uri-blocker",
            "conf": {
                "block_rules": ["root.exe", "root.m+"]
            }
        }
    }
}
]]

local code,err = dag_to_lua.generate(script)
if err then
    error(err)
end
print("test passed.")
