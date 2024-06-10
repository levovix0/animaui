import options, strutils, chroma, macros
import siwin, fusion/matching
import sigui/[uibase, mouseArea]

type
  Button = ref object of UiRect
    action: proc()
    icon: UiImage
    accent: Property[bool]

  WindowHeader* = ref object of UiRect

registerComponent Button
registerComponent WindowHeader


macro c(g: static string): Col =
  if g.len == 2: 
    let c = g.parseHexInt.byte
    newCall(bindSym"color", newCall(bindSym"rgbx", newLit c, newLit c, newLit c, newLit 255))
  else:
    let c = g.parseHtmlColor
    newCall(bindSym"color", newLit c.r, newLit c.g, newLit c.b, newLit c.a)


proc newButton*(icon: string): Button =
  result = Button()
  result.makeLayout:
    wh = vec2(50, 40)

    - newMouseArea() as mouse:
      this.fill parent

      this.mouseDownAndUpInside.connectTo root:
        root.action()

    - UiImage() as ico:
      colorOverlay = true
      image = icon.decodeImage
      this.centerIn parent
      root.icon = ico

      color = c"ff"
    
    this.binding color:
      if mouse.pressed[]:
        if this.accent[]: c"#C11B2D"
        else: c"36"
      elif mouse.hovered[]:
        if this.accent[]: c"#E03649"
        else: c"40"
      else:
        if this.accent[]: c"30"
        else: c"30"


proc newWindowHeader*(): WindowHeader =
  result = WindowHeader()
  result.makeLayout:
    this.binding color: c"30"

    - newMouseArea():
      this.fill parent

      this.grabbed.connectTo root:
        root.parentWindow.startInteractiveMove(some e)
      
      this.clicked.connectTo root:
        if e.double:
          e.window.maximized = not e.window.maximized

      - newButton(static(staticRead "../icons/title/close.svg")) as close:
        this.right = parent.right
        this.accent[] = true
        this.action = proc =
          close this.parentWindow
      
      - newButton(static(staticRead "../icons/title/maximize.svg")) as maximize:
        this.right = close.left
        this.action = proc =
          let win = this.parentWindow
          win.maximized = not win.maximized
      
      - newButton(static(staticRead "../icons/title/minimize.svg")) as minimize:
        this.right = maximize.left
        this.action = proc =
          this.parentWindow.minimized = true

