local bundle = require('luvi').bundle
loadstring(bundle.readfile("luvit-loader.lua"), "bundle:luvit-loader.lua")()

-- local STP = require "/stacktrace"
-- debug.traceback = STP.stacktrace

local readKl = require '/src/reader'
local sexpToAst = require '/src/parser'
local F, makeNamespace = unpack(require '/src/runtime')
local builtins, compile = unpack(require '/src/primitives')
-- local pprint = require '/pprint'

local function execKl(namespace, file)
  local ast = sexpToAst(readKl(file)).value
  local last
  for i=1, #ast do
    last = compile(namespace, {}, ast[i])({})
  end
  return last
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
  init({})
  local repl = namespace.functions['shen.repl']
  repl({})
  -- execKl(namespace, './test.kl')
  -- local test = namespace.functions['test']
  -- pprint(apply(test, {}))
end

bootstrap()