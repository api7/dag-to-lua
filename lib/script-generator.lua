local loadstring = loadstring
local pairs = pairs
local ipairs = ipairs
local unpack = unpack or table.unpack
local sformat = string.format
local mmax = math.max
local DEBUG = os and os.getenv and os.getenv('DEBUG') == '1'
local tab_concat = table.concat
local tab_insert = table.insert
local string = string

local tab_nkeys = require("table.nkeys")

local json_decode = require("cjson.safe").decode
local json_encode = require("cjson.safe").encode

--
-- Code generation
--

local generate_phase, generate_conf, generate_rule -- forward declaration

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


function codectx_mt:localvar(init, nres)
  local names = {}
  local nloc = self._nloc
  nres = nres or 1
  for i=1, nres do
    names[i] = sformat('var_%d_%d', self._idx, nloc+i)
  end

  self:stmt(sformat('local %s = ', tab_concat(names, ', ')), init or 'nil')
  self._nloc = nloc + nres
  return unpack(names)
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

local function q(s) return sformat('%q', s) end

function codectx_mt:generate(rule, conf)
  local root = self._root
  -- conf
  -- generate_conf(root, conf)
  --rule
  root:stmt(sformat('%s = ', "_M.access"), generate_rule(root:child(), rule, conf), "\n\n")
  -- other phose
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


function codectx_mt:as_func(name, ...)
  self:_get_loader()
  local loader, err = loadstring(tab_concat(self._code_table, ""), 'jsonschema:' .. (name or 'anonymous'))
  if loader then
    local validator
    validator, err = loader(self._uservalues, ...)
    if validator then return validator end
  end

  -- something went really wrong
  if DEBUG then
    local line=1
    print('------------------------------')
    print('FAILED to generate validator: ', err)
    print('generated code:')
    print('0001: ' .. self:as_string():gsub('\n', function()
      line = line + 1
      return sformat('\n%04d: ', line)
    end))
    print('------------------------------')
  end
  error(err)
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


