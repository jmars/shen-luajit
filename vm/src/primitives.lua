local ffi = require 'ffi'
local F, apply, makeNamespace = unpack(require '/src/runtime')
local createCompiler = require '/src/compiler'
local pprint = require '/pprint'

local builtins = {}
local compile

local function binary(op)
  return function(namespace, scope, ast)
    local args = map(function(arg) return compile(namespace, scope, arg) end, tail(ast))
    local f = F(2, function(args)
      return op(nth(1, args), nth(2, args))
    end)
    return function(env)
      local argVals = map(function(arg) return arg(env) end, args)
      return apply(f, argVals)
    end
  end
end

local function ternary(op)
  return function(namespace, scope, ast)
    local args = map(function(arg) return compile(namespace, scope, arg) end, tail(ast))
    local f = F(3, function(args)
      return op(nth(1, args), nth(2, args), nth(3, args))
    end)
    return function(env)
      local argVals = map(function(arg) return arg(env) end, args)
      return apply(f, argVals)
    end
  end
end

-- functions and bindings
builtins['defun'] = function(namespace, scope, ast)
  local name = nth(2, ast).value
  local args = map(function(node) return node.value end, nth(3, ast).value)
  local newScope = iter({})
  if length(args) > 0 then
    newScope = args
  end
  local body = compile(namespace, newScope, nth(4, ast))
  local f = F(length(args), function(args)
    return body(args)
  end)
  return function()
    namespace.functions[name] = f
    return { symbol = true, value = name }
  end
end

builtins['lambda'] = function(namespace, scope, ast)
  local argName = nth(2, ast).value
  local newScope = iter({ argName })
  if length(scope) > 0 then
    newScope = chain({ argName }, scope)
  end
  local body = compile(namespace, newScope, nth(3, ast))
  return function(env)
    return F(1, function(args)
      return body(chain(args, env))
    end)
  end
end

builtins['freeze'] = function(namespace, scope, ast)
  local body = compile(namespace, scope, nth(2, ast))
  return function(env)
    return { frozen = true, body = body, env = env }
  end
end

builtins['thaw'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, nth(2, ast))
  return function(env)
    local frozen = arg(env)
    return frozen.body(frozen.env)
  end
end

builtins['let'] = function(namespace, scope, ast)
  local name = nth(2, ast).value
  local value = compile(namespace, scope, nth(3, ast))
  local newScope = { name }
  if length(scope) > 0 then
    newScope = chain({ name }, scope)
  end
  local body = compile(namespace, newScope, nth(4, ast))
  return function(env)
    local binding = value(env)
    return body(chain({ binding }, env))
  end
end

builtins['do'] = function(namespace, scope, ast)
  local args = map(function(node) return compile(namespace, scope, node) end, tail(ast))
  return function(env)
    return reduce(function(last, x)
      return x(env)
    end, nil, args)
  end
end

-- conditionals
builtins['or'] = function(namespace, scope, ast)
  if length(ast) == 3 then
    local args = map(function(node) return compile(namespace, scope, node) end, tail(ast))
    return function(env)
      local cond = head(args)(env)
      if type(cond) ~= 'boolean' then
        error({ error = true, value = 'if: cond not a bool' })
      end
      if cond then
        return true
      else
        return nth(2, args)(env)
      end
    end
  else
    -- TODO: arg check
    return binary(function(a, b) return a or b end)(namespace, scope, ast)
  end
end

builtins['and'] = function(namespace, scope, ast)
  if length(ast) == 3 then
    local args = map(function(node) return compile(namespace, scope, node) end, tail(ast))
    return function(env)
      local cond = head(args)(env)
      if type(cond) ~= 'boolean' then
        error({ error = true, value = 'if: cond not a bool' })
      end
      if not cond then
        return false
      else
        return nth(2, args)(env)
      end
    end
  else
    -- TODO: arg check
    return binary(function(a, b) return a and b end)(namespace, scope, ast)
  end
end

builtins['if'] = function(namespace, scope, ast)
  if length(ast) == 4 then
    local args = map(function(node) return compile(namespace, scope, node) end, tail(ast))
    return function(env)
      if head(args)(env) == true then
        return nth(2, args)(env)
      else
        return nth(3, args)(env)
      end
    end
  else
    return ternary(function(a, b, c) if a then return b else return c end end)(namespace, scope, ast)
  end
end

builtins['cond'] = function(namespace, scope, ast)
  local args = map(function(node)
    return { compile(namespace, scope, nth(1, node.value)), compile(namespace, scope, nth(2, node.value)) }
  end, tail(ast))
  return function(env) 
    for i = 1, length(args) do
      if head(nth(i, args))(env) == true then
        return nth(2, nth(i, args))(env)
      end
    end
    error("No condition evaluated to true")
  end
