import siwin
import sigui/[uibase]
import pkg/[vmath]

type
  DecoratedWindow* = ref object of UiWindow
    borderWidth*: Property[float32] = 10'f32.property
    borderRadius*: Property[float32] = 7.5'f32.property
    minSize*: Property[IVec2] = ivec2(540, 320).property
    backgroundColor*: Property[Color] = "202020".litToColor.static.property
    titleHeight*: Property[float32]

    currentBorderWidth: Property[float32]

registerComponent DecoratedWindow


method recieve*(this: DecoratedWindow, signal: Signal) =
  procCall this.super.recieve(signal)

  if signal of WindowEvent and signal.WindowEvent.event of StateBoolChangedEvent:
    let e = (ref StateBoolChangedEvent)signal.WindowEvent.event
    if e.kind == maximized:
      if e.value:
        this.currentBorderWidth[] = 0
      else:
        this.currentBorderWidth[] = this.borderWidth[]


method init*(this: DecoratedWindow) =
  procCall this.super.init()

  this.binding currentBorderWidth:
    if this.siwinWindow.maximized: 0'f32
    else: this.borderWidth[]

  this.makeLayout:
    this.bindingValue this.siwinWindow.minSize: root.minSize[]

    - RectShadow():
      this.fill(parent)
      radius := root.borderRadius[]
      blurRadius := root.currentBorderWidth[]
      color = color(0, 0, 0, 0.3)

      - ClipRect():
        this.fill(parent, root.currentBorderWidth[])
        on root.currentBorderWidth.changed:
          this.fill(parent, root.currentBorderWidth[])

        radius := root.borderRadius[]

        proc updateSiwinWindowRegions =
          if this.w[] <= 0 or this.h[] <= 0: return
          root.siwinWindow.setInputRegion(this.xy, this.wh)
          root.siwinWindow.setBorderWidth(1, root.currentBorderWidth[], (root.currentBorderWidth[] * 2).max(10))
          root.siwinWindow.setTitleRegion(this.xy, vec2(this.w[], root.titleHeight[]))
        
        on this.w.changed:
          updateSiwinWindowRegions()
        on this.h.changed:
          updateSiwinWindowRegions()
        on root.currentBorderWidth.changed:
          updateSiwinWindowRegions()
        on root.titleHeight.changed:
          updateSiwinWindowRegions()
        
        - UiRect():
          this.fill(parent)
          color := root.backgroundColor[]

          root.newChildsObject = this


proc newDecoratedWindow*(siwinWindow: Window): DecoratedWindow =
  new result
  result.siwinWindow = siwinWindow
  loadExtensions()
  result.setupEventsHandling()
  result.ctx = newDrawContext()
  init result
