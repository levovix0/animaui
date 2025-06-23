import std/[macros, times, tables, macrocache, streams, sequtils, os]
import pkg/[jsony]
import pkg/sigui/[events]
import ./[exportutils]

type
  SerializeStatus* = enum
    sOk

  DeserializeStatus* = enum
    sOk
    sGreaterVersion


  EntityId* = distinct int64

  EntityIdOf*[T] = distinct EntityId


  Entity* = ref object of RootObj
    id*: EntityId
    changed*: Event[Entity]
    destroyed*: Event[Entity]
    database* {.cursor.}: Database
  

  TypeInfo* = object
    typeName*: tuple[module, name: string]
    construct*: proc(): Entity {.cdecl, gcsafe, raises: [].}


  Database* = ref object
    entities*: Table[EntityId, Entity]

    entityAdded*: Event[Entity]
    entityDestroyed*: Event[Entity]

    typeRegistry*: Table[tuple[module, name: string], TypeInfo]

    nextUnusedId*: EntityId = 1.EntityId
  

  UndoState* = object
    cause*: string
    entities_beforeChange_serialized*: seq[string]


  EntitiesBlockMetadata = object
    starts*: int64
    ends*: int64

  UndoStateMetadata = object
    cause*: string
    entities_beforeChange_serialized*: EntitiesBlockMetadata

  StorageFileMetadata = object
    entities*: EntitiesBlockMetadata
    undoStates*: seq[UndoStateMetadata]
    unusedRedoStates*: seq[UndoStateMetadata]
    currentUndoIndex*: int


  Storage* = ref object
    database* {.cursor.}: Database
    eh*: EventHandler

    file*: string
    
    maxUndoSize*: int = 1024 * 1024 * 8  # 8 MiB
    undoStates*: seq[UndoState]
    currentUndoIndex*: int

    maxUnusedRedoSize*: int = 1024 * 1024 * 4  # 4 MiB
    unusedRedoStates*: seq[UndoState]

    pendingChangedEntities*: seq[Entity]
    pendingAddedEntities*: seq[Entity]
    pendingDestroyedEntities*: seq[Entity]


  ProxyEntity* = ref object of Entity
    data*: string



proc serializeData*[T](data: T, s: var string) =
  when T is int:
    serializeData(data.int64, s)  # force 64 bit
  else:
    when sizeof(data) == 0: return

    s.setLen(s.len + sizeof(data))
    copyMem(s[s.len - sizeof(data)].addr, data.addr, sizeof(data))


proc serializeData*(data: string, s: var string) =
  serializeData(data.len.int64, s)
  if data.len == 0: return
  s.setLen(s.len + data.len)
  copyMem(s[s.len - data.len].addr, data[0].addr, data.len)


proc serializeData*[T](data: seq[T], s: var string) =
  serializeData(data.len.int64, s)
  for x in data:
    serializeData(x, s)


proc serializeData*[T: pointer|ptr|ref](data: T, s: var string) {.error: "pointer serialization is non-trivial".}


proc deserializeData*[T](data: var T, s: string, i: var int) =
  when T is int:
    var data_64bit: int64
    deserializeData(data_64bit, s, i)
    data = data_64bit.int
  else:
    when sizeof(data) == 0: return

    if i + sizeof(data) > s.len:
      raise EOFError.newException("unexpected end of data")

    copyMem(data.addr, s[i].addr, sizeof(data))
    inc i, sizeof(data)


proc deserializeData*(data: var string, s: string, i: var int) =
  var len: int64
  deserializeData(len, s, i)

  if i + len > s.len:
    raise EOFError.newException("unexpected end of data")

  if len == 0:
    data = ""
    return

  data.setLen(len.int)
  copyMem(data[0].addr, s[i].addr, len)
  inc i, len


proc deserializeData*[T](data: var seq[T], s: string, i: var int) =
  var len: int64
  deserializeData(len, s, i)

  data.setLen(len.int)

  for dataI in 0 ..< len:
    deserializeData(data[dataI], s, i)


proc deserializeData*[T: pointer|ptr|ref](data: var T, s: string, i: var int) {.error: "pointer deserialization is non-trivial".}


# --- Entity ---

macro super*[T: Entity](obj: T): auto =
  var t = obj.getTypeImpl
  if t.kind == nnkRefTy and t[0].kind == nnkSym:
    t = t[0].getImpl
  
  if t.kind == nnkTypeDef and t[2].kind == nnkObjectTy and t[2][1].kind == nnkOfInherit:
    return nnkDotExpr.newTree(obj, t[2][1][0])
  else:
    error("unexpected type impl", obj)