end

-- error handling
builtins['trap-error'] = function(namespace, scope, ast)
  local body = compile(namespace, scope, nth(2, ast))
  local handler = compile(namespace, scope, nth(3, ast))
  return function(env)
    local status, result = pcall(body, env)
    if status == true then
      return result
    else
      local err
      if type(result) == 'string' then
        err = { error = true, value = result }
      else
        err = result
      end
      local lam = handler(env)
      return apply(lam, { err })
    end
  end
end

builtins['simple-error'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, nth(2, ast))
  return function(env)
    local val = arg(env)
    if type(val) ~= 'string' then
      error({ error = true, value = "simple-error: arg not a string" })
    else
      error({ error = true, value = val })
    end
  end
end

builtins['error-to-string'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, nth(2, ast))
  return function(env)
    local err = arg(env)
    if type(err) == 'table' and err.error then
      return err.value
    else
      error({ error = true, value = "error-to-string: not an error" })
    end
  end
end

-- symbols
builtins['intern'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, nth(2, ast))
  return function(env)
    local value = arg(env)
    if value == 'true' then
      return true
    elseif value == 'false' then
      return false
    else
      return { symbol = true, value = value }
    end
  end
end

builtins['set'] = function(namespace, scope, ast)
  local name = compile(namespace, scope, nth(2, ast))
  local value = compile(namespace, scope, nth(3, ast))
  return function(env)
    local n = name(env)
    local v = value(env)
    namespace.globals[n.value] = v
    return v
  end
end

builtins['value'] = function(namespace, scope, ast)
  local name = compile(namespace, scope, nth(2, ast))
  return function(env)
    local n = name(env)
    local val = namespace.globals[n.value]
    if val == nil then
      error({ error = true, "no value " .. n.value })
    else
      return val
    end
  end
end

-- numerics
builtins['number?'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, nth(2, ast))
  return function(env)
    return type(arg(env)) == 'number'
  end
end

builtins['+'] = binary(function(a, b) return a + b end)
builtins['-'] = binary(function(a, b) return a - b end)
builtins['*'] = binary(function(a, b) return a * b end)
builtins['/'] = binary(function(a, b) return a / b end)
builtins['>'] = binary(function(a, b) return a > b end)
builtins['<'] = binary(function(a, b) return a < b end)
builtins['>='] = binary(function(a, b) return a <= b end)
builtins['<='] = binary(function(a, b) return a >= b end)

-- strings
builtins['string?'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, nth(2, ast))
  return function(env)
    return type(arg(env)) == 'string'
  end
end

builtins['pos'] = binary(function(str, i)
  local char = str:sub(i+1, i+1)
  if char == '' then
    error({ error = true, value = "pos: invalid index" })
  else
    return char
  end
end)

builtins['tlstr'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, nth(2, ast))
  return function(env)
    local str = arg(env)
    if str == '' then
      error({ error = true, value = "tlstr on empty string" })
    else
      return str:sub(2)
    end
  end
end

builtins['cn'] = binary(function(a, b)
  return a .. b
end)

local function str(value)
  local t = type(value)
  if t == 'boolean' or t == 'number' or t == 'string' then
    return tostring(value)
  elseif t == 'table' then
    if value.symbol then
      return value.value
    elseif value.error then
      return value.value
    elseif type(value.f) == 'function' then
      return "#<function>"
    elseif value.cons then
      if value.hd == nil and value.tl == nil then
        return '[]'
      else
        return '[cons '..str(value.hd)..' '..str(value.tl)..']'
      end
    end
  else
    return tostring(value)
  end
end

builtins['str'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, nth(2, ast))
  return function(env)
    return str(arg(env))
  end
end

builtins['string->n'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, nth(2, ast))
  return function(env)
    return string.byte(arg(env))
  end
end

builtins['n->string'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, nth(2, ast))
  return function(env)
    return string.char(arg(env))
  end
end

-- vectors
builtins['absvector'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, nth(2, ast))
  return function(env)
    local length = arg(env)
    return { vector = true, size = length }
  end
end

builtins['address->'] = ternary(function(vec, i, val)
  if not vec.vector then
    error({ error = true, value = 'address->: not a vector' })
  end
  vec[i] = val
  return vec
end)

builtins['<-address'] = binary(function(vec, i)
  if not vec.vector then
    error({ error = true, value = 'address->: not a vector' })
  end
  if i > vec.size then
    error({ error = true, value = "index out of bounds" })
  else
    return vec[i]
  end
end)

