--
-- Licensed to the Apache Software Foundation (ASF) under one or more
-- contributor license agreements.  See the NOTICE file distributed with
-- this work for additional information regarding copyright ownership.
-- The ASF licenses this file to You under the Apache License, Version 2.0
-- (the "License"); you may not use this file except in compliance with
-- the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
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
