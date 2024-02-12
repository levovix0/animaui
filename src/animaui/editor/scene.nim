import times, os, strutils, strformat
import sigui/[uibase, animations], imageman
import ./[keyframes, screenRecording]

type
  SceneObjectKind* = enum
    none
    rect

  Scene* = ref object of UiObj


  SceneObject* = ref object of Uiobj
    internalObject*: Uiobj
    kind*: Property[SceneObjectKind]
    selected*: Property[bool]

    color*: Property[chroma.Color]
    opacity*: Property[float32]

    xKeyframes*: seq[Keyframe[float32]]
    yKeyframes*: seq[Keyframe[float32]]
    wKeyframes*: seq[Keyframe[float32]]
    hKeyframes*: seq[Keyframe[float32]]
    colorKeyframes*: seq[Keyframe[chroma.Color]]
    opacityKeyframes*: seq[Keyframe[float32]]

registerComponent Scene
registerComponent SceneObject


proc setTime*(this: SceneObject, time: Duration) =
  if this.xKeyframes.len != 0:
    this.x[] = this.xKeyframes.getValueAtTime(time)
  if this.yKeyframes.len != 0:
    this.y[] = this.yKeyframes.getValueAtTime(time)
  if this.wKeyframes.len != 0:
    this.w[] = this.wKeyframes.getValueAtTime(time)
  if this.hKeyframes.len != 0:
    this.h[] = this.hKeyframes.getValueAtTime(time)
  if this.colorKeyframes.len != 0:
    this.color[] = this.colorKeyframes.getValueAtTime(time)
  if this.opacityKeyframes.len != 0:
    this.opacity[] = this.opacityKeyframes.getValueAtTime(time)


proc setTime*(this: Scene, time: Duration) =
  proc rec(this: UiObj) =
    if this of SceneObject:
      this.SceneObject.setTime(time)
    for x in this.childs:
      rec x

  rec this


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


  this.kind.changed.connectTo this, kind:
    if kind == none:
      this.internalObject = nil
      return

    let internalObjectKind =
      if this.internalObject == nil: SceneObjectKind.none
      elif this.internalObject of UiRect: SceneObjectKind.rect
      else: SceneObjectKind.none

    if internalObjectKind == kind: return

    this.internalObject = case kind
      of none: nil.UiObj
      of rect: UiRect()
    
    this.internalObject.parent = this.parentScene
    init this.internalObject
    
    case kind
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
      this.internalObject.xy[] = r.xy
      this.internalObject.wh[] = r.wh
  this.parentScene.h.changed.connectTo this, h:
    let r = this.queryRect
    if this.internalObject != nil:
      this.internalObject.xy[] = r.xy
      this.internalObject.wh[] = r.wh

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
  let prevXy = scene.xy[]
  let prevWh = scene.wh[]

  defer:
    scene.parent = prevParent
    scene.xy[] = prevXy
    scene.wh[] = prevWh

  scene.parent = nil

  let renderarea = ClipRect()
  renderarea.makeLayout:
    wh = resolution
    - UiRect():
      this.fill parent
      color = "202020"

    - scene:
      this.xy[] = vec2(0, 0)
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

  while time < toTime:
    defer:
      inc frame
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

  writeFile "/tmp/animaui/images.txt", imagepaths.join("\n")

  discard execShellCmd &"ffmpeg -hide_banner -loglevel panic -r {fps} -f concat -safe 0 -i /tmp/animaui/images.txt -c:v libx264 -pix_fmt yuv420p {outfile}"

  removeDir "/tmp/animaui"