macro registerEntityType*(moduleName: static string, typ: type) =
  result = newStmtList()

  let typName = typ.repr

  CacheSeq("animaui / types to register").incl nnkBracket.newTree(newLit moduleName, typ)

  result.add quote do:
    method typeName*(this: `typ`): tuple[module, name: string] {.raises: [].} =
      (`moduleName`, `typName`)


proc `==`*(a, b: EntityId): bool {.borrow.}
template `==`*[T](a, b: EntityIdOf[T]): bool = (EntityId)(a) == (EntityId)(b)

proc asTyped*[T: Entity](id: EntityId, t: typedesc[T]): EntityIdOf[T] {.inline.} = (EntityIdOf[T])(id)
proc asUntyped*[T: Entity](id: EntityIdOf[T]): EntityId {.inline.} = (EntityId)(id)

proc asTyped*[T: Entity, TOther: Entity](id: EntityIdOf[TOther], t: typedesc[T]): EntityIdOf[T] {.inline.} = (EntityIdOf[T])(id.EntityId)

proc typedId*[T: Entity](entity: T): EntityIdOf[T] {.inline.} = (EntityIdOf[T])(entity.id)


proc `$`*(entityId: EntityId): string =
  "EntityId " & $entityId.int64

proc `$`*[T](entityId: EntityIdOf[T]): string =
  "EntityIdOf[" & $T & "] " & $entityId.int64


macro addRegistredEntityTypeInfosToDatabase*(db: Database) =
  result = newStmtList()
  for typ in CacheSeq("animaui / types to register"):
    let typModule = typ[0]
    let typName = newLit typ[1].repr
    let typT = typ[1]
    
    result.add quote do:
      `db`.typeRegistry[(`typModule`, `typName`)] = TypeInfo(
        typeName: (`typModule`, `typName`),
        construct: proc(): Entity {.cdecl, raises: [].} = `typT`(),
      )



method typeName*(this: Entity): tuple[module, name: string] {.base, gcsafe, raises: [].} = ("animaui/editor/entities", "Entity")

proc version*(this: type Entity): int {.inline.} = 1

method serialize*(this: Entity, s: var string): SerializeStatus {.base, gcsafe, animaui_api.} =
  this.id.serializeData(s)

  this.typeof.version.serializeData(s)
  this.typeName.module.serializeData(s)
  this.typeName.name.serializeData(s)


method deserialize*(this: Entity, s: string, i: var int): DeserializeStatus {.base, gcsafe, animaui_api.} =
  var
    version: int
    id: EntityId
    typeName: tuple[module, name: string]
  
  id.deserializeData(s, i)
  version.deserializeData(s, i)
  typeName.module.deserializeData(s, i)
  typeName.name.deserializeData(s, i)

  if (version != this.typeof.version) or (typeName != this.typeName):
    return sGreaterVersion

  if id != this.id:
    raise AssertionDefect.newException("unexpected entity id")


method onDestroy*(entity: Entity) {.base, animaui_api.} =
  disconnect entity.changed
  disconnect entity.destroyed


proc cloneUntyped(this: Entity): Entity {.animaui_api.} =
  assert this != nil

  var s: string
  discard this.serialize(s)
  result = this.database.typeRegistry[this.typeName].construct()
  result.database = this.database

  let zeroId = 0.EntityId
  copyMem(s[0].addr, zeroId.addr, EntityId.sizeof)

  var i: int
  doassert result.deserialize(s, i) == sOk


proc clone*[T: Entity](this: T): T =
  bind cloneUntyped
  T(cloneUntyped(this))


proc copyInto*(fromEntity, toEntity: Entity) {.animaui_api.} =
  doassert fromEntity.typeName == toEntity.typeName

  var s: string
  discard fromEntity.serialize(s)

  copyMem(s[0].addr, toEntity.id.addr, EntityId.sizeof)

  var i: int
  doassert toEntity.deserialize(s, i) == sOk


# --- Database ---

proc `[]`*(db: Database, id: EntityId): Entity #[not nil]# {.animaui_api, raises: [KeyError].} =
  ## get entity by id
  ## if entity does not exist, raises KeyError
  db.entities[id]

proc `{}`*(db: Database, id: EntityId): Entity {.animaui_api, raises: [].} =
  ## get entity by id
  ## if entity does not exist, returns nil
  db.entities.getOrDefault(id, nil)