builtins['absvector?'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, nth(2, ast))
  return function(env)
    local v = arg(env)
    return type(v) == 'table' and v.vector or false
  end
end

-- conses
builtins['cons?'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, nth(2, ast))
  return function(env)
    local v = arg(env)
    return (type(v) == 'table' and v.cons and v.hd ~= nil and v.tl ~= nil) or false
  end
end

builtins['cons'] = function(namespace, scope, ast)
  local value = compile(namespace, scope, nth(2, ast))
  local list = compile(namespace, scope, nth(3, ast))
  return function(env)
    local v = value(env)
    local l = list(env)
    return { cons = true, hd = v, tl = l }
  end
end

builtins['hd'] = function(namespace, scope, ast)
  local value = compile(namespace, scope, nth(2, ast))
  return function(env)
    local list = value(env)
    if list.hd == nil then
      error({ error = true, value = "hd: value is not a pair" })
    else
      return list.hd
    end
  end
end

builtins['tl'] = function(namespace, scope, ast)
  local value = compile(namespace, scope, nth(2, ast))
  return function(env)
    local list = value(env)
    if list.tl == nil then
      error({ error = true, value = "tl: value is not a pair" })
    else
      return list.tl
    end
  end
end

-- streams
builtins['write-byte'] = binary(function(byte, stream)
  stream:write(string.char(byte))
  stream:flush()
  return byte
end)

ffi.cdef[[
  int fgetc(void *);
]]

builtins['read-byte'] = function(namespace, scope, ast)
  -- TODO: error handling
  local arg = compile(namespace, scope, nth(2, ast))
  return function(env)
    local stream = arg(env)
    local c = ffi.C.fgetc(stream)
    return c
  end
end

builtins['open'] = binary(function(path, config)
  local stream
  if config.value == 'in' then
    stream = io.open(path, 'rb')
  elseif config.value == 'out' then
    stream = io.open(path, 'wb')
  else
    error({ error = true, value = 'invalid stream type' })
  end
  if stream == nil then
    error({ error = true, value = 'failed to open ' .. path })
  end
  return stream
end)

builtins['close'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, nth(2, ast))
  return function(env)
    local stream = arg(env)
    stream:close()
    return { cons = true }
  end
end

-- TODO: make this a metatable
local function equals(a, b)
  if a == b then
    return true
  elseif type(a) == 'table' and type(b) == 'table' then
    if a.symbol and b.symbol then
      return a.value == b.value
    elseif a.error and b.error then
      return a.value == b.value
    elseif a.absvector and b.absvector then
      for i = 0, #a - 1 do
        if not equals(a[i], b[i]) then
          return false
        end
      end
      return true
    elseif a.cons and b.cons then
      if equals(a.hd, b.hd) then
        return equals(a.tl, b.tl)
      else
        return false
      end
    else
      return false
    end
  else
    return false
  end
end

builtins['='] = binary(equals)

local listToAst

local function valToAst(val)
  if type(val) == 'string' then
    return { type = 'string', value = val }
  elseif type(val) == 'number' then
    return { type = 'number', value = val }
  elseif type(val) == 'boolean' then
    return { type = 'boolean', value = val }
  else
    if val.symbol then
      return { type = 'symbol', value = val.value }
    elseif val.cons then
      return listToAst(val)
    end
  end
  error("Invalid value")
end

listToAst = function(list)
  local value = {}
  local l = list
  while l.hd ~= nil do
    table.insert(value, valToAst(l.hd))
    l = l.tl
  end
  return { type = "list", value = value }
end

builtins['eval-kl'] = function(namespace, scope, ast)
  local body = compile(namespace, scope, nth(2, ast))
  return function(env)
    local res = body(env)
    local body = compile(namespace, scope, valToAst(res))
    return body(env)
  end
end

local start_time = os.time(os.date("!*t"))
builtins['get-time'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, nth(2, ast))
  return function(env)
    local s = arg(env).value
    if s == "unix" then
      return os.time(os.date("!*t"))
    else
      return os.time(os.date("!*t")) - start_time
    end
  end
end

builtins['type'] = binary(function(v, ty)
  return v
end)

builtins['boolean?'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, nth(2, ast))
  return function(env)
    local res = arg(env)
    return res == true or res == false
  end
end

builtins['symbol?'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, nth(2, ast))
  return function(env)
    local res = arg(env)
    return type(res) == 'table' and res.symbol or false
  end
end

--[[
each(function(k, v)
  builtins[k] = function(...)
    local real = v(...)
    return function(env)
      print(k)
      return real(env)
    end
  end
end, builtins)
]]

compile = createCompiler(builtins)

return { builtins, compile }
