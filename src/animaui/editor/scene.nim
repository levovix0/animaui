import std/[times, os, strutils, strformat]
import pkg/[imageman, suru]
import pkg/sigui/[uibase, animations]
import ./[keyframes, screenRecording, entities, exportutils]

type
  EntityDrawContext* = ref object of RootObj
    screenCoordinateSystem*: Mat4

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

    ecs*: Mat4 = mat4(1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1)
      ## internal coordinate system (a matrix that transforms a coordinate from internal space to world space)
    color*: Col
    opacity*: float32


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


  SiguiFrameEntityKind* = enum
    emptyUiobj
    rect


  SiguiFrameEntity* = ref object of FrameEntity
    kind*: SiguiFrameEntityKind
    uiObj*: UiObj
    prop_color*: Property[Col]
    prop_opacity*: Property[float32]

  
  KeyframeAnimation* = ref object of Animation
    xKeyframes*: seq[Keyframe[float32]]
    yKeyframes*: seq[Keyframe[float32]]
    wKeyframes*: seq[Keyframe[float32]]
    hKeyframes*: seq[Keyframe[float32]]
    colorKeyframes*: seq[Keyframe[chroma.Color]]
    opacityKeyframes*: seq[Keyframe[float32]]


  SceneView* = ref object of UiObj
    ## todo
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
  this.ecs.serializeData(s)
  this.color.serializeData(s)
  this.opacity.serializeData(s)


method deserialize*(this: FrameEntity, s: string, i: var int): DeserializeStatus {.animaui_api.} =
  if (let status = procCall this.super.deserialize(s, i); status != sOk): return status
  
  var version: int
  version.deserializeData(s, i)
  if version > this.typeof.version: return sGreaterVersion
  
  this.scene.deserializeData(s, i)
  this.role.deserializeData(s, i)
  this.pair.deserializeData(s, i)
  this.ecs.deserializeData(s, i)
  this.color.deserializeData(s, i)
  this.opacity.deserializeData(s, i)



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

  for animation in this.animations:
    if time < animation.startTime or time > animation.endTime: continue
    animation.apply(time)

    let cfe = this.database[this.database[animation.animationObject].pair]
    cfe.changed.emit(cfe)



# --- SiguiFrameEntity ---

registerEntityType "animaui/editor/scene", SiguiFrameEntity

proc version*(this: type SiguiFrameEntity): int {.inline.} = 1

method serialize*(this: SiguiFrameEntity, s: var string): SerializeStatus {.animaui_api.} =
  if (let status = procCall this.super.serialize(s); status != sOk): return status

  this.typeof.version.serializeData(s)

  this.kind.serializeData(s)

  this.uiObj.x[].serializeData(s)
  this.uiObj.y[].serializeData(s)
  this.uiObj.w[].serializeData(s)
  this.uiObj.h[].serializeData(s)


method deserialize*(this: SiguiFrameEntity, s: string, i: var int): DeserializeStatus {.animaui_api.} =
  if (let status = procCall this.super.deserialize(s, i); status != sOk): return status

  var version: int
  version.deserializeData(s, i)
  if version > this.typeof.version: return sGreaterVersion

  this.kind.deserializeData(s, i)

  case this.kind
  of SiguiFrameEntityKind.emptyUiobj:
    this.uiObj = UiObj()
  of SiguiFrameEntityKind.rect:
    this.uiObj = UiRect()
    this.uiObj.UiRect.binding color: this.prop_color[] * this.prop_opacity[]
  
  this.uiObj.initIfNeeded()

  this.uiObj.x{}.deserializeData(s, i)
  this.uiObj.y{}.deserializeData(s, i)
  this.uiObj.w{}.deserializeData(s, i)
  this.uiObj.h{}.deserializeData(s, i)

  this.uiObj.x.changed.emit()
  this.uiObj.y.changed.emit()
  this.uiObj.w.changed.emit()
  this.uiObj.h.changed.emit()


method onDestroy*(this: SiguiFrameEntity) {.animaui_api.} =
  procCall this.super.onDestroy()

  delete this.uiObj
  disconnect this.prop_color.changed
  disconnect this.prop_opacity.changed



# --- KeyframeAnimation ---

registerEntityType "animaui/editor/scene", KeyframeAnimation

proc version*(this: type KeyframeAnimation): int {.inline.} = 1

method serialize*(this: KeyframeAnimation, s: var string): SerializeStatus {.animaui_api.} =
  if (let status = procCall this.super.serialize(s); status != sOk): return status

  this.typeof.version.serializeData(s)

  this.xKeyframes.serializeData(s)
  this.yKeyframes.serializeData(s)
  this.wKeyframes.serializeData(s)
  this.hKeyframes.serializeData(s)
  this.colorKeyframes.serializeData(s)
  this.opacityKeyframes.serializeData(s)


