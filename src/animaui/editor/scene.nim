import times
import sigui/[uibase, animations]
import ./keyframes

type
  SceneObjectKind* = enum
    none
    rect

  Scene* = ref object of UiObj


  SceneObject* = ref object of Uiobj
    internalObject*: Uiobj
    kind*: Property[SceneObjectKind]
    selected*: Property[bool]

    color*: Property[Color]

    xKeyframes*: seq[Keyframe[float32]]
    yKeyframes*: seq[Keyframe[float32]]
    wKeyframes*: seq[Keyframe[float32]]
    hKeyframes*: seq[Keyframe[float32]]
    colorKeyframes*: seq[Keyframe[Color]]


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


proc setTime*(this: Scene, time: Duration) =
  proc rec(this: UiObj) =
    if this of SceneObject:
      this.SceneObject.setTime(time)
    for x in this.childs:
      rec x

  rec this


method init*(this: SceneObject) =
  if this.initialized: return
  procCall this.super.init()

  proc parentScene(this: SceneObject): Scene =
    var x = this.parent
    while x != nil:
      if x of Scene: return Scene(x)
      x = x.parent

  proc queryRect(this: SceneObject): Rect =
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
      this.internalObject.UiRect.color[] = this.color[]
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
        this.internalObject.UiRect.color[] = color
      else: discard


method draw*(this: SceneObject, ctx: DrawContext) =
  this.drawBefore(ctx)
  if this.visibility[] == visible:
    draw(this.internalObject, ctx)
  this.drawAfter(ctx)
