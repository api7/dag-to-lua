local script_generator = require 'script-generator'

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
            ],
            [
                "",
                "vv-cc-xx-yy"
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
        },
        "vv-cc-xx-zz":{
            "name": "response-rewrite",
            "conf": {
                "body":"normal request",
                "headers":{
                    "X-limit-status": "normal"
                }
            }
        },
        "vv-cc-xx-yy":{
            "name": "response-rewrite",
            "conf": {
                "body":"normal request",
                "headers":{
                    "X-limit-status": "normal"
                }
            }
        }
    }
}
]]

local code, err = script_generator.generate(script)
if not err then
    error("should cause error when has more then one no-condition-children.")
end
print("test passed.")
