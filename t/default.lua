local script_generator = require 'script-generator'

local script = [[
{
    "rule":{
        "11-22-33-44":[
            [
                "code == 200",
                "aa-bb-cc-dd"
            ],
            [
                "",
                "qq-ww-ee-rr"
            ]
        ],
        "aa-bb-cc-dd":[
            [
                "code == 200",
                "yy-uu-ii-oo"
            ],
            [
                "",
                "vv-cc-xx-zz"
            ]
        ],
        "yy-uu-ii-oo":[
            [
                "",
                "qq-ww-ee-rr"
            ]
        ],
        "vv-cc-xx-zz":[
            [
                "",
                "qq-ww-ee-rr"
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
        "aa-bb-cc-dd":{
          "name": "key-auth",
          "conf": {
              "key":"auth-one"
            }
        },
        "yy-uu-ii-oo":{
          "name": "response-rewrite",
          "conf": {
              "body":{"code":"ok","message":"new json body"},
              "headers":{
                  "X-Logined-status":1
              }
            }
        },
        "vv-cc-xx-zz":{
          "name": "response-rewrite",
          "conf": {
              "body":{"code":"ok","message":"new json body"},
              "headers":{
                  "X-Logined-status":0
              }
            }
        },
        "qq-ww-ee-rr":{
          "name" : "syslog",
          "conf": {
              "host":"127.0.0.1",
              "port":5044,
              "flush_limit":1
            }
        }
    }
}
]]

local code = script_generator.generate(script)
ngx.say("------->\n", code)