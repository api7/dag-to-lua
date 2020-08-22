local dag_to_lua = require 'dag-to-lua'

local script = [[
{
    "rule":{
        "root": "11-22-33-44",
        "11-22-33-44":[
            [
                "code == 503",
                "yy-uu-ii-oo"
            ],
            [
                "",
                "vv-cc-xx-zz"
            ]
        ]
    },
    "conf":{
        "11-22-33-44":{
            "name": "limit-count",
            "conf": {
                "count":2,
                "time_window":60,
                "rejected_code":503,
                "key":"remote_addr"
            }
        },
        "yy-uu-ii-oo":{
            "name": "response-rewrite",
            "conf": {
                "body":"request has been limited",
                "headers":{
                    "X-limit-status": "limited"
                }
            }
        }
    }
}
]]

local _, err = dag_to_lua.generate(script)
if err == nil then
    error("should return error here.")
end

print("test passed.")
