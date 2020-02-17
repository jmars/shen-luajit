local ffi = require 'ffi'
local map, F, apply, makeNamespace = unpack(require '/src/runtime')
local createCompiler = require '/src/compiler'

local builtins = {}
local compile

local function binary(op)
  return function(namespace, scope, ast)
    local args = map(function(arg) return compile(namespace, scope, arg) end, { unpack(ast, 2) })
    local f = F(2, function(left, right)
      return op(left, right)
    end)
    return function(...)
      local env = { ... }
      local argVals = map(function(arg) return arg(unpack(env)) end, args)
      return apply(f, #argVals, unpack(argVals))
    end
  end
end

local function ternary(op)
  return function(namespace, scope, ast)
    local args = map(function(arg) return compile(namespace, scope, arg) end, { unpack(ast, 2) })
    local f = F(3, function(a, b, c)
      return op(a, b, c)
    end)
    return function(...)
      local env = {...}
      local argVals = map(function(arg) return arg(unpack(env)) end, args)
      return apply(f, #argVals, unpack(argVals))
    end
  end
end

-- functions and bindings
builtins['defun'] = function(namespace, scope, ast)
  local name = ast[2].value
  local args = map(function(node) return node.value end, ast[3].value)
  local newScope = {}
  if #args > 0 then
    newScope = { unpack(args) }
  end
  local body = compile(namespace, newScope, ast[4])
  local f = F(#args, body)
  return function()
    namespace.functions[name] = f
    return { symbol = true, value = name }
  end
end

builtins['lambda'] = function(namespace, scope, ast)
  local argName = ast[2].value
  local newScope = { argName }
  if #scope > 0 then
    newScope = { argName, unpack(scope) }
  end
  local body = compile(namespace, newScope, ast[3])
  return function(...)
    local env = { ... }
    return F(1, function(arg)
      return body(arg, unpack(env))
    end)
  end
end

builtins['freeze'] = function(namespace, scope, ast)
  local body = compile(namespace, scope, ast[2])
  return function(...)
    return { frozen = true, body = body, env = { ... } }
  end
end

builtins['thaw'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, ast[2])
  return function(...)
    local frozen = arg(...)
    return frozen.body(unpack(frozen.env))
  end
end

builtins['let'] = function(namespace, scope, ast)
  local name = ast[2].value
  local value = compile(namespace, scope, ast[3])
  local newScope = { name }
  if #scope > 0 then
    newScope = { name, unpack(scope) }
  end
  local body = compile(namespace, newScope, ast[4])
  return function(...)
    local binding = value(...)
    return body(binding, ...)
  end
end

builtins['do'] = function(namespace, scope, ast)
  local args = map(function(node) return compile(namespace, scope, node) end, { unpack(ast, 2) })
  return function(...)
    local last = nil
    for i = 1, #args do
      last = args[i](...)
    end
    return last
  end
end

-- conditionals
builtins['or'] = function(namespace, scope, ast)
  if #ast == 3 then
    local args = map(function(node) return compile(namespace, scope, node) end, { unpack(ast, 2) })
    return function(...)
      local cond = args[1](...)
      if type(cond) ~= 'boolean' then
        error({ error = true, value = 'if: cond not a bool' })
      end
      if cond then
        return true
      else
        return args[2](...)
      end
    end
  else
    -- TODO: arg check
    return binary(function(a, b) return a or b end)(namespace, scope, ast)
  end
end

builtins['and'] = function(namespace, scope, ast)
  if #ast == 3 then
    local args = map(function(node) return compile(namespace, scope, node) end, { unpack(ast, 2) })
    return function(...)
      local cond = args[1](...)
      if type(cond) ~= 'boolean' then
        error({ error = true, value = 'if: cond not a bool' })
      end
      if not cond then
        return false
      else
        return args[2](...)
      end
    end
  else
    -- TODO: arg check
    return binary(function(a, b) return a and b end)(namespace, scope, ast)
  end
end

builtins['if'] = function(namespace, scope, ast)
  if #ast == 4 then
    local args = map(function(node) return compile(namespace, scope, node) end, { unpack(ast, 2) })
    return function(...)
      if args[1](...) == true then
        return args[2](...)
      else
        return args[3](...)
      end
    end
  else
    return ternary(function(a, b, c) if a then return b else return c end end)(namespace, scope, ast)
  end
end

builtins['cond'] = function(namespace, scope, ast)
  local args = map(function(node)
    return { compile(namespace, scope, node.value[1]), compile(namespace, scope, node.value[2]) }
  end, { unpack(ast, 2 ) })
  return function(...) 
    for i = 1, #args do
      if args[i][1](...) == true then
        return args[i][2](...)
      end
    end
    error("No condition evaluated to true")
  end
end

-- error handling
builtins['trap-error'] = function(namespace, scope, ast)
  local body = compile(namespace, scope, ast[2])
  local handler = compile(namespace, scope, ast[3])
  return function(...)
    local status, result = pcall(body, ...)
    if status == true then
      return result
    else
      local err
      if type(result) == 'string' then
        err = { error = true, value = result }
      else
        err = result
      end
      local lam = handler(...)
      return apply(lam, 1, err)
    end
  end
end

builtins['simple-error'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, ast[2])
  return function(...)
    local val = arg(...)
    if type(val) ~= 'string' then
      error({ error = true, value = "simple-error: arg not a string" })
    else
      error({ error = true, value = arg(...) })
    end
  end
end

builtins['error-to-string'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, ast[2])
  return function(...)
    local err = arg(...)
    if type(err) == 'table' and err.error then
      return err.value
    else
      error({ error = true, value = "error-to-string: not an error" })
    end
  end
end

-- symbols
builtins['intern'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, ast[2])
  return function(...)
    local value = arg(...)
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
  local name = compile(namespace, scope, ast[2])
  local value = compile(namespace, scope, ast[3])
  return function(...)
    local n = name(...)
    local v = value(...)
    namespace.globals[n.value] = v
    return v
  end
end

builtins['value'] = function(namespace, scope, ast)
  local name = compile(namespace, scope, ast[2])
  return function(...)
    local n = name(...)
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
  local arg = compile(namespace, scope, ast[2])
  return function(...)
    return type(arg(...)) == 'number'
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
  local arg = compile(namespace, scope, ast[2])
  return function(...)
    return type(arg(...)) == 'string'
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
  local arg = compile(namespace, scope, ast[2])
  return function(...)
    local str = arg(...)
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
    end
  else
    return tostring(value)
  end
end

builtins['str'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, ast[2])
  return function(...)
    return str(arg(...))
  end
end

builtins['string->n'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, ast[2])
  return function(...)
    return string.byte(arg(...))
  end
end

builtins['n->string'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, ast[2])
  return function(...)
    return string.char(arg(...))
  end
end

-- vectors
builtins['absvector'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, ast[2])
  return function(...)
    local length = arg(...)
    return { vector = true, size = length }
  end
end

builtins['address->'] = ternary(function(vec, i, val)
  vec[i] = val
  return vec
end)

builtins['<-address'] = binary(function(vec, i)
  if i > vec.size then
    error({ error = true, value = "index out of bounds" })
  else
    return vec[i]
  end
end)

builtins['absvector?'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, ast[2])
  return function(...)
    local v = arg(...)
    return type(v) == 'table' and v.vector or false
  end
end

-- conses
builtins['cons?'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, ast[2])
  return function(...)
    local v = arg(...)
    return (type(v) == 'table' and v.cons and v.hd ~= nil and v.tl ~= nil) or false
  end
end

builtins['cons'] = function(namespace, scope, ast)
  local value = compile(namespace, scope, ast[2])
  local list = compile(namespace, scope, ast[3])
  return function(...)
    local v = value(...)
    local l = list(...)
    return { cons = true, hd = v, tl = l }
  end
end

builtins['hd'] = function(namespace, scope, ast)
  local value = compile(namespace, scope, ast[2])
  return function(...)
    local list = value(...)
    if list.hd == nil then
      error({ error = true, value = "hd: value is not a pair" })
    else
      return list.hd
    end
  end
end

builtins['tl'] = function(namespace, scope, ast)
  local value = compile(namespace, scope, ast[2])
  return function(...)
    local list = value(...)
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
  local arg = compile(namespace, scope, ast[2])
  return function(...)
    local stream = arg(...)
    local c = ffi.C.fgetc(io.stdin)
    return c
  end
end

builtins['open'] = binary(function(path, config)
  if config.value == 'in' then
    return io.open(path, 'rb')
  elseif config.value == 'out' then
    return io.open(path, 'wb')
  else
    error('invalid stream type')
  end
end)

builtins['close'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, ast[2])
  return function(...)
    local stream = arg(...)
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
      if a.hd == b.hd then
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
  local body = compile(namespace, scope, ast[2])
  return function(...)
    local res = body(...)
    local body = compile(namespace, scope, valToAst(res))
    return body(...)
  end
end

local counter = 0
builtins['get-time'] = function(namespace, scope, ast)
  return function(...)
    counter = counter + 1
    return counter
  end
end

builtins['type'] = binary(function(v, ty)
  return v
end)

builtins['boolean?'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, ast[2])
  return function(...)
    local res = arg(...)
    return res == true or res == false
  end
end

builtins['symbol?'] = function(namespace, scope, ast)
  local arg = compile(namespace, scope, ast[2])
  return function(...)
    local res = arg(...)
    return type(res) == 'table' and res.symbol or false
  end
end

compile = createCompiler(builtins)

return { builtins, compile }