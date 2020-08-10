local pairs = pairs
local ipairs = ipairs
local sformat = string.format
local mmax = math.max
local tab_concat = table.concat
local tab_insert = table.insert
local string = string
local json_decode = require("cjson.safe").decode
local json_encode = require("cjson.safe").encode

--
-- Code generation
--

local generate_phase, generate_rule -- forward declaration

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


function codectx_mt:param(n)
  self._nparams = mmax(n, self._nparams)
  return 'p_' .. n
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
  root:stmt(sformat('%s = ', "_M.access"), generate_rule(root:child(), rule, conf), "\n\n")
  -- other phase
  root:stmt(sformat('%s = ', "_M.log"), generate_phase(root:child()), "\n\n")
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
    for i=1, self._nparams do
      insert_code('p_' .. i, code_table)
      if i ~= self._nparams then insert_code(', ', code_table) end
    end
    insert_code(')\n', code_table)
    indent = string.rep('  ', self._idx)
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
    _nparams = 0,
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


generate_phase = function(ctx, schema)
  ctx:stmt('return true')
  return ctx
end


local function conf_lua_name(rule_id)
  local conf_lua = "conf_" .. string.gsub(rule_id, '-', '_')
  return conf_lua
end


local function func_lua_name(rule_id)
  local conf_lua = "func_rule_" .. string.gsub(rule_id, '-', '_')
  return conf_lua
end


local function _gen_common_phase_lua(ctx)
end


local function _gen_rule_lua(ctx, rule_id, plugin_conf, conditions, target_ids)
    local root = ctx._root
    local plugin_name = plugin_conf.name
    local plugin_name_lua = plugin_name:gsub('-', '_')

    -- conf
    local conf_lua = conf_lua_name(rule_id)
    local func_lua = func_lua_name(rule_id)

    root:preface("local " .. conf_lua ..
      " = core.json.decode(\n    [[" .. json_encode(plugin_conf.conf) .. "]]\n)")

    -- plugin
    root:preface(sformat('local %s = plugin.get("%s")', plugin_name_lua, plugin_name))
    -- function
    root:preface(sformat('local function %s(conf, ctx)', func_lua))

    -- local condition_fun1 = limit_count["access"] and limit_count["access"] or limit_count["rewrite"]
    root:preface(sformat('  local phase_fun = %s.access or %s.rewrite',
      plugin_name_lua, plugin_name_lua))

    root:preface(sformat('  local code, body = phase_fun(%s, ctx)', conf_lua))

    for key, condition_arr in pairs(conditions) do
        local target_id = condition_arr[2]
        local func_target = func_lua_name(target_id)
        target_ids[target_id] = 1
        -- condition
        if condition_arr[1] ~= "" then
            root:preface(sformat('  if %s then', condition_arr[1]))
            root:preface(sformat('    return _M.%s(conf, ctx)', func_target))
            root:preface(        '  end\n')
        else
            root:preface(sformat('  return _M.%s(conf, ctx)', func_target))
        end
    end
    root:preface(        'end')
    root:preface(sformat('_M.%s = %s\n\n', func_lua, func_lua))

    return func_lua
end


local function _gen_last_rule_lua(ctx, rule_id, plugin_conf)
    local root = ctx._root
    local plugin_name = plugin_conf.name
    local plugin_name_lua = plugin_name:gsub('-', '_')

    -- conf
    local conf_lua = conf_lua_name(rule_id)
    local func_lua = func_lua_name(rule_id)

    root:preface("local " .. conf_lua ..
     " = core.json.decode(\n    [[" .. json_encode(plugin_conf.conf) .. "]]\n)")

    -- plugin
    root:preface(sformat('local %s = plugin.get("%s")', plugin_name_lua, plugin_name))
    -- function
    root:preface(sformat('local function %s(conf, ctx)', func_lua))
    root:preface(sformat('  %s.access(%s, ctx)', plugin_name_lua, conf_lua))

    root:preface(        'return\n')
    root:preface(        'end')
    root:preface(sformat('_M.%s = %s\n\n', func_lua, func_lua))

    return func_lua
end


generate_rule = function (ctx, rules, conf)
  if type(rules) ~= "table" then
    return nil
  end

  local root = ctx._root
  root:preface([[local _M = {}]])
  root:preface("\n")

  local rule_ids, target_ids = {}, {}

  for rule_id, conditions in pairs(rules) do
    if rule_id ~= "root" then
      rule_ids[rule_id] = 1
      _gen_rule_lua(ctx, rule_id, conf[rule_id], conditions, target_ids)
    end
  end

  for target_id,_ in pairs(target_ids) do
    -- last node
    if not rule_ids[target_id] then
      _gen_last_rule_lua(ctx, target_id, conf[target_id])
    end
  end

  local root_func = func_lua_name(rules.root)
  ctx:stmt(sformat("return %s()", root_func))

  return ctx
end


local function generate_ctx(conf, options)
  local data = json_decode(conf)
  if data == nil then
      return nil, "parse conf failed"
  end

  data.rule = data.rule or {}
  data.conf = data.conf or {}
  local ctx = codectx(data.rule, data.conf, options or {})

  ctx:preface('local core = require("apisix.core")')
  ctx:preface('local plugin = require("apisix.plugin")')

  ctx:stmt('return ', ctx:generate(data.rule, data.conf))

  return ctx, nil
end


return {
    generate = function(conf, options)
        local cxt, err = generate_ctx(conf, options)
        if not cxt then
            return nil, err
        end

        return cxt:as_lua(), nil
    end,
}