--
-- Validator util functions (available in the validator context
--
local validatorlib = {}

-- TODO: this function is critical for performance, optimize it
-- Returns:
--  0 for objects
--  1 for empty object/table (these two are indistinguishable in Lua)
--  2 for arrays
function validatorlib.tablekind(t)
  local length = #t
  if length == 0 then
    if tab_nkeys(t) == 0 then
      return 1 -- empty table
    end

    return 0 -- pure hash
  end

  -- not empty, check if the number of items is the same as the length
  if tab_nkeys(t) == length then
    return 2 -- array
  end

  return 0 -- mixed array/object
end


-- used for unique items in arrays (not fast at all)
-- from: http://stackoverflow.com/questions/25922437
-- If we consider only the JSON case, this function could be simplified:
-- no loops, keys are only strings. But this library might also be used in
-- other cases.
local function deepeq(table1, table2)
   local avoid_loops = {}
   local function recurse(t1, t2)
      -- compare value types
      if type(t1) ~= type(t2) then return false end
      -- Base case: compare simple values
      if type(t1) ~= "table" then return t1 == t2 end
      -- Now, on to tables.
      -- First, let's avoid looping forever.
      if avoid_loops[t1] then return avoid_loops[t1] == t2 end
      avoid_loops[t1] = t2
      -- Copy keys from t2
      local t2keys = {}
      local t2tablekeys = {}
      for k, _ in pairs(t2) do
         if type(k) == "table" then table.insert(t2tablekeys, k) end
         t2keys[k] = true
      end
      -- Let's iterate keys from t1
      for k1, v1 in pairs(t1) do
         local v2 = t2[k1]
         if type(k1) == "table" then
            -- if key is a table, we need to find an equivalent one.
            local ok = false
            for i, tk in ipairs(t2tablekeys) do
               if deepeq(k1, tk) and recurse(v1, t2[tk]) then
                  table.remove(t2tablekeys, i)
                  t2keys[tk] = nil
                  ok = true
                  break
               end
            end
            if not ok then return false end
         else
            -- t1 has a key which t2 doesn't have, fail.
            if v2 == nil then return false end
            t2keys[k1] = nil
            if not recurse(v1, v2) then return false end
         end
      end
      -- if t2 has a key which t1 doesn't have, fail.
      if next(t2keys) then return false end
      return true
   end
   return recurse(table1, table2)
end
validatorlib.deepeq = deepeq


local function unique_item_in_array(arr)
    local existed_items, tab_items, n_tab_items = {}, {}, 0
    for i, val in ipairs(arr) do
        if type(val) == 'table' then
            n_tab_items = n_tab_items + 1
            tab_items[n_tab_items] = val
        else
            if existed_items[val] then
              return false, existed_items[val], i
            end
        end
        existed_items[val] = i
    end
    --check for table items
    if n_tab_items > 1 then
        for i = 1, n_tab_items - 1 do
            for j = i + 1, n_tab_items do
                if deepeq(tab_items[i], tab_items[j]) then
                    return false, existed_items[tab_items[i]], existed_items[tab_items[j]]
                end
            end
        end
    end
    return true
end
validatorlib.unique_item_in_array = unique_item_in_array


--
-- Validation generator
--

-- generate an expression to check a JSON type
local function typeexpr(ctx, jsontype, datatype, tablekind)
  -- TODO: optimize the type check for arays/objects (using NaN as kind?)
  if jsontype == 'object' then
    return sformat('%s == "table" and %s <= 1 ', datatype, tablekind)
  elseif jsontype == 'array' then
    return sformat(' %s == "table" and %s >= 1 ', datatype, tablekind)
  elseif jsontype == 'table' then
    return sformat(' %s == "table" ', datatype)
  elseif jsontype == 'integer' then
    return sformat(' (%s == "number" and %s(%s, 1.0) == 0.0) ',
      datatype, ctx:libfunc('math.fmod'), ctx:param(1))
  elseif jsontype == 'string' or jsontype == 'boolean' or jsontype == 'number' then
    return sformat('%s == %q', datatype, jsontype)
  elseif jsontype == 'null' then
    return sformat('%s == %s', ctx:param(1), ctx:libfunc('custom.null'))
  elseif jsontype == 'function' then
    return sformat(' %s == "function" ', datatype)
  else
    error('invalid JSON type: ' .. jsontype)
  end
end


local function str_rep_quote(m)
  local ch1 = m:sub(1, 1)
  local ch2 = m:sub(2, 2)
  if ch1 == "\\" then
    return ch2
  end

  return ch1 .. "\\" .. ch2
end


local function str_filter(s)
  s = string.format("%q", s)
  -- print(s)
  if s:find("\\\n", 1, true) then
      s = string.gsub(s, "\\\n", "\\n")
  end

  if s:find("'", 1, true) then
    s = string.gsub(s, ".?'", str_rep_quote)
  end
  return s
end


local function to_lua_code(var)
  if type(var) == "string" then
    return sformat("%q", var)
  end

  if type(var) ~= "table" then
    return var
  end

  local code = "{"
  for k, v in pairs(var) do
    code = code .. string.format("[%s] = %s,", to_lua_code(k), to_lua_code(v))
  end
  return code .. "}"
end


generate_phase = function(ctx, schema)

  ctx:stmt('return true')
  return ctx
end


generate_conf = function (ctx, conf)
  ctx:preface("\n")
  if type(conf) ~= "table" then
    return nil
  end
  for id, data in pairs(conf) do

  end
  ctx:preface("\n")
end

local function _gen_rule_lua(ctx, rule_id, plugin_conf, conditions)
    local root = ctx._root
    local plugin_name = plugin_conf.name
    local plugin_name_lua = plugin_name:gsub('-', '_')

    -- conf
    local conf_lua = "conf_" .. string.gsub(rule_id, '-', '_')
    local func_lua = "func_rule_" .. conf_lua

    root:preface("local " .. conf_lua .. " = core.json.decode(\n    [[" .. json_encode(plugin_conf.conf) .. "]]\n)")

    -- plugin
    root:preface(sformat('local %s = plugin.get("%s")', plugin_name_lua, plugin_name))
    -- function
    root:preface(sformat('local function %s(conf, ctx)', func_lua))
    root:preface(sformat('  local code, body = %s.access(%s, ctx)', plugin_name_lua, conf_lua))

    for key, condition_arr in pairs(conditions) do
        local target_id = condition_arr[2]
        local func_rule_name_node = "func_rule_conf_" .. string.gsub(target_id, '-', '_')
        -- condition
        if condition_arr[1] ~= "" then
            root:preface(sformat('  if %s then', condition_arr[1]))
            root:preface(sformat('    return %s(conf, ctx)', func_rule_name_node))
            root:preface(        '  end\n')
        else
            root:preface(sformat('  return %s(conf, ctx)', func_rule_name_node))
        end
    end
    root:preface(        'end\n\n')

    return func_lua
end

generate_rule = function (ctx, rules, conf)
  if type(rules) ~= "table" then
    return nil
  end

  local root = ctx._root
  root:preface([[local _M = {}]])
  root:preface("\n")

  local added_first_call_func

  for rule_id, conditions in pairs(rules) do
    local func_rule_name = _gen_rule_lua(ctx, rule_id, conf[rule_id], conditions)
    if not added_first_call_func then
      added_first_call_func = true
      ctx:stmt(sformat("return %s()", func_rule_name))
    end
  end

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
