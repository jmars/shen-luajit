local bundle = require('luvi').bundle

local function readKl(fileName)
  local str = bundle.readfile(fileName)

  local isDigit = {}
  for i = 0, 9 do
    isDigit[tostring(i)] = true
  end

  local string = "string"
  local list = "list"
  local atom = "atom"

  local stack = { {} }
  local reading = list

  for i = 1, #str do
    local char = str:sub(i, i)
    local reading
    ::top::
    if type(stack[#stack]) == 'table' then
      reading = list
    else
      if stack[#stack]:sub(1, 1) == '"' then
        reading = string
      else
        reading = atom
      end
    end
    if char == '\n' and reading ~= string then
      goto continue
    end
    if reading == list then
      if char == "(" then
        table.insert(stack, {})
      elseif char == ")" then
        table.insert(stack[#stack - 1], stack[#stack])
        table.remove(stack)
      elseif char == '"' then
        table.insert(stack, '"')
      elseif char == ' ' then
        goto continue
      else
        table.insert(stack, char)
      end
    elseif reading == string then
      if char == '"' then
        stack[#stack] = stack[#stack] .. '"'
        table.insert(stack[#stack - 1], stack[#stack])
        table.remove(stack)
      else
        stack[#stack] = stack[#stack] .. char
      end
    elseif reading == atom then
      if char == ')' or char == ' ' or char == '(' then
        local atom = stack[#stack]
        table.remove(stack)
        if isDigit[atom:sub(1, 1)] then
          table.insert(stack[#stack], tonumber(atom))
        elseif atom == 'true' then
          table.insert(stack[#stack], true)
        elseif atom == 'false' then
          table.insert(stack[#stack], false)
        else
          table.insert(stack[#stack], atom)
        end
        goto top
      else
        stack[#stack] = stack[#stack] .. char
      end
    else
      error(char)
    end
    ::continue::
  end

  return stack[#stack]
end

return readKl