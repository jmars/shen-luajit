local pprint = require '/pprint'


local function F(arity, fun)
  return {
    type = "function",
    a = arity,
    f = fun,
  }
end

local function apply(f, args)
  if f.type ~= "function" then
    pprint(f, args)
    error("Tried to apply non-function")
  end
  -- match
  local n = #args
  if f.a == n then
    return f.f(args)
  end
  -- underapply
  if n < f.a then
    return F(f.a - n, function(next)
      return f.f(chain(args, next))
    end)
  end
  -- overapply
  if n > f.a then
    local res = f.f(take_n(n, args))
    return apply(res, drop_n(n, args))
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

function map(f, t)
  local r = {}
  for i=1, #t do
    table.insert(r, f(t[i]))
  end
  return r
end

function tail(t)
  local r = {}
  for i=2,#t do
    table.insert(r, t[i])
  end
  return r
end

function index(v, t)
  for i=1,#t do
    if t[i] == v then
      return i
    end
  end
  return -1
end

return { F, apply, makeNamespace }