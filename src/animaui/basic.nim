import times, strutils, os, macros, imageman
import sigui/[uibase, animations], siwin, fusion/matching
export uibase, animations
when not defined(preview):
  import strformat
  import screenRecording

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

proc `()`*(typeface: Typeface, size: float): Font =
  result = newFont(typeface)
  result.size = size


converter toColor*(s: string): chroma.Color =
  case s.len
  of 3:
    result = chroma.Color(
      r: ($s[0]).parseHexInt.float32 / 15.0,
      g: ($s[1]).parseHexInt.float32 / 15.0,
      b: ($s[2]).parseHexInt.float32 / 15.0,
      a: 1,
    )
  of 4:
    result = chroma.Color(
      r: ($s[0]).parseHexInt.float32 / 15.0,
      g: ($s[1]).parseHexInt.float32 / 15.0,
      b: ($s[2]).parseHexInt.float32 / 15.0,
      a: ($s[3]).parseHexInt.float32 / 15.0,
    )
  of 6:
    result = chroma.Color(
      r: (s[0..1].parseHexInt.float32) / 255.0,
      g: (s[2..3].parseHexInt.float32) / 255.0,
      b: (s[4..5].parseHexInt.float32) / 255.0,
      a: 1,
    )
  of 8:
    result = chroma.Color(
      r: (s[0..1].parseHexInt.float32) / 255.0,
      g: (s[2..3].parseHexInt.float32) / 255.0,
      b: (s[4..5].parseHexInt.float32) / 255.0,
      a: (s[6..7].parseHexInt.float32) / 255.0,
    )
  else:
    raise ValueError.newException("invalid color: " & s)


let win = 
  when defined(preview): 
    newOpenglWindow(size = ivec2(width, height)).newUiWindow
  else:
    newOpenglContext().newUiWindow


var this* = ClipRect()
this.wh[] = vec2(width.float, height.float)

var timepoint*: Duration


var timeactions*: seq[(Duration, proc())]


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
      a.interpolation[] = outSquareInterpolation
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
      a.interpolation[] = outSquareInterpolation
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
      a.interpolation[] = outSquareInterpolation
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
  win.addChild this
  init this

  when not defined(preview):
    var frame = 0
    var time: Duration
    var img = imageman.initImage[imageman.ColorRGBAU](width, height)

    var imagepaths: seq[string]

    if dirExists("/tmp/animaui"):
      removeDir "/tmp/animaui"
    createDir "/tmp/animaui"

    while not finished:
      defer:
        inc frame
        time += initDuration(seconds=1) div fps

      if frame mod 8 == 0:
        echo time

      block:
        var i = 0
        while i < timeactions.len:
          if timeactions[i][0] <= time:
            timeactions[i][1]()
            timeactions.del i
          else:
            inc i
      
      win.draw(win.ctx)

      this.getPixels(img.data)
      flipVert img

      savePng(img, "/tmp/animaui/" & $frame & ".png")
      imagepaths.add("file /tmp/animaui/" & $frame & ".png")

      win.onTick.emit(TickEvent(window: win.siwinWindow, deltaTime: initDuration(seconds=1) div fps))

    writeFile "/tmp/animaui/images.txt", imagepaths.join("\n")

    discard execShellCmd &"ffmpeg  -hide_banner -loglevel panic -r {fps} -f concat -safe 0 -i /tmp/animaui/images.txt -c:v libx264 -pix_fmt yuv420p {outfile}"

    removeDir "/tmp/animaui"
  
  else:
    var frame = 0
    var time: Duration

    win.onTick.connectTo win, val:
      inc frame
      time += val.deltaTime

      block:
        var i = 0
        while i < timeactions.len:
          if timeactions[i][0] <= time:
            timeactions[i][1]()
            timeactions.del i
          else:
            inc i

      redraw win

    run win.siwinWindow