method deserialize*(this: KeyframeAnimation, s: string, i: var int): DeserializeStatus {.animaui_api.} =
  if (let status = procCall this.super.deserialize(s, i); status != sOk): return status

  var version: int
  version.deserializeData(s, i)
  if version > this.typeof.version: return sGreaterVersion

  this.xKeyframes.deserializeData(s, i)
  this.yKeyframes.deserializeData(s, i)
  this.wKeyframes.deserializeData(s, i)
  this.hKeyframes.deserializeData(s, i)
  this.colorKeyframes.deserializeData(s, i)
  this.opacityKeyframes.deserializeData(s, i)


method apply*(this: KeyframeAnimation, time: Duration) {.animaui_api.} =
  let target = this.database[this.database[this.animationObject].pair.asTyped(SiguiFrameEntity)]

  if this.xKeyframes.len != 0:
    target.uiObj.x[] = this.xKeyframes.getValueAtTime(time)
  if this.yKeyframes.len != 0:
    target.uiObj.y[] = this.yKeyframes.getValueAtTime(time)
  if this.wKeyframes.len != 0:
    target.uiObj.w[] = this.wKeyframes.getValueAtTime(time)
  if this.hKeyframes.len != 0:
    target.uiObj.h[] = this.hKeyframes.getValueAtTime(time)
  if this.colorKeyframes.len != 0:
    target.prop_color[] = this.colorKeyframes.getValueAtTime(time)
  if this.opacityKeyframes.len != 0:
    target.prop_opacity[] = this.opacityKeyframes.getValueAtTime(time)


#[

proc pxToScene*(xy: Vec2, scene: Scene): Vec2 =
  let ptSize = min(scene.w[], scene.h[]) / 50
  return xy / ptSize


method init*(this: SceneObject) =
  procCall this.super.init()

  proc parentScene(this: SceneObject): Scene =
    var x = this.parent
    while x != nil:
      if x of Scene: return Scene(x)
      x = x.parent

  proc queryRect(this: SceneObject): bumpy.Rect =
    let scene = this.parentScene
    if scene == nil: return
    let ptSize = min(scene.w[], scene.h[]) / 50
    result.xy = vec2(this.x[], this.y[]).posToGlobal(this.parent).posToLocal(scene) * ptSize
    result.wh = vec2(this.w[], this.h[]) * ptSize


  this.kind.changed.connectTo this:
    if this.kind[] == none:
      this.internalObject = nil
      return

    let internalObjectKind =
      if this.internalObject == nil: SceneObjectKind.none
      elif this.internalObject of UiRect: SceneObjectKind.rect
      else: SceneObjectKind.none

    if internalObjectKind == this.kind[]: return

    this.internalObject = case this.kind[]
      of none: nil.UiObj
      of rect: UiRect()
    
    this.internalObject.parent = this.parentScene
    init this.internalObject
    
    case this.kind[]
    of rect:
      this.internalObject.UiRect.color[] = color(this.color[].r, this.color[].g, this.color[].b, this.opacity[])
    else: discard
  
  this.x.changed.connectTo this, x:
    let r = this.queryRect
    if this.internalObject != nil: this.internalObject.x[] = r.x
  this.y.changed.connectTo this, y:
    let r = this.queryRect
    if this.internalObject != nil: this.internalObject.y[] = r.y

  this.parentScene.w.changed.connectTo this, w:
    let r = this.queryRect
    if this.internalObject != nil:
      this.internalObject.xy = r.xy
      this.internalObject.wh = r.wh
  this.parentScene.h.changed.connectTo this, h:
    let r = this.queryRect
    if this.internalObject != nil:
      this.internalObject.xy = r.xy
      this.internalObject.wh = r.wh

  this.w.changed.connectTo this, w:
    let r = this.queryRect
    if this.internalObject != nil: this.internalObject.w[] = r.w
  this.h.changed.connectTo this, h:
    let r = this.queryRect
    if this.internalObject != nil: this.internalObject.h[] = r.h

  this.color.changed.connectTo this, color:
    if this.internalObject != nil:
      case this.kind[]
      of rect:
        this.internalObject.UiRect.color[] = color(this.color[].r, this.color[].g, this.color[].b, this.opacity[])
      else: discard

  this.opacity.changed.connectTo this, opacity:
    if this.internalObject != nil:
      case this.kind[]
      of rect:
        this.internalObject.UiRect.color[] = color(this.color[].r, this.color[].g, this.color[].b, this.opacity[])
      else: discard


method draw*(this: SceneObject, ctx: DrawContext) =
  this.drawBefore(ctx)
  if this.visibility[] == visible:
    draw(this.internalObject, ctx)
  this.drawAfter(ctx)


method recieve*(this: SceneObject, signal: Signal) =
  if this.internalObject != nil:
    this.internalObject.recieve(signal)


proc render*(scene: Scene, resolution: Vec2, outfile: string, fps: int, fromTime, toTime: Duration) =
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
    - UiRect():
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

    scene.setTime(time)
    
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

]#
