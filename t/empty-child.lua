local dag_to_lua = require 'dag-to-lua'

local script = [[
{
    "rule":{
        "root": "node1",
        "node1":[
            [
                "code == 503",
                "node2"
            ],
            [
                "",
                null
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
            "name": "kafka-logger",
            "conf": {
                "broker_list" : {
                    "127.0.0.1":9092
                },
                "kafka_topic" : "test2",
                "key" : "key1"
            }
        }
    }
}
]]

local code,err = dag_to_lua.generate(script)
if err then
    error(err)
end


local dag_to_lua = require 'dag-to-lua'

local script = [[
{
    "rule":{
        "root": "node1",
        "node1":[
            [
                "code == 503",
                "node2"
            ],
            [
                null,
                null
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
            "name": "kafka-logger",
            "conf": {
                "broker_list" : {
                    "127.0.0.1":9092
                },
                "kafka_topic" : "test2",
                "key" : "key1"
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
