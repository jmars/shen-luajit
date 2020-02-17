local bundle = require('luvi').bundle
loadstring(bundle.readfile("luvit-loader.lua"), "bundle:luvit-loader.lua")()

local readKl = require '/src/reader'
local sexpToAst = require '/src/parser'
local map, F, apply, makeNamespace = unpack(require '/src/runtime')
local builtins, compile = unpack(require '/src/primitives')

local function execKl(namespace, file)
  local ast = sexpToAst(readKl(file)).value
  local last
  for i = 1, #ast do
    local func = compile(namespace, {}, ast[i])
    last = func({})
  end
end

local function bootstrap()
  local namespace = makeNamespace()
  execKl(namespace, "./klambda/toplevel.kl")
  execKl(namespace, "./klambda/core.kl")
  execKl(namespace, "./klambda/sys.kl")
  execKl(namespace, "./klambda/dict.kl")
  execKl(namespace, "./klambda/sequent.kl")
  execKl(namespace, "./klambda/yacc.kl")
  execKl(namespace, "./klambda/reader.kl")
  execKl(namespace, "./klambda/prolog.kl")
  execKl(namespace, "./klambda/track.kl")
  execKl(namespace, "./klambda/load.kl")
  execKl(namespace, "./klambda/writer.kl")
  execKl(namespace, "./klambda/macros.kl")
  execKl(namespace, "./klambda/declarations.kl")
  execKl(namespace, "./klambda/t-star.kl")
  execKl(namespace, "./klambda/types.kl")
  execKl(namespace, "./klambda/init.kl")
  local init = namespace.functions['shen.initialise']
  apply(init, 0)
  local repl = namespace.functions['shen.repl']
  apply(repl, 0)
end

bootstrap()