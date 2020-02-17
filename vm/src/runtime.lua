-- TODO: remove for varargs
local function map(f, list)
  local res = {}
  for i = 1, #list do
    res[i] = f(list[i])
  end
  return res
end

function find(table, element)
  for i = 1, #table do
    local el = table[i]
    if el == element then
      return i
    end
  end
  return -1
end

local function F(arity, fun)
  return {
    a = arity,
    f = fun,
  }
end

local function apply(f, n, ...)
  if f.a == n then
    return f.f(...)
  end
  local args = { ... }
  if n < f.a then
    return F(f.a - n, function(...)
      local next = { ... }
      for i = 1, #next do
        args[i + #args] = next[i]
      end
      return f.f(unpack(args))
    end)
  end
  if n > f.a then
    local res = f.f(unpack(args, 1, n))
    return apply(res, n - f.a, unpack(args, n))
  end
end

function capture(cmd, raw)
  local f = assert(io.popen(cmd, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  if raw then return s end
  s = string.gsub(s, '^%s+', '')
  s = string.gsub(s, '%s+$', '')
  s = string.gsub(s, '[\n\r]+', ' ')
  return s
end

local function makeNamespace()
  local globals = {
    ["*stinput*"] = io.stdin,
    ["*stoutput*"] = io.stdout,
    ["*sterror*"] = io.stderr,
    ["*home-directory*"] = os.getenv("HOME"),
    ["*language*"] = _VERSION,
    ["*implementation*"] = jit.version,
    ["*os*"] = capture('uname'),
    ["*port*"] = "0.1",
    ["*porters*"] = "Jaye Marshall <marshall.jaye@gmail.com>"
  }
  return {
    functions = {},
    globals = globals
  }
end

return { map, F, apply, makeNamespace, find }