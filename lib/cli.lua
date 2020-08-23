local dag_to_lua = require 'dag-to-lua'

if not arg[1] then
	error("no script config param!")
end

local code, err = dag_to_lua.generate(arg[1])
if err then
	error(err)
end

print(code)
