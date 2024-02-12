import std/[times, strutils, sequtils]
import sigui/[uibase, mouseArea, globalShortcut, dolars], siwin
import ../[utils]
import ./[fonts, keyframes]

type
  TimelinePanel* = ref object of UiRect
    actions*: Property[seq[Keyframe[void]]]
    colorActions*: Property[seq[Keyframe[void]]]
    opacityActions*: Property[seq[Keyframe[void]]]
    currentTime*: Property[Duration]
    playing*: Property[bool]

    startTime*: Property[Duration] 
    endTime*: Property[Duration] 
    
    actionsView: CustomProperty[Uiobj]
    opacityActionsView: CustomProperty[Uiobj]

registerComponent TimelinePanel


proc newTimelinePanel*(): TimelinePanel =
  result = TimelinePanel()

  result.endTime[] = initDuration(seconds=5)

  result.makeLayout:
    var timeScale = 0.5.property  # seconds per label
    var pixelsUntilText = 50.0.property  # pixels per label
    var startFromPixel = 20.0.property

    proc timeToPx(time: Duration): float =
      (time.inMicroseconds() / 1_000_000) * (pixelsUntilText[] / timeScale[])

    color = "303030"

    this.actionsView --- Uiobj():
      this.fillHorizontal parent
      h = 2
      bottom = parent.bottom - 20

      for x in root.actions:
        - UiRect():
          w = 1
          h = 2
          this.binding x: (x.time.inMicroseconds() / 1_000_000) * (pixelsUntilText[] / timeScale[]) + startFromPixel[]
          this.binding w: (x.changeDuration.toDuration.inMicroseconds() / 1_000_000) * (pixelsUntilText[] / timeScale[])
          color = "8f8"

    this.opacityActionsView --- Uiobj():
      this.fillHorizontal parent
      h = 2
      # bottom = parent.bottom - 12
      bottom = parent.bottom - 16

      for x in root.opacityActions:
        - UiRect():
          w = 1
          h = 2
          this.binding x: (x.time.inMicroseconds() / 1_000_000) * (pixelsUntilText[] / timeScale[]) + startFromPixel[]
          this.binding w: (x.changeDuration.toDuration.inMicroseconds() / 1_000_000) * (pixelsUntilText[] / timeScale[])
          color = "888"

    this.actions.changed.connectTo this: this.actionsView[] = UiObj()
    this.opacityActions.changed.connectTo this: this.opacityActionsView[] = UiObj()

    - UiRect():
      this.fillVertical parent
      this.binding w: parent.w[]
      this.binding x: (startFromPixel[] - this.w[] + root.startTime[].timeToPx).max(-this.w[]).min(0)
      # todo [in sigui]:
      # w := parent.w
      # x := (startFromPixel - this.w).max(-this.w).min(0)
      # w = binding parent.w
      # x = binding (startFromPixel - this.w).max(-this.w).min(0)
      # visibility = binding:
      #   if mouse.hovered and not mouse.pressed: Visibility.visible
      #   else: Visibility.hiddenTree

      color = "282828"

    - UiRect():
      this.fillVertical parent
      this.binding w: parent.w[]
      this.binding x: (startFromPixel[] + root.endTime[].timeToPx).max(0).min(parent.w[])
      color = "282828"

    - UiRect() as mouseCacert:
      this.fillVertical parent
      w = 1
      this.binding visibility:
        if mouse.hovered[] and not mouse.pressed[]: Visibility.visible
        else: Visibility.hiddenTree

      this.binding x: mouse.mouseX[]
      
      color = "777"

      proc updateX =
        if not mouse.pressed[]: return
        let d = mouse.mouseX[]
        let time = initDuration(microseconds=1) * (((-startFromPixel[] + d) * (timeScale[] / pixelsUntilText[])) * 1_000_000).int
        if Key.lcontrol in this.parentWindow.keyboard.pressed or Key.rcontrol in this.parentWindow.keyboard.pressed:
          # align to nearest keyframe
          let nearestDistance = (
            root.actions[].mapit(it.time.inMilliseconds) &
            root.actions[].mapit(it.time.inMilliseconds + it.changeDuration.toDuration.inMilliseconds) &
            root.colorActions[].mapit(it.time.inMilliseconds) &
            root.colorActions[].mapit(it.time.inMilliseconds + it.changeDuration.toDuration.inMilliseconds) &
            root.opacityActions[].mapit(it.time.inMilliseconds) &
            root.opacityActions[].mapit(it.time.inMilliseconds + it.changeDuration.toDuration.inMilliseconds) &
            @[
              int64 (time.inMilliseconds / 1000 / timeScale[]).int.float * 1000 * timeScale[],
              int64 ((time.inMilliseconds / 1000 / timeScale[]).int.float * 1000 + 1000) * timeScale[],
            ]
          )
            .mapit(it - time.inMilliseconds)
            .foldl(if abs(a) < abs(b): a else: b)
          root.currentTime[] = initDuration(milliseconds = time.inMilliseconds + nearestDistance)
        else:
          root.currentTime[] = time
      
      mouse.mouseX.changed.connectTo this: updateX()
      mouse.pressed.changed.connectTo this:
        if mouse.pressed[]: updateX()
    
    - UiRect() as cacert:
      this.fillVertical parent
      w = 1
      this.binding x: (root.currentTime[].inMicroseconds() / 1_000_000) * (pixelsUntilText[] / timeScale[]) + startFromPixel[]
      color = "aaa"

    var texts: CustomProperty[UiObj]
    texts --- UiObj():
      this.top = parent.top + 10
      this.h[] = 20
      this.binding w: parent.w[]
      this.binding x: (startFromPixel[] mod pixelsUntilText[])

      let count = (this.w[] / pixelsUntilText[]).int
      for i in 0..(count+1):
        let time = (-(startFromPixel[] / pixelsUntilText[]).int + i).float * timeScale[]

        - UiText():
          centerY = parent.center
          font = (fonts.firaCode)(10)
          let timef = time.round(2)
          text = (if timef == timef.int.float: $timef.int else: $timef)
          color = "aaa"
          # this.centerX = parent.left + (i.float * pixelsUntilText[])
          x = (i.float * pixelsUntilText[]) - this.w[] / 2

          - UiRect():
            drawLayer = before mouseCacert
            left = parent.center
            top = root.top
            w = 1
            this.binding h:
              if "." in parent.text[]: 5
              else: 8
            
            color = "777"

      proc update =
        let count = (this.w[] / pixelsUntilText[]).int
        if this.childs.len > count+2: this.childs[count+1..^1] = @[]

        for i in (this.childs.len)..(count+1):
          let originalRoot = root
          this.makeLayout:
            - UiText():
              centerY = parent.center
              font = (fonts.firaCode)(10)
              color = "aaa"
              # this.centerX = parent.left + (i.float * pixelsUntilText[])
              x = (i.float * pixelsUntilText[]) - this.w[] / 2

              - UiRect():
                drawLayer = before mouseCacert
                left = parent.center
                top = originalRoot.top
                w = 1
                this.binding h:
                  if "." in parent.text[]: 5
                  else: 8
                
                color = "777"
        
        var neededTexts: seq[string]

        for i, x in this.childs:
          let time = (-(startFromPixel[] / pixelsUntilText[]).int + i).float * timeScale[]
          let timef = time.round(2)
          neededTexts.add (if timef == timef.int.float: $timef.int else: $timef)

        let correctChilds: seq[UiText] = this.childs.mapit(it.UiText).filterit(it.text[] in neededTexts)
        var freeChilds: seq[UiText] = this.childs.mapit(it.UiText).filterit(it notin correctChilds)

        for i, x in neededTexts:
          block selectChild:
            for y in correctChilds:
              if y.text[] == x:
                y.x[] = (i.float * pixelsUntilText[]) - y.w[] / 2
                break selectChild
            let y = freeChilds.pop
            y.text[] = x
            y.x[] = (i.float * pixelsUntilText[]) - y.w[] / 2

      startFromPixel.changed.connectTo this: update()
      this.w.changed.connectTo this: update()
    
    timeScale.changed.connectTo this: texts[] = UiObj()
    pixelsUntilText.changed.connectTo this: texts[] = UiObj()

    - MouseArea() as rmouse:
      this.fill parent
      acceptedButtons = {MouseButton.right}
      var oldX = 0'f32
      this.mouseX.changed.connectTo this:
        if this.pressed[]:
          startFromPixel[] = startFromPixel[] + (this.mouseX[] - oldX)
        oldX = this.mouseX[]

    - MouseArea() as mouse:
      this.fill parent
      acceptedButtons = {MouseButton.left}
    
    - globalShortcut({Key.q}):
      this.activated.connectTo this:
        root.currentTime[] = root.currentTime[] - initDuration(microseconds = int (timeScale[] / 20 * 1_000_000))
    
    - globalShortcut({Key.e}):
      this.activated.connectTo this:
        root.currentTime[] = root.currentTime[] + initDuration(microseconds = int (timeScale[] / 20 * 1_000_000))
    
    - globalShortcut({Key.lshift, Key.q}):
      this.activated.connectTo this:
        root.currentTime[] = root.currentTime[] - initDuration(microseconds = int (timeScale[] * 1_000_000))
    
    - globalShortcut({Key.lshift, Key.e}):
      this.activated.connectTo this:
        root.currentTime[] = root.currentTime[] + initDuration(microseconds = int (timeScale[] * 1_000_000))
      
    - globalShortcut({Key.lshift, Key.lbracket}):
      this.activated.connectTo this:
        root.startTime[] = root.currentTime[]
      
    - globalShortcut({Key.lshift, Key.rbracket}):
      this.activated.connectTo this:
        root.endTime[] = root.currentTime[]
    
    - globalShortcut({Key.space}):
      this.activated.connectTo this:
        root.playing[] = not root.playing[]
