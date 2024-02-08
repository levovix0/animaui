import sigui/[uibase, mouseArea, layouts], siwin
import ../utils

type
  ToolKind* = enum
    arrow
    rect

  ToolbarTool* = ref object of UiRect
    selected*: Property[bool]
    clicked*: Event[void]
  
  Toolbar* = ref object of UiRect
    currentTool*: Property[ToolKind]


const arrowIcon = staticRead "../../icons/toolbox/arrow.svg"
const rectIcon = staticRead "../../icons/toolbox/rect.svg"


proc newToolbarTool(icon: string): ToolbarTool =
  new result
  result.makeLayout:
    this.binding color:
      if mouse.pressed[] or root.selected[]: "202020"
      elif mouse.hovered[]: "383838"
      else: "303030"

    - UiSvgImage():
      this.centerIn parent
      this.image[] = icon
      this.color[] = "fff"
    
    - MouseArea() as mouse:
      this.fill parent

      this.mouseDownAndUpInside.connectTo root: root.clicked.emit()


method init*(this: Toolbar) =
  if this.initialized: return
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
