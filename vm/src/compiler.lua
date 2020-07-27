local F, apply, makeNamespace = unpack(require '/src/runtime')

local function emptylist()
  return { cons = true }
end

local function createCompiler(builtins)
  local function compile(namespace, scope, ast)
    if ast.type == 'list' then
      local values = ast.value
      local car = nth(1, values)
      if #values == 0 then
        return emptylist
      end
      if type(car) == 'table' and
        car.type == 'symbol' and
        builtins[car.value] ~= nil
        then
        return builtins[car.value](namespace, scope, values)
      elseif type(car) == 'table' and
        car.type == 'symbol' and
        builtins[car.value] == nil and
        (index(car.value, scope) or -1) == -1
        then
        local args = map(function(arg) return compile(namespace, scope, arg) end, tail(values))
        return function(env)
          local argVals = map(function(arg) return arg(env) end, args)
          local f = namespace.functions[car.value]
          return apply(f, argVals)
        end
      else
        local f = compile(namespace, scope, car)
        local args = map(function(arg) return compile(namespace, scope, arg) end, tail(values))
        return function(env)
          local argVals = map(function(arg) return arg(env) end, args)
          local lam = f(env)
          return apply(lam, argVals)
        end
      end
    elseif ast.type == 'string' or ast.type == 'number' or ast.type == 'boolean' then
      local value = ast.value
      return function(env)
        return value
      end
    elseif ast.type == 'symbol' then
      -- TODO: interning
      local index = index(ast.value, scope) or -1
      if index >= 1 then
        return function(env)
          local r = nth(index, env)
          return r
        end
      else
        local value = { symbol = true, value = ast.value }
        return function(env)
          return value
        end
      end
    else
      error("unknown node")
    end
  end
  return compile
end

return createCompiler