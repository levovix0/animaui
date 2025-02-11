import sigui/[uibase, mouseArea, layouts], siwin

type
  ToolKind* = enum
    arrow
    rect
    frame
    text
    color
    opacity

  ToolbarTool* = ref object of UiRect
    selected*: Property[bool]
    clicked*: Event[void]
  
  Toolbar* = ref object of UiRect
    currentTool*: Property[ToolKind]

registerComponent Toolbar
registerComponent ToolbarTool


const arrowIcon = staticRead "../../icons/toolbar/arrow.svg"
const rectIcon = staticRead "../../icons/toolbar/rect.svg"
const opacityIcon = staticRead "../../icons/toolbar/opacity.svg"


proc newToolbarTool(icon: string): ToolbarTool =
  new result
  result.makeLayout:
    color = binding:
      if mouse.pressed[] or root.selected[]: "202020".toColor.static
      elif mouse.hovered[]: "383838".toColor.static
      else: "303030".toColor.static

    - UiSvgImage():
      this.centerIn parent
      image = icon
      color = "fff".toColor.static
    
    - MouseArea() as mouse:
      this.fill parent

      this.mouseDownAndUpInside.connectTo root: root.clicked.emit()


method init*(this: Toolbar) =
  procCall this.super.init()

  this.color[] = "303030"

  this.makeLayout:
    - Layout():
      this.fill parent
      this.spacing[] = 0
      this.orientation[] = vertical

      this.onSignal.connectTo this, signal:
        if not(signal of WindowEvent): return
        if not(signal.WindowEvent.event of (ref KeyEvent)): return
        let pressed = ((ref KeyEvent)signal.WindowEvent.event).pressed
        if ((ref KeyEvent)signal.WindowEvent.event).repeated: return
        let p = pressed

        case ((ref KeyEvent)signal.WindowEvent.event).key
        of Key.r:
          if p: root.currentTool[] = ToolKind.rect
          else: root.currentTool[] = ToolKind.arrow
        # of Key.t:
        #   if p: root.currentTool[] = ToolKind.text
        #   else: root.currentTool[] = ToolKind.arrow
        of Key.x:
          if p: root.currentTool[] = ToolKind.opacity
          else: root.currentTool[] = ToolKind.arrow
        else: discard

      - newToolbarTool(arrowIcon):
        this.binding w: parent.w[]
        this.binding h: this.w[]
        this.binding selected: root.currentTool[] == arrow
        this.clicked.connectTo this: root.currentTool[] = arrow

      - newToolbarTool(rectIcon):
        this.binding w: parent.w[]
        this.binding h: this.w[]
        this.binding selected: root.currentTool[] == rect
        this.clicked.connectTo this: root.currentTool[] = rect

      - newToolbarTool(opacityIcon):
        this.binding w: parent.w[]
        this.binding h: this.w[]
        this.binding selected: root.currentTool[] == opacity
        this.clicked.connectTo this: root.currentTool[] = opacity
