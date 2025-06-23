import std/[times, os, strutils, strformat]
import pkg/[imageman, suru]
import pkg/sigui/[uibase, animations]
import ./[keyframes, screenRecording, entities, exportutils]

type
  EntityDrawContext* = ref object of RootObj
    database*: Database
    scene*: Scene
    sceneView*: SceneView
    siguiCtx*: uibase.DrawContext


  FrameEntityRole* = enum
    ## for each "frame object" there are two frame entities:
    ## - initial frame entity is the one that is created by user, it's properties are "by default" for all frames.
    ## - current frame entity is the one that is draw on each frame and the one that frequently changed by animations.
    ## `FrameEntity.pair` is initial frame for current and the other way around
    initial
    current

  FrameEntity* = ref object of Entity
    scene*: EntityIdOf[Scene]
    role*: FrameEntityRole
    pair*: EntityIdOf[FrameEntity]
  

  BoxEntity* = ref object of FrameEntity
    pos*: Vec2
    size*: Vec2


  SceneEntity* = ref object of Entity
    scene*: EntityIdOf[Scene]

  
  Scene* = ref object of Entity
    initialFrameEntities*: seq[EntityIdOf[FrameEntity]]
    currentFrameEntities*: seq[EntityIdOf[FrameEntity]]
    sceneEntities*: seq[EntityIdOf[SceneEntity]]


  Animation* = ref object of SceneEntity
    animationObject*: EntityIdOf[FrameEntity]
    startTime*: Duration
    endTime*: Duration


  SiguiEntityKind* = enum
    emptyUiobj
    rect


  SiguiEntity* = ref object of BoxEntity
    kind*: SiguiEntityKind
    uiObj*: UiObj
    bindings*: EventHandler
    
    color*: Col
    opacity*: float32
  

  FloatKeyframePropertyKind* = enum
    x, y, w, h
    opacity


  ColorKeyframePropertyKind* = enum
    color


  Keyframes*[T, Enum] = object
    kind: Enum
    keyframes: seq[Keyframe[T]]

  
  KeyframeAnimation* = ref object of Animation
    floatKeyframes: seq[Keyframes[float32, FloatKeyframePropertyKind]]
    colorKeyframes: seq[Keyframes[chroma.Color, ColorKeyframePropertyKind]]


  SceneView* = ref object of UiObj
    database*: Database
    scene*: EntityIdOf[Scene]


registerComponent SceneView



# --- FrameEntity ---

registerEntityType "animaui/editor/scene", FrameEntity

proc version*(this: type FrameEntity): int {.inline.} = 1

method draw*(this: FrameEntity, ctx: EntityDrawContext) {.base, animaui_api.} =
  discard


method transformBy*(this: FrameEntity, m: Mat4) {.base, animaui_api.} =
  discard


method serialize*(this: FrameEntity, s: var string): SerializeStatus {.animaui_api.} =
  if (let status = procCall this.super.serialize(s); status != sOk): return status
  
  this.typeof.version.serializeData(s)
  
  this.scene.serializeData(s)
  this.role.serializeData(s)
  this.pair.serializeData(s)


method deserialize*(this: FrameEntity, s: string, i: var int): DeserializeStatus {.animaui_api.} =
  if (let status = procCall this.super.deserialize(s, i); status != sOk): return status
  
  var version: int
  version.deserializeData(s, i)
  if version > this.typeof.version: return sGreaterVersion
  
  this.scene.deserializeData(s, i)
  this.role.deserializeData(s, i)
  this.pair.deserializeData(s, i)



# --- SceneEntity ---

registerEntityType "animaui/editor/scene", SceneEntity

proc version*(this: type SceneEntity): int {.inline.} = 1



# --- Animation ---

registerEntityType "animaui/editor/scene", Animation

proc version*(this: type Animation): int {.inline.} = 1

method serialize*(this: Animation, s: var string): SerializeStatus {.animaui_api.} =
  if (let status = procCall this.super.serialize(s); status != sOk): return status

  this.typeof.version.serializeData(s)

  this.animationObject.serializeData(s)
  this.startTime.serializeData(s)
  this.endTime.serializeData(s)


method deserialize*(this: Animation, s: string, i: var int): DeserializeStatus {.animaui_api.} =
  if (let status = procCall this.super.deserialize(s, i); status != sOk): return status

  var version: int
  version.deserializeData(s, i)
  if version > this.typeof.version: return sGreaterVersion

  this.animationObject.deserializeData(s, i)
  this.startTime.deserializeData(s, i)
  this.endTime.deserializeData(s, i)


