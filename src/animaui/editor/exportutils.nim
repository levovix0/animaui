import std/[macros]

const animaui_use_shared {.booldefine.} = false

when animaui_use_shared:
  import std/[sequtils]


macro animaui_api*(body) =
  when true:
    proc reprIdentSafe(x: NimNode): string =
      for c in x.repr:
        case c
        of {'a'..'z', 'A'..'Z', '0'..'9', '_'}:
          result.add c
        of '{':
          result.add "_lb"
        of '}':
          result.add "_rb"
        of '<':
          result.add "_lt"
        of '>':
          result.add "_gt"
        of '=':
          result.add "_eq"
        of '[':
          result.add "_lq"
        of ']':
          result.add "_rq"
        of '(':
          result.add "_ls"
        of ')':
          result.add "_gs"
        else:
          discard

    if body[2].kind == nnkGenericParams:
      error("generics are not supported for {.animaui_api.}", body[2])

    var mangledName = "_" & reprIdentSafe(body.name)

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
  
  else:
    return body

