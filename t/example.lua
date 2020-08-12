local core = require("apisix.core")
local plugin = require("apisix.plugin")
local tablepool = core.tablepool
local _M = {}


local conf_11_22_33_44 = core.json.decode(
    [[{"time_window":60,"rejected_code":503,"count":2,"key":"remote_addr"}]]
)
local limit_count = plugin.get("limit-count")
local function func_rule_11_22_33_44(conf, ctx)
  local phase_fun = limit_count.access or limit_count.rewrite
  local code, _ = phase_fun(conf_11_22_33_44, ctx)
  if code == 503 then
    core.table.insert(ctx.plugins, "response-rewrite")
    core.table.insert(ctx.plugins, "yy-uu-ii-oo")
    return _M.func_rule_yy_uu_ii_oo(conf, ctx)
  end

    core.table.insert(ctx.plugins, "response-rewrite")
    core.table.insert(ctx.plugins, "vv-cc-xx-zz")
  return _M.func_rule_vv_cc_xx_zz(conf, ctx)
end
_M.func_rule_11_22_33_44 = func_rule_11_22_33_44


local conf_vv_cc_xx_zz = core.json.decode(
    [[{"body":{"message":"normal request","code":"ok"},"headers":{"X-limit-status":"normal"}}]]
)
local response_rewrite = plugin.get("response-rewrite")
local function func_rule_vv_cc_xx_zz(conf, ctx)
  local phase_fun = response_rewrite.access or response_rewrite.rewrite
  phase_fun(conf_vv_cc_xx_zz, ctx)
  return
end
_M.func_rule_vv_cc_xx_zz = func_rule_vv_cc_xx_zz


local conf_yy_uu_ii_oo = core.json.decode(
    [[{"body":{"message":"request has been limited.","code":"ok"},"headers":{"X-limit-status":"limited"}}]]
)
local response_rewrite = plugin.get("response-rewrite")
local function func_rule_yy_uu_ii_oo(conf, ctx)
  local phase_fun = response_rewrite.access or response_rewrite.rewrite
  phase_fun(conf_yy_uu_ii_oo, ctx)
  return
end
_M.func_rule_yy_uu_ii_oo = func_rule_yy_uu_ii_oo


_M.access = function(ctx)
  ctx.plugins = tablepool.fetch("script_plugins", 0, 32)
  return func_rule_11_22_33_44(ctx)
end


_M.header_filter = function(ctx)
  for i = 1, #ctx.plugins, 2 do
      local plugin_name = ctx.plugins[i]
      local plugin_conf_name = ctx.plugins[i + 1]
      local plugin_obj = plugin.get(plugin_name)
      local phase_fun = plugin_obj.header_filter
      if phase_fun then
          local code, body = phase_fun(_M.conf[plugin_conf_name], ctx)
          if code or body then
              core.response.exit(code, body)
          end
      end
  end
end


_M.body_filter = function(ctx)
  for i = 1, #ctx.plugins, 2 do
      local plugin_name = ctx.plugins[i]
      local plugin_conf_name = ctx.plugins[i + 1]
      local plugin_obj = plugin.get(plugin_name)
      local phase_fun = plugin_obj.header_filter
      if phase_fun then
          local code, body = phase_fun(_M.conf[plugin_conf_name], ctx)
          if code or body then
              core.response.exit(code, body)
          end
      end
  end
end


_M.log = function(ctx)
  for i = 1, #ctx.plugins, 2 do
      local plugin_name = ctx.plugins[i]
      local plugin_conf_name = ctx.plugins[i + 1]
      local plugin_obj = plugin.get(plugin_name)
      local phase_fun = plugin_obj.header_filter
      if phase_fun then
          local code, body = phase_fun(_M.conf[plugin_conf_name], ctx)
          if code or body then
              core.response.exit(code, body)
          end
      end
  end

  tablepool.release("script_plugins", ctx.plugins)
end


return _M
