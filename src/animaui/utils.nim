import pixie
import sigui/[uiobj]

{.experimental: "callOperator".}


type
  DestroyLoggerInner = object
    message: string

  DestroyLogger* = ref object of Uiobj
    inner: DestroyLoggerInner


proc `=destroy`(x: DestroyLoggerInner) =
  if x.message != "":
    echo x.message


proc onDestroyLog*(msg: string): DestroyLogger =
  result = DestroyLogger()
  initIfNeeded(result)
  result.inner.message = msg


proc `()`*(typeface: Typeface, size: float): Font =
  result = newFont(typeface)
  result.size = size


proc fit*(image: Image, size: Vec2): Image =
  let size = size.ivec2
  let wmul = size.x / image.width
  let hmul = size.y / image.height
  if wmul < hmul:
    image.resize(int image.width.float * wmul, int image.height.float * wmul)
  else:
    image.resize(int image.width.float * hmul, int image.height.float * hmul)
