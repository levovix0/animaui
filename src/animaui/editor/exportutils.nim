import std/[macros]

const animaui_use_shared {.booldefine.} = false

when animaui_use_shared:
  import std/[sequtils]


macro animaui_api*(body) =
  proc reprIdentSafe(x: NimNode): string =
    result = x.repr
    var i = 0
    while i < result.len:
      if result[i] notin {'a'..'z', 'A'..'Z', '_'}:
        result[i..i] = ""
      inc i

  var mangledName = $body.name

  if body.params[0].kind == nnkEmpty:
    mangledName &= "_"
  else:
    mangledName &= "_" & reprIdentSafe(body.params[0])

  for param in body.params[1..^1]:
    mangledName &= "_" & reprIdentSafe(param[^2])

  result = body
  
  if result.pragma.kind == nnkEmpty:
    result.pragma = nnkPragma.newTree()
  
  when animaui_use_shared:
    if body.kind == nnkMethodDef:
      let impl = nnkProcDef.newTree(body[0..^1])
      impl.body = newEmptyNode()
      impl[0] = ident("impl")
      impl.pragma = nnkPragma.newTree(nnkExprColonExpr.newTree(ident("importc"), newLit(mangledName)))
      result.body = nnkStmtList.newTree(
        impl,
        newCall(ident("impl"), body.params[1..^1].mapIt(it[0..^3]).concat)
      )
    else:
      result.pragma.add nnkExprColonExpr.newTree(ident("importc"), newLit(mangledName))
      result.body = newEmptyNode()
  
  else:
    result.pragma.add nnkExprColonExpr.newTree(ident("exportc"), newLit(mangledName))

