local script_generator = require 'script-generator'

local script = [[
{
    "rule":{
        "root": "node1",
        "node1":[
            [
                "code == 403",
                "node2"
            ]
        ]
    },
    "conf":{
        "node1":{
            "name": "uri-blocker",
            "conf": {
                "block_rules": ["root.exe", "root.m+"]
            }
        },
        "node2":{
            "name": "fault-injection",
            "conf": {
                "abort": {
                    "http_status": 200,
                    "body": "hit our DAG"
                }
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
