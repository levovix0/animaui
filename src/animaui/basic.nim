import std/[times, strutils, os, macros, threadpool]
import pkg/[imageman]
import sigui/[uibase, animations], siwin, fusion/matching
export uibase, animations
import utils
export utils
when not defined(preview):
  import strformat, sequtils
  import editor/screenRecording
  import std/importutils
  import suru
  # import ffmpeg
else:
  import math, strformat
  import sigui/[globalShortcut, mouseArea]

{.experimental: "callOperator".}

const width {.intdefine.} = 1280
const height {.intdefine.} = 720
const pxRatio {.strdefine.} = "1"
const fontDirectory {.strdefine.} = "fonts"
when not defined(preview):
  const fps {.intdefine.} = 60
  const outFile {.strdefine.} = "out.mp4"

var sceneWidth*: float = width  # in pixels
var sceneHeight*: float = height  # in pixels

var endTime*: Duration


proc w*(lit: float): float =
  lit * sceneWidth

proc h*(lit: float): float =
  lit * sceneHeight


proc lwh*(lit: float): float =
  lit * min(sceneWidth, sceneHeight)

proc gwh*(lit: float): float =
  lit * max(sceneWidth, sceneHeight)


var pixelRatio*: float = pxRatio.parseFloat
var ptRatio*: float = 0.03.lwh
var changeDuration*: Duration = 0.2's


proc px*(lit: float): float =
  lit * pixelRatio

proc pt*(lit: float): float =
  lit * ptRatio


proc useFont*(name: string): Typeface =
  parseTtf(readFile fontDirectory / name & ".ttf")


let win = 
  when defined(preview): 
    newOpenglWindow(size = ivec2(width, height)).newUiWindow
  else:
    newOpenglContext().newUiWindow


var this* = ClipRect()
this.wh[] = vec2(width.float, height.float)

var timepoint*: Duration


var timeactions*: seq[(Duration, proc())]


macro localTimepoint* =
  let tp = ident "timepoint"
  quote do:
    var `tp` = `tp`


macro byTime*(t, body: untyped): untyped =
  let tp = ident "timepoint"
  quote do:
    `tp` = `t`
    block:
      var `tp` {.used.} = `tp`
      timeactions.add (`tp`, proc() {.closure.} =
        `body`
      )


macro afterTime*(t, body: untyped): untyped =
  let tp = ident "timepoint"
  quote do:
    `tp` = `tp` + `t`
    block:
      var `tp` {.used.} = `tp`
      timeactions.add (`tp`, proc() {.closure.} =
        `body`
      )


macro addToScene*(body) =
  let this = bindSym "this"
  quote do:
    `this`.makeLayout(`body`)


macro change*(what, toVal: untyped): untyped =
  let changeDuration = ident "changeDuration"
  case what
  of BracketExpr[@what]:
    quote do:
      let a = Animation[typeof(`what`[])](
        action: (proc(x: typeof(`what`[])) =
          `what`[] = x
        ),
      )
      a.duration{} = `changeDuration`
      a.a{} = `what`[]
      a.b{} = `toVal`
      a.easing[] = outSquareEasing
      this.addChild a
      start a
  else:
    quote do:
      let a = Animation[typeof(`what`)](
        action: (proc(x: typeof(`what`)) =
          `what` = x
        ),
      )
      a.duration{} = `changeDuration`
      a.a{} = `what`
      a.b{} = `toVal`
      a.easing[] = outSquareEasing
      this.addChild a
      start a


proc appear*[T: UiObj](
  obj: T,
  slideUp: float = 0,
  slideDown: float = 0,
  slideLeft: float = 0,
  slideRight: float = 0,
  changeDuration = changeDuration,
) =
  template mkappear(slv, prop, equa: untyped) =
    if slv != 0:
      let prev {.inject.} = prop[]
      prop[] = equa(prev, slv)
      change prop[]: prev

  mkappear slideUp, obj.y, `+`
  mkappear slideDown, obj.y, `-`
  mkappear slideLeft, obj.x, `+`
  mkappear slideRight, obj.x, `-`

  var prevColor = obj.color[]
  var newColor = prevColor
  prevColor.a = 0
  newColor.a = 1
  obj.color[] = prevColor
  change obj.color[]: newColor


proc disappear*[T: UiObj](
  obj: T,
  slideUp: float = 0,
  slideDown: float = 0,
  slideLeft: float = 0,
  slideRight: float = 0,
  changeDuration = changeDuration,
) =
  template mkappear(slv, prop, equa: untyped) =
    if slv != 0:
      let prev = prop[]
      let a = Animation[float](
        action: (proc(x: float) =
          prop[] = x
        ),
      )
      a.duration{} = changeDuration
      a.a{} = prev
      a.b{} = equa(prev, slv)
      a.easing[] = outSquareEasing
      a.ended.connectTo obj:
        prop[] = prev
      this.addChild a
      start a

  mkappear slideUp, obj.y, `-`
  mkappear slideDown, obj.y, `+`
  mkappear slideLeft, obj.x, `-`
  mkappear slideRight, obj.x, `+`
  
  var prevColor = obj.color[]
  var newColor = prevColor
  prevColor.a = 1
  newColor.a = 0
  obj.color[] = prevColor
  change obj.color[]: newColor


var finished = false

proc finish*() =
  finished = true
  when defined(preview):
    close win.siwinWindow


