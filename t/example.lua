[[
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
                "body":"request has been limited.",
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
        }
    }
}
]]

local core = require("apisix.core")
local plugin = require("apisix.plugin")
local tablepool = core.tablepool


local _M = {}


_M.conf_11_22_33_44 = core.json.decode(
    [[{"time_window":60,"rejected_code":503,"count":2,"key":"remote_addr"}]]
)
local limit_count = plugin.get("limit-count")
local function func_rule_11_22_33_44(ctx)
  local phase_fun = limit_count.access or limit_count.rewrite
  local plugins = ctx.script_plugins

  local code, _ = phase_fun(_M.conf_11_22_33_44, ctx)
  if code == 503 then
    core.table.insert(plugins, "response-rewrite")
    core.table.insert(plugins, "conf_yy_uu_ii_oo")
    return _M.func_rule_yy_uu_ii_oo(ctx)
  end

  core.table.insert(plugins, "response-rewrite")
  core.table.insert(plugins, "conf_vv_cc_xx_zz")
  return _M.func_rule_vv_cc_xx_zz(ctx)
end
_M.func_rule_11_22_33_44 = func_rule_11_22_33_44


_M.conf_vv_cc_xx_zz = core.json.decode(
    [[{"body":"normal request","headers":{"X-limit-status":"normal"}}]]
)
local response_rewrite = plugin.get("response-rewrite")
local function func_rule_vv_cc_xx_zz(ctx)
  local phase_fun = response_rewrite.access or response_rewrite.rewrite
  if phase_fun then
    phase_fun(_M.conf_vv_cc_xx_zz, ctx)
  end
  return
end
_M.func_rule_vv_cc_xx_zz = func_rule_vv_cc_xx_zz


_M.conf_yy_uu_ii_oo = core.json.decode(
    [[{"body":"request has been limited","headers":{"X-limit-status":"limited"}}]]
)
local response_rewrite = plugin.get("response-rewrite")
local function func_rule_yy_uu_ii_oo(ctx)
  local phase_fun = response_rewrite.access or response_rewrite.rewrite
  if phase_fun then
    phase_fun(_M.conf_yy_uu_ii_oo, ctx)
  end
  return
end
_M.func_rule_yy_uu_ii_oo = func_rule_yy_uu_ii_oo


_M.access = function(ctx)
  ctx.script_plugins = {}
  return func_rule_11_22_33_44(ctx)
end


_M.header_filter = function(ctx)
  local plugins = ctx.script_plugins
  for i = 1, #plugins, 2 do
      local plugin_name = plugins[i]
      local plugin_conf_name = plugins[i + 1]
      local plugin_obj = plugin.get(plugin_name)
      local phase_fun = plugin_obj.header_filter
      if phase_fun then
          local code, body = phase_fun(_M[plugin_conf_name], ctx)
          if code or body then
              core.response.exit(code, body)
          end
      end
  end
end


_M.body_filter = function(ctx)
  local plugins = ctx.script_plugins
  for i = 1, #plugins, 2 do
      local plugin_name = plugins[i]
      local plugin_conf_name = plugins[i + 1]
      local plugin_obj = plugin.get(plugin_name)
      local phase_fun = plugin_obj.body_filter
      if phase_fun then
          local code, body = phase_fun(_M[plugin_conf_name], ctx)
          if code or body then
              core.response.exit(code, body)
          end
      end
  end
end


_M.log = function(ctx)
  local plugins = ctx.script_plugins
  for i = 1, #plugins, 2 do
      local plugin_name = plugins[i]
      local plugin_conf_name = plugins[i + 1]
      local plugin_obj = plugin.get(plugin_name)
      local phase_fun = plugin_obj.log
      if phase_fun then
          local code, body = phase_fun(_M[plugin_conf_name], ctx)
          if code or body then
              core.response.exit(code, body)
          end
      end
  end
  tablepool.release("script_plugins", ctx.script_plugins)
end


return _M

