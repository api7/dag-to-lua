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
local pairs       = pairs
local ipairs      = ipairs
local sformat     = string.format
local tab_concat  = table.concat
local tab_insert  = table.insert
local string      = string


local json_decode
local json_encode
do
  local ok, cjson = pcall(require, 'cjson.safe')
  if ok then
    json_decode = require("cjson.safe").decode
    json_encode = cjson.encode
  else
    local json = require "json"
    json_decode = json.decode
    json_encode = json.encode
  end
end


local nkeys
do
  local ok, table_nkeys = pcall(require, 'table.nkeys')
  if ok then
    nkeys = table_nkeys
  else
    nkeys = function(t)
      local count = 0
      for _, _ in pairs(t) do
        count = count + 1
      end
      return count
    end
  end
end


--
-- Code generation
--

local generate_common_phase, generate_rule -- forward declaration

local codectx_mt = {}
codectx_mt.__index = codectx_mt


function codectx_mt:libfunc(globalname)
    local root = self._root
    local localname = root._globals[globalname]

    if not localname then
        localname = globalname:gsub('%.', '_')
        root._globals[globalname] = localname
        root:preface(sformat('local %s = %s', localname, globalname))
    end
    return localname
end


local function q(s) return sformat('%q', s) end


function codectx_mt:param(param)
    tab_insert(self._params, param)
    return param
end


function codectx_mt:label()
    local nlabel = self._nlabels + 1
    self._nlabels = nlabel
    return 'label_' .. nlabel
end


-- Returns an expression that will result in passed value.
-- Currently user vlaues are stored in an array to avoid consuming a lot of local
-- and upvalue slots. Array accesses are still decently fast.
function codectx_mt:uservalue(val)
    local slot = #self._root._uservalues + 1
    self._root._uservalues[slot] = val
    return sformat('uservalues[%d]', slot)
end


function codectx_mt:generate(rule, conf)
    local root = self._root
    --rule
    local rule_ctx, err = generate_rule(root:child(), rule, conf)
    if err ~= nil then
        return nil, err
    end

    root:stmt(sformat('%s = ', "_M.access"), rule_ctx, "\n\n")
    -- other phase
    root:stmt(sformat('%s = ', "_M.header_filter"),
        generate_common_phase(root:child(), "header_filter"), "\n\n")
    root:stmt(sformat('%s = ', "_M.body_filter"),
        generate_common_phase(root:child(), "body_filter"), "\n\n")

    local release_plugins = 'tablepool.release("script_plugins", ctx.script_plugins)'
    root:stmt(sformat('%s = ', "_M.log"),
        generate_common_phase(root:child(), "log", release_plugins), "\n\n")

    return "_M"
end


function codectx_mt:preface(...)
    assert(self._preface, 'preface is only available for root contexts')
    for i=1, select('#', ...) do
        tab_insert(self._preface, (select(i, ...)))
    end
    tab_insert(self._preface, '\n')
end


function codectx_mt:stmt(...)
    for i=1, select('#', ...) do
        tab_insert(self._body, (select(i, ...)))
    end
    tab_insert(self._body, '\n')
end


-- load doesn't like at all empty string, but sometimes it is easier to add
-- some in the chunk buffer
local function insert_code(chunk, code_table)
    if chunk and chunk ~= '' then
        tab_insert(code_table, chunk)
    end
end


function codectx_mt:_generate(code_table)
    local indent = ''
    if self._root == self then
        for _, stmt in ipairs(self._preface) do
            insert_code(indent, code_table)
            if getmetatable(stmt) == codectx_mt then
                stmt:_generate(code_table)
            else
                insert_code(stmt, code_table)
            end
        end
    else
        insert_code('function(', code_table)
        for _,param in ipairs(self._params) do
            insert_code(param, code_table)
        end
        insert_code(')\n', code_table)
        indent = string.rep('', self._idx)
    end

    for _, stmt in ipairs(self._body) do
        insert_code(indent, code_table)
        if getmetatable(stmt) == codectx_mt then
            stmt:_generate(code_table)
        else
            insert_code(stmt, code_table)
        end
    end

    if self._root ~= self then
        insert_code('end', code_table)
    end
end


function codectx_mt:_get_loader()
    self._code_table = {}
    self:_generate(self._code_table)
    return self._code_table
end


function codectx_mt:as_lua()
    self:_get_loader()
    return tab_concat(self._code_table)