method apply*(this: Animation, time: Duration) {.base, animaui_api.} = discard
  ## applies animation to `current` pair of animation object
  ## for implementors: don't emit changed for animation object, scene will do it



# --- Scene ---

registerEntityType "animaui/editor/scene", Scene

proc version*(this: type Scene): int {.inline.} = 1

method serialize*(this: Scene, s: var string): SerializeStatus {.animaui_api.} =
  if (let status = procCall this.super.serialize(s); status != sOk): return status

  this.typeof.version.serializeData(s)

  this.initialFrameEntities.serializeData(s)
  this.currentFrameEntities.serializeData(s)
  this.sceneEntities.serializeData(s)


method deserialize*(this: Scene, s: string, i: var int): DeserializeStatus {.animaui_api.} =
  if (let status = procCall this.super.deserialize(s, i); status != sOk): return status

  var version: int
  version.deserializeData(s, i)
  if version > this.typeof.version: return sGreaterVersion

  this.initialFrameEntities.deserializeData(s, i)
  this.currentFrameEntities.deserializeData(s, i)
  this.sceneEntities.deserializeData(s, i)


proc add*(this: Scene, entity: SceneEntity) =
  defer: this.changed.emit(this)
  this.sceneEntities.add entity.typedId


proc add*(this: Scene, entity: FrameEntity) =
  defer: this.changed.emit(this)
  doassert entity.role == FrameEntityRole.initial

  this.initialFrameEntities.add entity.typedId
  
  let pair = entity.clone
  this.database.add pair

  pair.role = FrameEntityRole.current
  
  pair.pair = entity.typedId
  entity.pair = pair.typedId

  this.currentFrameEntities.add pair.typedId


iterator animations*(this: Scene): Animation =
  for entity_id in this.sceneEntities:
    let entity = this.database[entity_id]
    if entity of Animation:
      yield Animation(entity)


proc `currentTime=`*(this: Scene, time: Duration) =
  for currentFe_id in this.currentFrameEntities:
    let currentFe = this.database[currentFe_id]
    let pair = this.database[currentFe.pair]
    
    pair.copyInto(currentFe)
    currentFe.pair = pair.typedId
    currentFe.role = FrameEntityRole.current

  for animation in this.animations:
    if time < animation.startTime or time > animation.endTime: continue
    animation.apply(time)

    let cfe = this.database[this.database[animation.animationObject].pair]
    cfe.changed.emit(cfe)



# --- BoxEntity ---

registerEntityType "animaui/editor/scene", BoxEntity

proc version*(this: type BoxEntity): int {.inline.} = 1

method serialize*(this: BoxEntity, s: var string): SerializeStatus {.animaui_api.} =
  if (let status = procCall this.super.serialize(s); status != sOk): return status

  this.typeof.version.serializeData(s)

  this.pos.serializeData(s)
  this.size.serializeData(s)


method deserialize*(this: BoxEntity, s: string, i: var int): DeserializeStatus {.animaui_api.} =
  if (let status = procCall this.super.deserialize(s, i); status != sOk): return status

  var version: int
  version.deserializeData(s, i)
  if version > this.typeof.version: return sGreaterVersion

  this.pos.deserializeData(s, i)
  this.size.deserializeData(s, i)



# --- SiguiEntity ---

registerEntityType "animaui/editor/scene", SiguiEntity

proc version*(this: type SiguiEntity): int {.inline.} = 1

method serialize*(this: SiguiEntity, s: var string): SerializeStatus {.animaui_api.} =
  if (let status = procCall this.super.serialize(s); status != sOk): return status

  this.typeof.version.serializeData(s)

  this.kind.serializeData(s)


proc setKind*(this: SiguiEntity, kind: SiguiEntityKind) =
  disconnect this.bindings
  delete this.uiObj

  this.kind = kind

  case this.kind
  of SiguiEntityKind.emptyUiobj:
    this.uiObj = UiObj()
  of SiguiEntityKind.rect:
    this.uiObj = UiRect()
  
  this.uiObj.initIfNeeded()

  proc updateUiObj(this: Entity) =
    let this = SiguiEntity(this)

    this.uiObj.x[] = this.pos.x
    this.uiObj.y[] = this.pos.y
    this.uiObj.w[] = this.size.x
    this.uiObj.h[] = this.size.y
    
    case this.kind
    of SiguiEntityKind.emptyUiobj:
      discard
    of SiguiEntityKind.rect:
      this.uiObj.UiRect.color[] = this.color * this.opacity
  
  updateUiObj(this)
  this.changed.connect this.bindings, updateUiObj



