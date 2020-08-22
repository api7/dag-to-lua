local script_generator = require 'script-generator'

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

local code,err = script_generator.generate(script)
if err then
    error(err)
end
print("test passed.")