proc render*() =
  when not defined(preview):
    win.addChild this
    init this

    var frame = 0
    var time: Duration
    var img = imageman.initImage[imageman.ColorRGBAU](width, height)

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

    privateAccess Window

    var progressbar = initSuruBar(1)
    progressbar[0].total = int endTime.inMicroseconds / 1_000_000 * fps
    setup progressbar

    while not finished:
      defer:
        inc frame
        inc progressbar
        update progressbar
        if endTime <= time: finished = true
        time += initDuration(seconds=1) div fps

      block:
        var i = 0
        while i < timeactions.len:
          if timeactions[i][0] <= time:
            timeactions[i][1]()
            redraw win
            timeactions.del i
          else:
            inc i
      
      if win.siwinWindow.redrawRequested or imagepaths.len == 0:
        win.draw(win.ctx)

        this.getPixels(img.data)
        flipVert img

        spawn savePng(img, "/tmp/animaui/" & $frame & ".png", compression = 5)

      else:
        copyFile(imagepaths[^1], "/tmp/animaui/" & $frame & ".png")
      
      imagepaths.add("/tmp/animaui/" & $frame & ".png")

      win.onTick.emit(TickEvent(window: win.siwinWindow, deltaTime: initDuration(seconds=1) div fps))

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

    writeFile "/tmp/animaui/images.txt", imagepaths.mapit("file " & it).join("\n")

    threadpool.sync()  # done saving .png images

    discard execShellCmd &"ffmpeg -hide_banner -loglevel panic -r {fps} -f concat -safe 0 -i /tmp/animaui/images.txt -c:v libx264 -pix_fmt yuv420p {outfile}"

    removeDir "/tmp/animaui"
  
  else:
    var frame = 0
    var time: Duration
    var paused = false.property
    var showSize = false.property

    let cr = this
    const play = staticRead "../icons/play.svg"
    const pause = staticRead "../icons/pause.svg"
    const font = staticRead "../fonts/FiraCode.ttf"
    let typeface = font.parseTtf

    win.makeLayout:
      - Animator() as animator:
        - cr

      win.onTick.connectTo win, val:
        if not paused[]:
          inc frame
          if endTime <= time: finish()
          time += val.deltaTime

          block:
            var i = 0
            while i < timeactions.len:
              if timeactions[i][0] <= time:
                timeactions[i][1]()
                timeactions.del i
              else:
                inc i

          animator.onTick.emit(val.deltaTime)
          redraw win
      
      - UiSvgImage():
        this.centerIn parent
        this.w[] = 4.pt
        this.h[] = 4.pt
        
        this.binding image:
          if paused[]: pause else: play

        this.color[] = "fff0"

        - Animation[chroma.Color]() as playpause_color_anim:
          this.easing[] = proc(x: float): float = 1 - (x * 2 - 1).pow(2)
          this.duration[] = changeDuration
          this.a[] = "fff0"
          this.b[] = "fffa"
          this.action = proc(x: chroma.Color) = parent.color[] = x

        - Animation[float]() as playpause_size_anim:
          this.easing[] = outSquareEasing
          this.duration[] = changeDuration
          this.a[] = 0
          this.b[] = 4.pt
          this.action = proc(x: float) = parent.wh[] = vec2(x, x)
      
      - MouseArea() as mouse:
        this.fill parent
        var oldPos = vec2()
        
        proc f =
          if not this.pressed[]: return
          var x = this.mouseX[]
          var y = this.mouseY[]
          var w = oldPos.x - x
          var h = oldPos.y - y

          if x > 0.5.w:
            shown_rect.right = Anchor()
            shown_rect.left = parent.left + 10.px
          else:
            shown_rect.left = Anchor()
            shown_rect.right = parent.right - 10.px
          
          if w < 0: w = -w; x = oldPos.x
          if h < 0: h = -h; y = oldPos.y

          shown_text.text[] =
            &"{x / 1.pt:.2f},  {y / 1.pt:.2f} [pt]" &
            (if w != 0 and h != 0: &"\n{w / 1.pt:.2f} x {h / 1.pt:.2f} [pt]" else: "")

          overlap_rect.xy[] = vec2(x, y)
          overlap_rect.wh[] = vec2(w, h)
          redraw win.siwinWindow

        this.mouseX.changed.connectTo this: f()
        this.mouseY.changed.connectTo this: f()
        this.pressed.changed.connectTo this, val:
          if not val: return
          oldPos = vec2(this.mouseX[], this.mouseY[])
          f()

      - UiRect() as overlap_rect:
        this.color[] = "88f8"
        this.radius[] = 5.px
        this.binding visibility:
          if mouse.pressed[] or showSize[]: Visibility.visible
          else: Visibility.hiddenTree

      - UiRect() as shown_rect:
        this.top = parent.top + 10.px
        this.left = parent.left + 10.px
        this.radius[] = 5.px
        this.binding w: shown_text.w[] + 20.px
        this.binding h: shown_text.h[] + 10.px
        this.binding visibility:
          if mouse.pressed[] or showSize[]: Visibility.visible
          else: Visibility.hiddenTree

        - UiText() as shown_text:
          this.color[] = "fff"
          this.centerIn parent
          this.font[] = typeface(1.pt)
      
      - globalShortcut {space}:
        this.activated.connectTo this:
          paused[] = not paused[]
          start playpause_color_anim
          start playpause_size_anim

      - globalShortcut {Key.escape}:
        this.activated.connectTo this:
          close win.siwinWindow

      - globalShortcut {Key.s}:
        this.activated.connectTo this:
          showSize[] = not showSize[]

      - globalShortcut {Key.right}:
        this.activated.connectTo this:
          time += 1's

    run win.siwinWindow

