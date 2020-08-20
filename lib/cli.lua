local script_generator = require 'script-generator'

if not arg[1] then
	error("no script config param!")
end

local code, err = script_generator.generate(arg[1])
if err then
	error(err)
end

print(code)
