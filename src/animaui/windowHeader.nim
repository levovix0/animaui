import std/[options, strutils, macros]
import pkg/[chroma, pixie, siwin]
import pkg/sigui/[uibase, mouseArea]

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


proc newButton*(parent: Uiobj, icon: string): Button =
  result = Button()
  initIfNeeded(result)
  result.parent = parent  # workaroud

  result.makeLayout:
    wh = vec2(50, 40)

    - newMouseArea() as mouse:
      this.fill parent
      globalY = 10  # workaround

      this.mouseDownAndUpInside.connectTo root:
        root.action()

    - UiImage.new as ico:
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
  
  result.parent = nil  # workaroud


method init*(this: WindowHeader) =
  procCall this.super.init()

  this.makeLayout:
    color = c"30"

    - MouseArea.new:
      this.fill parent

      on this.grabbed[] == true:
        root.parentWindow.startInteractiveMove(some this.pressWindowPos)
      
      this.clicked.connectTo root:
        if e.double:
          e.window.maximized = not e.window.maximized

      - this.newButton(static(staticRead "../icons/title/close.svg")) as close:
        this.right = parent.right
        this.accent[] = true
        this.action = proc =
          close this.parentWindow
      
      - this.newButton(static(staticRead "../icons/title/maximize.svg")) as maximize:
        this.right = close.left
        this.action = proc =
          let win = this.parentWindow
          win.maximized = not win.maximized
      
      - this.newButton(static(staticRead "../icons/title/minimize.svg")) as minimize:
        this.right = maximize.left
        this.action = proc =
          this.parentWindow.minimized = true

