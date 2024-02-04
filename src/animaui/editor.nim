import algorithm, times, sequtils
import sigui/[uibase, mouseArea, globalShortcut, animations], siwin, cligen
import utils
import editor/[fonts, timeline, toolbar, keyframes, scene]


proc animaui =
  let win = newOpenglWindow().newUiWindow
  # var root = UiObj()
  # let win = createWindow(root)
  
  win.clearColor = "202020"

  let fonts = Fonts()
  fonts.firaCode = static(staticRead "../../fonts/FiraCode.ttf").parseTtf

  var selectedObject: Property[SceneObject]
 
  # root.makeLayout:
  win.makeLayout:
    # proc sceneToPx(xy: Vec2): Vec2 =
    #   let ptSize = min(scene.w[], scene.h[]) / 50
    #   return xy * ptSize
    
    proc pxToScene(xy: Vec2): Vec2 =
      let ptSize = min(scene.w[], scene.h[]) / 50
      return xy / ptSize


    proc keyframeForTime[T](keyframes: var seq[Keyframe[T]], value: T, time: Duration): var Keyframe[T] =
      if keyframes.len == 0:
        keyframes.add Keyframe[T](value: value, time: -(0.2's))

      for kf in keyframes.mitems:
        if kf.time.inMilliseconds == time.inMilliseconds:
          return kf
      
      keyframes.add Keyframe[T](time: time)
      return keyframes[^1]
    

    - Scene() as scene:
      this.left = toolbar.right
      this.right = parent.right
      this.top = parent.top
      this.bottom = timelinePanel.top

      timelinePanel.currentTime.changed.connectTo this, time:
        this.setTime(time)

    - MouseArea():  # arrow tool
      this.fill scene

      this.ignoreHandling[] = true

      var eh: EventHandler

      toolbar.currentTool.changed.connectTo this:
        disconnect eh
      selectedObject.changed.connectTo this:
        disconnect eh
        if selectedObject[] != nil:
          timelinePanel.actions[] = selectedObject[].xKeyframes.mapit(Keyframe[void](time: it.time, changeDuration: it.changeDuration))
        else:
          timelinePanel.actions[] = @[]

      this.pressed.changed.connectTo this, pressed:
        disconnect eh
        if not pressed: return

        if toolbar.currentTool[] != ToolKind.arrow: return
        let pos = vec2(this.mouseX[], this.mouseY[])
        let xy = pos.pxToScene
        proc findObjectAt(parent: UiObj, xy: Vec2): UiObj =
          for x in parent.childs.reversed:
            if not (x of SceneObject): continue
            let r = x.findObjectAt(xy - x.xy[])
            if r != nil: return r
            if xy.overlaps bumpy.rect(x.xy[], x.wh[]):
              return x
        let obj = scene.findObjectAt(xy)
        if obj == nil or obj.SceneObject.internalObject == nil:
          selectedObject[] = nil
        else:
          selectedObject[] = obj.SceneObject
      
      this.dragged.connectTo this, originw:
        if selectedObject[] == nil: return
        if toolbar.currentTool[] != ToolKind.arrow: return
        
        let obj = selectedObject[]
        let origin = posToObject(scene, obj, (originw - win.siwinWindow.pos).vec2.posToLocal(scene).pxToScene)
        proc updatePos() =
          let pos = posToObject(scene, obj.parent, vec2(this.mouseX[], this.mouseY[])).pxToScene - origin
          let time = timelinePanel.currentTime[]
          obj.xKeyframes.keyframeForTime(obj.x[], time).value = pos.x
          obj.yKeyframes.keyframeForTime(obj.y[], time).value = pos.y
          obj.xy[] = pos
          timelinePanel.actions[] = obj.xKeyframes.mapit(Keyframe[void](time: it.time, changeDuration: it.changeDuration))
        updatePos()
        this.mouseX.changed.connectTo eh: updatePos()
        this.mouseY.changed.connectTo eh: updatePos()
      
      - UiRectBorder():
        this.color[] = "f44"
        this.borderWidth[] = 2
        this.binding visibility:
          if toolbar.currentTool[] != ToolKind.arrow or (this.w[] == 0 and this.h[] == 0): Visibility.hiddenTree
          else: Visibility.visible
        
        selectedObject.changed.connectTo this, obj:
          if obj == nil or obj.internalObject == nil:
            this.left = Anchor()
            this.right = Anchor()
            this.top = Anchor()
            this.bottom = Anchor()
            this.xy[] = vec2()
            this.wh[] = vec2()
          else:
            this.fill(obj.internalObject, -2)


    - MouseArea():  # rect tool
      this.fill scene

      this.ignoreHandling[] = true

      var oldPos: Property[Vec2]
      this.pressed.changed.connectTo this, pressed:
        if pressed:
          oldPos[] = vec2(this.mouseX[], this.mouseY[])
        else:
          if toolbar.currentTool[] != ToolKind.rect: return
          let d = vec2(this.mouseX[], this.mouseY[])
          var r = bumpy.rect(oldPos.pxToScene, (d - oldPos).pxToScene)
          if r.w < 0:
            r.x = r.x + r.w
            r.w = -r.w
          if r.h < 0:
            r.y = r.y + r.h
            r.h = -r.h
          scene.makeLayout:
            - SceneObject():
              this.kind[] = rect
              this.color[] = "fff"

              this.x[] = r.x
              this.y[] = r.y
              this.w[] = r.w
              this.h[] = r.h
              
              redraw this

      - UiRect():
        this.binding x: oldPos[].x
        this.binding y: oldPos[].y
        this.binding w: parent.mouseX[] - oldPos[].x
        this.binding h: parent.mouseY[] - oldPos[].y

        this.binding visibility:
          if parent.pressed[] and toolbar.currentTool[] == ToolKind.rect: Visibility.visible
          else: Visibility.hidden

        this.color[] = "88f8"


    - globalShortcut({Key.del}):
      this.activated.connectTo this:
        if selectedObject[] != nil:
          selectedObject[].kind[] = none
          selectedObject[].parent[].childs.delete selectedObject[].parent[].childs.find(selectedObject[])
          selectedObject[] = nil
          redraw this


    - newTimelinePanel(fonts) as timelinePanel:
      this.fillHorizontal parent
      this.bottom = parent.bottom
      this.h[] = 150

      this.parentUiWindow.onTick.connectTo this, e:
        if timelinePanel.playing[]:
          timelinePanel.currentTime[] = timelinePanel.currentTime[] + e.deltaTime
          redraw this
    
    - Toolbar() as toolbar:
      this.top = parent.top
      this.bottom = timelinePanel.top
      this.left = parent.left
      this.w[] = 40

    # - newWindowHeader() as header:
    #   this.fillHorizontal parent
    #   this.h[] = 40


  run win.siwinWindow


when isMainModule:
  dispatch animaui
