import std/[macros, times]
import pkg/[vmath, chroma]
import ./[exportutils]

type
  SerializeStatus* = enum
    sOk
    sError

  DeserializeStatus* = enum
    sOk
    sError
    sGreaterVersion

  EntityId* = distinct int64

  Entity* = ref object of RootObj


  EntityDrawContext* = ref object of RootObj
    screenCoordinateSystem*: Mat4

  FrameEntity* = ref object of Entity
    ecs*: Mat4 = mat4(1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1)
      ## internal coordinate system (a matrix that transforms a coordinate from internal space to world space)
    color*: Color


  SceneEntity* = ref object of Entity

  Animation* = ref object of SceneEntity
    animationObject*: EntityId
    startTime*: Duration
    endTime*: Duration


proc serializeData*[T](data: T, s: var string) =
  when T is int:
    serializeData(data.int64, s)  # force 64 bit
  else:
    when sizeof(data) == 0: return

    s.setLen(s.len + sizeof(data))
    copyMem(s[s.len - sizeof(data)].addr, data.addr, sizeof(data))

proc serializeData*[T: pointer|ptr|ref](data: T, s: var string) {.error: "pointer serialization is non-trivial".}
proc serializeData*(data: EntityId, s: var string) {.error: "EntityId serialization is non-trivial".}


proc deserializeData*[T](data: T, s: string, i: var int) =
  when T is int:
    deserializeData(data.int64, s, i)  # force 64 bit
  else:
    when sizeof(data) == 0: return

    if i + sizeof(data) > s.len:
      raise ValueError.newException("unexpected end of data")

    copyMem(data.addr, s[i].addr, sizeof(data))
    inc i, sizeof(data)

proc deserializeData*[T: pointer|ptr|ref](data: T, s: string, i: var int) {.error: "pointer deserialization is non-trivial".}
proc deserializeData*(data: EntityId, s: string, i: var int) {.error: "EntityId deserialization is non-trivial".}


# --- Entity ---

macro super*[T: Entity](obj: T): auto =
  var t = obj.getTypeImpl
  if t.kind == nnkRefTy and t[0].kind == nnkSym:
    t = t[0].getImpl
  
  if t.kind == nnkTypeDef and t[2].kind == nnkObjectTy and t[2][1].kind == nnkOfInherit:
    return nnkDotExpr.newTree(obj, t[2][1][0])
  else:
    error("unexpected type impl", obj)


method serialize*(this: Entity, s: var string): SerializeStatus {.base, animaui_api.} =
  discard


method deserialize*(this: Entity, s: string, i: var int): DeserializeStatus {.base, animaui_api.} =
  discard


# --- FrameEntity ---

proc version*(this: type FrameEntity): int {.compileTime.} = 1

method draw*(this: FrameEntity, ctx: EntityDrawContext) {.base, animaui_api.} =
  discard


method transformBy*(this: FrameEntity, m: Mat4) {.base, animaui_api.} =
  discard


method serialize*(this: FrameEntity, s: var string): SerializeStatus {.animaui_api.} =
  if (let status = procCall this.super.serialize(s); status != sOk): return status
  
  this.typeof.version.serializeData(s)
  
  this.ecs.serializeData(s)
  this.color.serializeData(s)


method deserialize*(this: FrameEntity, s: string, i: var int): DeserializeStatus {.animaui_api.} =
  if (let status = procCall this.super.deserialize(s, i); status != sOk): return status
  
  var version: int
  version.deserializeData(s, i)
  if version > this.typeof.version: return sGreaterVersion
  
  this.ecs.deserializeData(s, i)
  this.color.deserializeData(s, i)


# --- Animation ---

proc version*(this: type Animation): int {.compileTime.} = 1

method serialize*(this: Animation, s: var string): SerializeStatus {.animaui_api.} =
  if (let status = procCall this.super.serialize(s); status != sOk): return status

  this.typeof.version.serializeData(s)

  # this.animationObject.serializeData(s)
  this.startTime.serializeData(s)
  this.endTime.serializeData(s)


method deserialize*(this: Animation, s: string, i: var int): DeserializeStatus {.animaui_api.} =
  if (let status = procCall this.super.deserialize(s, i); status != sOk): return status

  var version: int
  version.deserializeData(s, i)
  if version > this.typeof.version: return sGreaterVersion

  # this.animationObject.deserializeData(s, i)
  this.startTime.deserializeData(s, i)
  this.endTime.deserializeData(s, i)

