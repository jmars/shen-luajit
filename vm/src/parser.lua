local function sexpToAst(sexp)
  if type(sexp) == "table" then
    local acc = {}
    for i = 1, #sexp do
      acc[i] = sexpToAst(sexp[i])
    end
    return { type = "list", value = acc }
  elseif type(sexp) == "string" then
    local firstChar = sexp:sub(1, 1)
    if firstChar == '"' then
      return { type = "string", value = sexp:sub(2, -2) }
    elseif firstChar == '-' and tostring(tonumber(sexp)) == sexp then
      return { type = "number", value = tonumber(sexp) }
    else
      return { type = "symbol", value = sexp }
    end
  elseif type(sexp) == "boolean" then
    return { type = "boolean", value = sexp }
  else -- number
    return { type = "number", value = sexp }
  end
end

return sexpToAst