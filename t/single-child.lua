local dag_to_lua = require 'dag-to-lua'

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

local code,err = dag_to_lua.generate(script)
if err then
    error(err)
end
print("test passed.")
