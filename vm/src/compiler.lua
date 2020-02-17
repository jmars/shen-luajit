local map, F, apply, makeNamespace, find = unpack(require '/src/runtime')

local function emptylist()
  return { cons = true }
end

local function createCompiler(builtins)
  local function compile(namespace, scope, ast)
    if ast.type == 'list' then
      local values = ast.value
      if #values == 0 then
        return emptylist
      end
      if type(values[1]) == 'table' and
        values[1].type == 'symbol' and
        builtins[values[1].value] ~= nil
        then
        return builtins[values[1].value](namespace, scope, values)
      elseif type(values[1]) == 'table' and
        values[1].type == 'symbol' and
        builtins[values[1].value] == nil and
        find(scope, values[1].value) == -1
        then
        local args = map(function(arg) return compile(namespace, scope, arg) end, { unpack(values, 2 )})
        return function(...)
          local env = { ... }
          local argVals = map(function(arg) return arg(unpack(env)) end, args)
          local f = namespace.functions[values[1].value]
          return apply(f, #argVals, unpack(argVals))
        end
      else
        local f = compile(namespace, scope, values[1])
        local args = map(function(arg) return compile(namespace, scope, arg) end, { unpack(values, 2) })
        return function(...)
          local env = { ... }
          local argVals = map(function(arg) return arg(unpack(env)) end, args)
          local lam = f(...)
          return apply(lam, #argVals, unpack(argVals))
        end
      end
    elseif ast.type == 'string' or ast.type == 'number' or ast.type == 'boolean' then
      local value = ast.value
      return function()
        return value
      end
    elseif ast.type == 'symbol' then
      -- TODO: interning
      local index = find(scope, ast.value)
      if index >= 1 then
        return function(...)
          local env = { ... }
          if env[index] == nil then
            error({ error = true, value = "invalid var: " .. ast.value})
          end
          return env[index]
        end
      else
        local value = { symbol = true, value = ast.value }
        return function()
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