proc `[]`*[T: Entity](db: Database, id: EntityIdOf[T]): T {.raises: [KeyError, ValueError].} =
  ## get entity by id
  ## if entity does not exist, raises KeyError
  ## if entity has different type, raises ValueError
  var e = db.entities[id.asUntyped]
  if e of T:
    T(e)
  else:
    raise ValueError.newException("entity has different type, expected " & $T & ", got " & $e.typeName)

proc `{}`*[T: Entity](db: Database, id: EntityIdOf[T]): T {.raises: [].} =
  ## get entity by id
  ## if entity does not exist or has different type, returns nil
  var e = db.entities.getOrDefault(id.asUntyped, nil)
  if e of T:
    T(e)
  else:
    nil


proc defragment*(db: Database) {.animaui_api.} =
  ## todo


proc add*(db: Database, entity: Entity) {.animaui_api.} =
  assert entity != nil

  if entity.id == 0.EntityId:
    if db.nextUnusedId == EntityId.high:
      defragment db

    entity.id = db.nextUnusedId
    inc db.nextUnusedId

  var record: ptr Entity = db.entities.mgetOrPut(entity.id, nil).addr
  if record[] != nil and record[] != entity:
    raise AssertionDefect.newException("diffirent entity with the same id already exists in database")
  
  if record[] == nil:
    record[] = entity
    record[].database = db

    {.cast(gcsafe).}:
      db.entityAdded.emit(entity)


proc destroy*(db: Database, entity: Entity) {.animaui_api.} =
  assert entity != nil

  var record: Entity
  if db.entities.pop(entity.id, record):
    if record != entity:
      raise AssertionDefect.newException("diffirent entity with the same id was in database")

    entity.destroyed.emit(entity)
    db.entityDestroyed.emit(entity)
    entity.onDestroy()


proc new*[T: Entity](db: Database, entity: T): T =
  db.add(entity)
  result = entity



# --- Storage ---


proc newStorage*(db: Database): Storage {.animaui_api.} =
  result = Storage(
    database: db,
  )
  proc subscribeToEvents(storage: Storage) {.nimcall.} =
    proc onEntityChanged(entity: Entity) {.closure.} =
      storage.pendingChangedEntities.add entity

    proc onEntityDestroyed(entity: Entity) {.closure.} =
      storage.pendingDestroyedEntities.add entity
      entity.changed.disconnect storage.eh

    proc onEntityAdded(entity: Entity) {.closure.} =
      storage.pendingAddedEntities.add entity
      entity.changed.connect storage.eh, onEntityChanged

    storage.database.entityAdded.connect storage.eh, onEntityAdded
    storage.database.entityDestroyed.connect storage.eh, onEntityDestroyed

  subscribeToEvents(result)


iterator entities(stream: Stream, b: EntitiesBlockMetadata): string =
  stream.setPosition(b.starts)

  while stream.getPosition() + sizeof(int64) <= b.ends:
    var len: int64
    if stream.readData(len.addr, sizeof(len)) != sizeof(len):
      raise IOError.newException("invalid file format")

    if (let s = stream.readStr(len); s.len == len and stream.getPosition() + s.len <= b.ends):
      yield s
    else:
      raise IOError.newException("invalid file format")


proc readEntityShallow(storage: Storage, s: string, res: var Entity) {.raises: [IOError].} =
  var
    version: int
    id: EntityId
    typeName: tuple[module, name: string]
  
  var i = 0
  
  version.deserializeData(s, i)
  id.deserializeData(s, i)
  typeName.module.deserializeData(s, i)
  typeName.name.deserializeData(s, i)

  if res != nil:
    doassert version == res.typeof.version
    doassert id == res.id
    doassert typeName == res.typeName

  else:
    let typeinfo = storage.database.typeRegistry.getOrDefault(typeName)
    if typeinfo.typeName != typeName or typeinfo.construct == nil:
      res = ProxyEntity(id: id, data: s)
      return
    
    res = typeinfo.construct()

    res.database = storage.database


proc readEntity(storage: Storage, s: string): Entity =
  var i = 0
  var
    version: int
    id: EntityId
  
  version.deserializeData(s, i)
  id.deserializeData(s, i)

  var res {.cursor.} = storage.database.entities.mgetOrPut(id, nil)
  assert res != nil

  i = 0
  
  case res.deserialize(s, i)
  of sOk: discard
  of sGreaterVersion:
    disconnect res.changed
    disconnect res.destroyed
    res = ProxyEntity(id: res.id, data: s)

  return res


