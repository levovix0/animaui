import algorithm, times, sequtils
import sigui/[uibase, mouseArea, globalShortcut, animations], siwin, cligen
import utils, window, windowHeader
import editor/[fonts, timeline, toolbar, keyframes, scene]


proc animaui =
  # let win = newOpenglWindow().newUiWindow
  var root = UiObj()
  let win = createWindow(root)

  # win.clearColor = "202020"

  let fonts = Fonts()
  fonts.firaCode = static(staticRead "../../fonts/FiraCode.ttf").parseTtf

  var selectedObject: Property[SceneObject]

  root.makeLayout:
  # win.makeLayout:
    proc sceneToPx(xy: Vec2): Vec2 =
      let ptSize = min(scene.w[], scene.h[]) / 50
      return xy * ptSize
    
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
    

    - UiRect() as scenearea:
      this.fill parent
      this.color[] = "101010"

      this.left = toolbar.right
      this.right = parent.right
      this.top = header.bottom
      this.bottom = timelinePanel.top

      - UiRect() as scenebg:
        this.fill scene
        this.color[] = "202020"

      - Scene() as scene:
        const aspectRatio = 16/9

        this.binding w:
          let r = parent.w[] / parent.h[]
          if r > aspectRatio:
            this.h[] * aspectRatio
          else:
            parent.w[]

        this.binding h:
          let r = parent.w[] / parent.h[]
          if r > aspectRatio:
            parent.h[]
          else:
            this.w[] / aspectRatio
        
        this.centerIn parent

        timelinePanel.currentTime.changed.connectTo this, time:
          this.setTime(time)
      
      # --- borders ---
      - UiRect():
        this.drawLayer = after scene
        this.top = parent.top
        this.bottom = scene.top
        this.fillHorizontal parent
        this.color[] = "10101080"
      
      - UiRect():
        this.drawLayer = after scene
        this.bottom = parent.bottom
        this.top = scene.bottom
        this.fillHorizontal parent
        this.color[] = "10101080"

      - UiRect():
        this.drawLayer = after scene
        this.left = parent.left
        this.right = scene.left
        this.fillVertical parent
        this.color[] = "10101080"
      
      - UiRect():
        this.drawLayer = after scene
        this.right = parent.right
        this.left = scene.right
        this.fillVertical parent
        this.color[] = "10101080"

    - MouseArea():  # arrow tool
      this.fill scenearea

      this.ignoreHandling[] = true

      this.binding visibility:
        if toolbar.currentTool[] == ToolKind.arrow: Visibility.visible
        else: Visibility.collapsed


      var eh: EventHandler      

      var horizontalSnapping = false.property
      var verticalSnapping = false.property


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
        horizontalSnapping[] = false
        verticalSnapping[] = false
        if not pressed: return

        if toolbar.currentTool[] != ToolKind.arrow: return
        let pos = vec2(this.mouseX[], this.mouseY[]).posToObject(this, scene)
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
      

      - UiRect() as shapVertical:
        this.fillHorizontal scenearea
        this.h[] = 1
        this.color[] = "fa0"
        
        proc updateVisibility =
          this.visibility[] =
            if (
              verticalSnapping[] and
              selectedObject[] != nil and
              parent.pressed[]
            ):
              Visibility.visible
            else: Visibility.hiddenTree
        
        updateVisibility()
        parent.pressed.changed.connectTo this: updateVisibility()
        selectedObject.changed.connectTo this: updateVisibility()
        verticalSnapping.changed.connectTo this: updateVisibility()
        
        proc updateY =
          this.y[] =
            if selectedObject[] == nil: 0'f32
            else: vec2(0, selectedObject[].y[] + selectedObject[].h[] / 2).posToObject(selectedObject[].parent, scene).sceneToPx.posToObject(scene, this.parent).y

        var eh: EventHandler
        selectedObject.changed.connectTo this:
          disconnect eh
          if selectedObject[] == nil: return
          updateY()
          selectedObject[].y.changed.connectTo eh: updateY()
          selectedObject[].h.changed.connectTo eh: updateY()
      

      - UiRect() as shapHorizontal:
        this.fillVertical scenearea
        this.w[] = 1
        this.color[] = "fa0"
        
        proc updateVisibility =
          this.visibility[] =
            if (
              horizontalSnapping[] and
              selectedObject[] != nil and
              parent.pressed[]
            ):
              Visibility.visible
            else: Visibility.hiddenTree
        
        updateVisibility()
        parent.pressed.changed.connectTo this: updateVisibility()
        selectedObject.changed.connectTo this: updateVisibility()
        horizontalSnapping.changed.connectTo this: updateVisibility()
        
        proc updateX =
          this.x[] =
            if selectedObject[] == nil: 0'f32
            else: vec2(selectedObject[].x[] + selectedObject[].w[] / 2, 0).posToObject(selectedObject[].parent, scene).sceneToPx.posToObject(scene, this.parent).x

        var eh: EventHandler
        selectedObject.changed.connectTo this:
          disconnect eh
          if selectedObject[] == nil: return
          updateX()
          selectedObject[].x.changed.connectTo eh: updateX()
          selectedObject[].w.changed.connectTo eh: updateX()


      this.grabbed.connectTo this, originw:
        if selectedObject[] == nil: return
        if toolbar.currentTool[] != ToolKind.arrow: return
        
        let obj = selectedObject[]
        let origin = posToObject(scene, obj, (originw - win.siwinWindow.pos).vec2.posToLocal(scene).pxToScene)
        let startPos = obj.xy[]

        proc updatePos() =
          var pos = vec2(this.mouseX[], this.mouseY[]).posToObject(this, scene).pxToScene - origin
          let time = timelinePanel.currentTime[]

          if Key.lshift in this.parentWindow.keyboard.pressed or Key.rshift in this.parentWindow.keyboard.pressed:
            # snapping
            if abs(pos.x - startPos.x) - (if horizontalSnapping[]: 10 else: 0) <= abs(pos.y - startPos.y) - (if verticalSnapping[]: 10 else: 0):
              pos.x = startPos.x
              horizontalSnapping[] = true
              verticalSnapping[] = false
            else:
              pos.y = startPos.y
              horizontalSnapping[] = false
              verticalSnapping[] = true
          else:
            let center = (scene.wh[] / 2).pxToScene
            if abs((pos + obj.wh[] / 2) - center).length < 3:
              # snap to center
              pos = center - obj.wh[] / 2
              horizontalSnapping[] = true
              verticalSnapping[] = true
            else:
              horizontalSnapping[] = false
              verticalSnapping[] = false
          
          obj.xKeyframes.keyframeForTime(obj.x[], time).value = pos.x
          obj.yKeyframes.keyframeForTime(obj.y[], time).value = pos.y
          obj.xy[] = pos
          timelinePanel.actions[] = obj.xKeyframes.mapit(Keyframe[void](time: it.time, changeDuration: it.changeDuration))
        
        updatePos()

        this.mouseX.changed.connectTo eh: updatePos()
        this.mouseY.changed.connectTo eh: updatePos()
        this.onSignal.connectTo eh, signal:
          if signal of WindowEvent and signal.WindowEvent.event of (ref KeyEvent):
            updatePos()
      

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
      this.fill scenearea

      this.ignoreHandling[] = true

      var oldPos: Property[Vec2]
      var prevPos: Vec2

      var operationStarted = false

      proc finishOperation =
        operationStarted = false
        let d = posToObject(this, scene, vec2(this.mouseX[], this.mouseY[]))
        let oldPos = posToObject(this, scene, oldPos[])
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

      this.pressed.changed.connectTo this, pressed:
        if pressed:
          oldPos[] = vec2(this.mouseX[], this.mouseY[])
          if toolbar.currentTool[] == ToolKind.rect:
            operationStarted = true
        else:
          if toolbar.currentTool[] == ToolKind.rect:
            finishOperation()
      
      toolbar.currentTool.changed.connectTo this:
        if toolbar.currentTool[] != ToolKind.rect and operationStarted:
          finishOperation()
      
      proc updatePos =
        if ({Key.lalt, Key.ralt} * this.parentWindow.keyboard.pressed).len > 0:
          oldPos[] = oldPos[] + (vec2(this.mouseX[], this.mouseY[]) - prevPos)
        prevPos = vec2(this.mouseX[], this.mouseY[])
        redraw this

      this.mouseX.changed.connectTo this: updatePos()
      this.mouseY.changed.connectTo this: updatePos()

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
      this.top = header.bottom
      this.bottom = timelinePanel.top
      this.left = parent.left
      this.w[] = 40

    - newWindowHeader() as header:
      this.fillHorizontal parent
      this.h[] = 40


  run win.siwinWindow


when isMainModule:
  dispatch animaui
