local pprint = require '/pprint'

local funcMT = {}

function funcMT:__call(args)
  local f = self
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
      local new = { unpack(args) }
      for i = 1, #next do
        new[i + #new] = next[i]
      end
      return f.f(new)
    end)
  end
  -- overapply
  if n > f.a then
    local res = f.f({ unpack(args, 1, n) })
    return res({ unpack(args, n) })
  end
end


local function F(arity, fun)
  return setmetatable({
    type = "function",
    a = arity,
    f = fun,
  }, funcMT)
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

return { F, makeNamespace }