end


-- returns a child code context with the current context as parent
function codectx_mt:child(ref)
  return setmetatable({
      _schema = ref,
      _idx = self._idx + 1,
      _nloc = 0,
      _nlabels = 0,
      _body = {},
      _root = self._root,
      _params = {},
  }, codectx_mt)
end


-- returns a root code context. A root code context holds the library function
-- cache (as upvalues for the child contexts), a preface, and no named params
local function codectx(rule, conf, options)
    local self = setmetatable({
        _rule = rule,
        _conf = conf,
        _code_table = {},
        _idx = 0,
        -- code generation
        _nloc = 0,
        _nlabels = 0,
        _preface = {},
        _body = {},
        _globals = {},
        _uservalues = {}
    }, codectx_mt)
    self._root = self
    return self
end


generate_common_phase = function(ctx, phase, tail_lua)
    ctx:stmt('local plugins = ctx.script_plugins')
    ctx:stmt('for i = 1, #plugins, 2 do')
    ctx:stmt('    local plugin_name = plugins[i]')
    ctx:stmt('    local plugin_conf_name = plugins[i + 1]')
    ctx:stmt('    local plugin_obj = plugin.get(plugin_name)')
    ctx:stmt('    local phase_fun = plugin_obj.' .. phase)
    ctx:stmt('    if phase_fun then')
    ctx:stmt(sformat('        phase_fun(_M[plugin_conf_name], %s)', ctx:param("ctx")))
    ctx:stmt('    end')
    ctx:stmt('end')
    if tail_lua then
      ctx:stmt(      tail_lua)
    end
    return ctx
end


local function conf_lua_name(rule_id)
    if not rule_id then
        return ""
    end
    local conf_lua = "conf_" .. string.gsub(rule_id, '-', '_')
    return conf_lua
end


local function func_lua_name(rule_id)
    if not rule_id then
        return ""
    end
    local func_lua = "func_rule_" .. string.gsub(rule_id, '-', '_')
    return func_lua
end


local function plugin_lua_name(plugin_name)
    if not plugin_name then
        return ""
    end
    local plugin_lua = string.gsub(plugin_name, '-', '_')
    return plugin_lua
end


local function _gen_rule_lua(ctx, rule_id, conf, conditions, target_ids)
    local root = ctx._root
    local plugin_conf = conf[rule_id]
    local plugin_name = plugin_conf.name
    local plugin_name_lua = plugin_lua_name(plugin_name)

    if not plugin_conf then
        return nil, "invalid conf!"
    end

    -- conf
    local conf_lua = conf_lua_name(rule_id)
    local func_lua = func_lua_name(rule_id)

    root:preface("_M." .. conf_lua .. " = core.json.decode(\n    [[" ..
    json_encode(plugin_conf.conf) .. "]]\n)")

    -- plugin
    root:preface(sformat('local %s = plugin.get("%s")', plugin_name_lua, plugin_name))
    -- function
    root:preface(sformat('local function %s(ctx)', func_lua))

    root:preface(sformat('  local phase_fun = %s.access or %s.rewrite',
        plugin_name_lua, plugin_name_lua))

    root:preface(        '  local plugins = ctx.script_plugins\n')

    root:preface(sformat('  local code, _ = phase_fun(%s, ctx)', '_M.' .. conf_lua))

    root:preface(sformat('  core.table.insert(plugins, %s)', q(plugin_name)))
    root:preface(sformat('  core.table.insert(plugins, %s)', q(conf_lua)))

    local condition_children = 0
    local no_condition_children = 0
    for key, condition_arr in pairs(conditions) do
        local target_id = condition_arr[2]
        if target_id and target_id ~= "" then
            local func_target = func_lua_name(target_id)
            target_ids[target_id] = 1
            local target_plugin_conf = conf[target_id]
            if not target_plugin_conf then
                return nil, "invalid conf!"
            end

            -- condition
            if condition_arr[1] and condition_arr[1] ~= "" then
                if condition_children > 0 then
                    root:preface(sformat('  else if %s then', condition_arr[1]))
                else
                    root:preface(sformat('  if %s then', condition_arr[1]))
                end
                root:preface(sformat('    return _M.%s(ctx)', func_target))
                root:preface(        '  end\n')
                condition_children = condition_children + 1
            else
                no_condition_children = no_condition_children + 1
                root:preface(sformat('  return _M.%s(ctx)', func_target))
            end
        end
    end

    -- don't have a no condtion child
    if no_condition_children == 0 and condition_children > 0 then
        root:preface(                '  else if code or body then')
        root:preface(                '    core.response.exit(code, body)')
        root:preface(                '  end')
    end

    if no_condition_children > 1 then
        return nil, "can't have more then one no-condition children!"
    end

    root:preface(        'end')
    root:preface(sformat('_M.%s = %s\n\n', func_lua, func_lua))

    return func_lua