method deserialize*(this: SiguiEntity, s: string, i: var int): DeserializeStatus {.animaui_api.} =
  if (let status = procCall this.super.deserialize(s, i); status != sOk): return status

  var version: int
  version.deserializeData(s, i)
  if version > this.typeof.version: return sGreaterVersion

  this.kind.deserializeData(s, i)
  {.cast(gcsafe).}:
    this.setKind(this.kind)


method onDestroy*(this: SiguiEntity) {.animaui_api.} =
  procCall this.super.onDestroy()

  disconnect this.bindings
  delete this.uiObj


method draw*(this: SiguiEntity, ctx: EntityDrawContext) {.animaui_api.} =
  this.uiObj.draw(ctx.siguiCtx)



# --- KeyframeAnimation ---

registerEntityType "animaui/editor/scene", KeyframeAnimation

proc version*(this: type KeyframeAnimation): int {.inline.} = 1

method serialize*(this: KeyframeAnimation, s: var string): SerializeStatus {.animaui_api.} =
  if (let status = procCall this.super.serialize(s); status != sOk): return status

  this.typeof.version.serializeData(s)

  this.floatKeyframes.serializeData(s)
  this.colorKeyframes.serializeData(s)


method deserialize*(this: KeyframeAnimation, s: string, i: var int): DeserializeStatus {.animaui_api.} =
  if (let status = procCall this.super.deserialize(s, i); status != sOk): return status

  var version: int
  version.deserializeData(s, i)
  if version > this.typeof.version: return sGreaterVersion

  this.floatKeyframes.deserializeData(s, i)
  this.colorKeyframes.deserializeData(s, i)


method apply*(this: KeyframeAnimation, time: Duration) {.animaui_api.} =
  let target = this.database[this.database[this.animationObject].pair.asTyped(SiguiEntity)]
  var hadChanges = false

  for kf in this.floatKeyframes:
    if kf.keyframes.len != 0:
      hadChanges = true
      case kf.kind
      of x: target.pos.x = kf.keyframes.getValueAtTime(time)
      of y: target.pos.y = kf.keyframes.getValueAtTime(time)
      of w: target.size.x = kf.keyframes.getValueAtTime(time)
      of h: target.size.y = kf.keyframes.getValueAtTime(time)
      of opacity: target.opacity = kf.keyframes.getValueAtTime(time)

  for kf in this.colorKeyframes:
    if kf.keyframes.len != 0:
      hadChanges = true
      case kf.kind
      of color: target.color = kf.keyframes.getValueAtTime(time)

  if hadChanges:
    target.changed.emit(target)



proc sceneToPx*(xy: Vec2, scene: SceneView): Vec2 =
  let ptSize = min(scene.w[], scene.h[]) / 50
  return xy * ptSize

proc pxToScene*(xy: Vec2, scene: SceneView): Vec2 =
  let ptSize = min(scene.w[], scene.h[]) / 50
  return xy / ptSize


method draw*(this: SceneView, ctx: DrawContext) =
  this.drawBefore(ctx)
  
  if this.visibility[] == visible:
    let scene = this.database[this.scene]

    let animauiCtx = EntityDrawContext(
      database: this.database,
      scene: scene,
      sceneView: this,
      siguiCtx: ctx
    )
    
    for cfe in scene.currentFrameEntities:
      this.database[cfe].draw(animauiCtx)
  
  this.drawAfter(ctx)