proc load*(storage: Storage, filePath: string) {.animaui_api, raises: [IOError, OSError, JsonError, Exception].} =
  assert storage.file == "", "some file is already loaded"
  storage.file = filePath

  let data = newFileStream(filePath, fmRead)

  block read_magic:
    var buf: array["animaui".len, char]
    if data.readData(buf.addr, buf.len) != sizeof(buf) or buf != "animaui":
      raise IOError.newException("invalid file format")

  block read_version:
    var version: int64
    if data.readData(version.addr, sizeof(version)) != sizeof(version) and version != 1:
      raise IOError.newException("invalid file format")
  

  var metadata: StorageFileMetadata

  block read_metadata:
    var pos: int64
    if data.readData(pos.addr, sizeof(pos)) != sizeof(pos):
      raise IOError.newException("invalid file format")

    data.setPosition(pos)

    var len: int64
    if data.readData(len.addr, sizeof(len)) != sizeof(len):
      raise IOError.newException("invalid file format")

    if (let s = data.readStr(len); s.len == len):
      try:
        metadata = fromJson(s, StorageFileMetadata)
      except ValueError:
        raise JsonError.newException("invalid file format")
    else:
      raise IOError.newException("invalid file format")


  block read_entities:
    for s in entities(data, metadata.entities):
      var entity: Entity
      readEntityShallow(storage, s, entity)
      try:
        storage.database.add entity
      except:
        raise IOError.newException(
          "got an exception while adding entity: " & getCurrentExceptionMsg() &
          ", stack trace of underlying exception: " & getCurrentException().getStackTrace()
        )
    
    for s in entities(data, metadata.entities):
      let entity = readEntity(storage, s)
      entity.changed.emit(entity)
  

  block read_undoStates:
    storage.currentUndoIndex = metadata.currentUndoIndex

    for usm in metadata.undoStates:
      var us = UndoState(cause: usm.cause)

      for s in entities(data, usm.entities_beforeChange_serialized):
        us.entities_beforeChange_serialized.add s

  block read_unusedRedoStates:
    for ursm in metadata.unusedRedoStates:
      var urs = UndoState(cause: ursm.cause)

      for s in entities(data, ursm.entities_beforeChange_serialized):
        urs.entities_beforeChange_serialized.add s


proc create*(storage: Storage, filePath: string) {.animaui_api.} =
  assert storage.file == "", "some file is already loaded"
  storage.file = filePath



proc save*(storage: Storage) {.animaui_api, raises: [IOError, OSError, Exception].} =
  assert storage.file != "", "no file is loaded"

  let data = newStringStream()

  data.write "animaui"
  data.write 1.int64


  var metadata = StorageFileMetadata(
    currentUndoIndex: storage.currentUndoIndex,
    undoStates: storage.undoStates.mapIt(UndoStateMetadata(
      cause: it.cause,
    )),
    unusedRedoStates: storage.unusedRedoStates.mapIt(UndoStateMetadata(
      cause: it.cause,
    )),
  )

  let metadata_pos_i = data.getPosition
  data.write 0.int64


  block write_entities:
    metadata.entities.starts = data.getPosition

    for entity in storage.database.entities.values:
      var s: string
      if entity.serialize(s) != sOk:
        raise IOError.newException("failed to serialize entity")

      data.write s.len.int64
      data.write s

    metadata.entities.ends = data.getPosition
  

  block write_undoStates:
    for i, us in storage.undoStates:
      metadata.undoStates[i].entities_beforeChange_serialized.starts = data.getPosition

      for s in us.entities_beforeChange_serialized:
        data.write s.len.int64
        data.write s

      metadata.undoStates[i].entities_beforeChange_serialized.ends = data.getPosition

  block write_unusedRedoStates:
    for i, urs in storage.unusedRedoStates:
      metadata.unusedRedoStates[i].entities_beforeChange_serialized.starts = data.getPosition

      for s in urs.entities_beforeChange_serialized:
        data.write s.len.int64
        data.write s

      metadata.unusedRedoStates[i].entities_beforeChange_serialized.ends = data.getPosition


  block write_metadata:
    let metadata_pos = data.getPosition

    let metadata_json = toJson(metadata)
    data.write metadata_json.len.int64
    data.write metadata_json

    data.setPosition(metadata_pos_i)
    data.write metadata_pos.int64


  storage.file.writeFile data.data



# --- ProxyEntity ---

registerEntityType "animaui/editor/entities", ProxyEntity

method serialize*(this: ProxyEntity, s: var string): SerializeStatus {.animaui_api.} =
  this.data.serializeData(s)