end


local function _gen_last_rule_lua(ctx, rule_id, plugin_conf)
    local root = ctx._root
    if not plugin_conf then
        return nil, "invalid conf!"
    end

    local plugin_name = plugin_conf.name
    local plugin_name_lua = plugin_lua_name(plugin_name)

    -- conf
    local conf_lua = conf_lua_name(rule_id)
    local func_lua = func_lua_name(rule_id)

    root:preface("_M." .. conf_lua ..
     " = core.json.decode(\n    [[" .. json_encode(plugin_conf.conf) .. "]]\n)")

    -- plugin
    root:preface(sformat('local %s = plugin.get("%s")', plugin_name_lua, plugin_name))
    -- function
    root:preface(sformat('local function %s(ctx)', func_lua))

    root:preface(        '  local plugins = ctx.script_plugins\n')

    root:preface(sformat('  local phase_fun = %s.access or %s.rewrite',
      plugin_name_lua, plugin_name_lua))

    root:preface(        '  if phase_fun then')
    root:preface(sformat('    local code, body = phase_fun(%s, ctx)', '_M.' .. conf_lua))
    root:preface(        '    if code or body then')
    root:preface(        '      core.response.exit(code, body)')
    root:preface(        '    end')
    root:preface(        '  end')

    root:preface(sformat('  core.table.insert(plugins, %s)', q(plugin_name)))
    root:preface(sformat('  core.table.insert(plugins, %s)', q(conf_lua)))

    root:preface(        '  return')
    root:preface(        'end')
    root:preface(sformat('_M.%s = %s\n\n', func_lua, func_lua))

    return func_lua
end


generate_rule = function (ctx, rules, conf)
    if type(rules) ~= "table" then
        return nil, "invalid rules!"
    end

    local root = ctx._root
    root:preface([[local _M = {}]])
    root:preface("\n")

    local rule_ids, target_ids = {}, {}

    if not rules.root then
        return nil, "invalid rules!"
    end

    if nkeys(rules) == 1 then
        local _, err = _gen_rule_lua(ctx, rules.root, conf, {}, target_ids)
        if err ~= nil then
            return nil, err
        end
    else
        for rule_id, conditions in pairs(rules) do
            if rule_id ~= "root" then
                rule_ids[rule_id] = 1
                local _, err = _gen_rule_lua(ctx, rule_id, conf, conditions, target_ids)
                if err ~= nil then
                    return nil, err
                end
            end
        end
    end

    for target_id,_ in pairs(target_ids) do
        -- last node
        if not rule_ids[target_id] then
            local _, err = _gen_last_rule_lua(ctx, target_id, conf[target_id])
            if err ~= nil then
                return nil, err
            end
        end
    end

    local root_func = func_lua_name(rules.root)
    ctx:stmt('  ctx.script_plugins = {}')
    ctx:stmt(sformat("  return %s(%s)", root_func, ctx:param("ctx")))

    return ctx
end


local function generate_ctx(conf, options)
    -- local data, err = json_decode(conf)
    local ok, data = pcall(json_decode, conf)
    if not ok then
        return nil, data
    end

    data.rule = data.rule or {}
    data.conf = data.conf or {}
    local ctx = codectx(data.rule, data.conf, options or {})

    ctx:preface('local core = require("apisix.core")')
    ctx:preface('local plugin = require("apisix.plugin")')
    ctx:preface('local tablepool = core.tablepool')
    ctx:preface('\n')

    local class_name, err = ctx:generate(data.rule, data.conf)
    if err then
        return nil, err
    end

    ctx:stmt('return ', class_name)

    return ctx, nil
end


return {
    generate = function(conf, options)
        local ctx, err = generate_ctx(conf, options)
        if not ctx then
            return nil, err
        end

        return ctx:as_lua(), nil
    end,
}