proc render*(scene: SceneView, resolution: Vec2, outfile: string, fps: int, fromTime, toTime: Duration) =
  let prevParent = scene.parent
  let prevXy = scene.xy
  let prevWh = scene.wh

  defer:
    scene.parent = prevParent
    scene.xy = prevXy
    scene.wh = prevWh

  scene.parent = nil

  let renderarea = ClipRect()
  renderarea.makeLayout:
    wh = resolution
    - UiRect.new:
      this.fill parent
      color = "202020"

    - scene:
      this.xy = vec2(0, 0)
      this.w[] = resolution.x
      this.h[] = resolution.y

  var frame = 0
  var time = fromTime
  var img = imageman.initImage[imageman.ColorRGBAU](resolution.x.int, resolution.y.int)

  var imagepaths: seq[string]
  # avdevice_register_all()

  # var format_context: ptr AVFormatContext
  # doassert avformat_alloc_output_context2(format_context.addr, nil, nil, outfile) == 0

  # let codec = avcodec_find_encoder(AV_CODEC_ID_H264)
  # doassert codec != nil
  # let stream = avformat_new_stream(format_context, codec)
  # doassert stream != nil
  # stream.id = cint format_context.nb_streams - 1

  # let codec_context = avcodec_alloc_context3(codec)
  # doassert codec_context != nil

  # codec_context.codec_id = format_context.oformat.video_codec
  # codec_context.bit_rate = 400000
  # codec_context.width = width
  # codec_context.height = height
  # stream.time_base = av_d2q(1 / fps, 120)
  # codec_context.time_base = stream.time_base
  # codec_context.pix_fmt = AV_PIX_FMT_YUV420P
  # codec_context.gop_size = 12
  # codec_context.max_b_frames = 2

  # if (format_context.oformat.flags and AVFMT_GLOBALHEADER) == AVFMT_GLOBALHEADER:
  #   codec_context.flags = codec_context.flags or AV_CODEC_FLAG_GLOBAL_HEADER
  
  # doassert avcodec_open2(codec_context, codec, nil) == 0

  # let ffmpeg_frame = av_frame_alloc()
  # doassert ffmpeg_frame != nil
  # ffmpeg_frame.format = cint codec_context.pix_fmt
  # ffmpeg_frame.width = codec_context.width
  # ffmpeg_frame.height = codec_context.height

  # doassert av_frame_get_buffer(ffmpeg_frame, 32) == 0

  # codec_context.extradata = cast[ptr uint8](alloc0(uint8.sizeof))
  # doassert avcodec_parameters_from_context(stream.codecpar, codec_context) == 0
  
  # let sws_context = sws_getContext(
  #   codec_context.width, codec_context.height, AV_PIX_FMT_RGBA,  # src
  #   codec_context.width, codec_context.height, AV_PIX_FMT_YUV420P,  # dest
  #   SWS_BILINEAR, nil, nil, nil
  # )
  # doassert sws_context != nil

  # av_dump_format(format_context, 0, outfile, 1)
  # doassert avio_open(format_context.pb.addr, outfile, AVIO_FLAG_WRITE) == 0
  # doassert avformat_write_header(format_context, nil) == 0

  if dirExists("/tmp/animaui"):
    removeDir "/tmp/animaui"
  createDir "/tmp/animaui"

  var progressbar = initSuruBar(1)
  progressbar[0].total = int (toTime - fromTime).inMicroseconds / 1_000_000 * fps.float
  setup progressbar

  while time < toTime:
    defer:
      inc frame
      inc progressbar
      update progressbar
      time += initDuration(seconds=1) div fps

    if frame mod 8 == 0:  ## todo: make better
      echo time

    scene.database[scene.scene].currentTime = time
    
    renderarea.draw(prevParent.parentUiWindow.ctx)

    renderarea.getPixels(img.data)
    flipVert img

    savePng(img, "/tmp/animaui/" & $frame & ".png", compression = 5)
    imagepaths.add("file /tmp/animaui/" & $frame & ".png")

    # doassert av_frame_make_writable(ffmpeg_frame) >= 0
    # var linesize = codec_context.width * 4
    # var data = cast[ptr uint8](img.data[0].addr)
    # discard sws_scale(sws_context, data.addr, linesize.addr, 0, codec_context.height, ffmpeg_frame.data[0].addr, ffmpeg_frame.linesize[0].addr)
    # ffmpeg_frame.pts = frame
    
    # doassert avcodec_send_frame(codec_context, ffmpeg_frame) >= 0
    # var packet: AVPacket
    # doassert avcodec_receive_packet(codec_context, packet.addr) >= 0
    
    # # av_packet_rescale_ts(packet.addr, codec_context.time_base, stream.time_base)
    # packet.stream_index = stream.index
    
    # doassert av_interleaved_write_frame(format_context, packet.addr) >= 0
    # av_packet_unref(packet.addr)
  
  finish progressbar

  writeFile "/tmp/animaui/images.txt", imagepaths.join("\n")

  discard execShellCmd &"ffmpeg -hide_banner -loglevel panic -r {fps} -f concat -safe 0 -i /tmp/animaui/images.txt -c:v libx264 -pix_fmt yuv420p {outfile}"

  removeDir "/tmp/animaui"

