import std/[times, sequtils, strutils]
import sigui/[uibase, mouseArea, globalShortcut], siwin
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
    
    actionsView: ChangableChild[Uiobj]
    opacityActionsView: ChangableChild[Uiobj]
    texts: ChangableChild[Uiobj]

registerComponent TimelinePanel


method init*(this: TimelinePanel) =
  procCall this.super.init()

  this.endTime[] = initDuration(seconds=5)

  this.makeLayout:
    var timeScale = 0.5.property  # seconds per label
    var pixelsUntilText = 50.0.property  # pixels per label
    var startFromPixel = 20.0.property

    proc timeToPx(time: Duration): float =
      (time.inMicroseconds() / 1_000_000) * (pixelsUntilText[] / timeScale[])

    color = "303030"


    this.actionsView --- Uiobj.new:
      <--- UiObj(): this.actions[]

      this.fillHorizontal parent
      h = 2
      bottom = parent.bottom - 20

      for x in root.actions:
        - UiRect.new:
          w = 1
          h = 2
          this.binding x: (x.time.inMicroseconds() / 1_000_000) * (pixelsUntilText[] / timeScale[]) + startFromPixel[]
          this.binding w: (x.changeDuration.toDuration.inMicroseconds() / 1_000_000) * (pixelsUntilText[] / timeScale[])
          color = "8f8"


    this.opacityActionsView --- Uiobj.new:
      <--- UiObj(): this.opacityActions[]

      this.fillHorizontal parent
      h = 2
      # bottom = parent.bottom - 12
      bottom = parent.bottom - 16

      for x in root.opacityActions:
        - UiRect.new:
          w = 1
          h = 2
          this.binding x: (x.time.inMicroseconds() / 1_000_000) * (pixelsUntilText[] / timeScale[]) + startFromPixel[]
          this.binding w: (x.changeDuration.toDuration.inMicroseconds() / 1_000_000) * (pixelsUntilText[] / timeScale[])
          color = "888"


    - UiRect.new:
      this.fillVertical parent
      w := parent.w[]
      x := (startFromPixel[] - this.w[] + root.startTime[].timeToPx).max(-this.w[]).min(0)

      color = "282828"


    - UiRect.new:
      this.fillVertical parent
      w := parent.w[]
      x := (startFromPixel[] + root.endTime[].timeToPx).max(0).min(parent.w[])
      color = "282828"


    - UiRect.new as mouseCacert:
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
    

    - UiRect.new as cacert:
      this.fillVertical parent
      w = 1
      this.binding x: (root.currentTime[].inMicroseconds() / 1_000_000) * (pixelsUntilText[] / timeScale[]) + startFromPixel[]
      color = "aaa"


    root.texts --- UiObj.new:
      <--- UiObj.new: timeScale[]; pixelsUntilText[]; this.w[]; startFromPixel[]
      # todo: CycledElement

      this.top = parent.top + 10
      this.h[] = 20
      w = parent.w[]
      x = (startFromPixel[] mod pixelsUntilText[])

      
      let count = (this.w[] / pixelsUntilText[]).int
      for i in 0..(count+1):
        let time = (-(startFromPixel[] / pixelsUntilText[]).int + i).float * timeScale[]

        - UiText.new:
          centerY = parent.center
          font = (fonts.firaCode)(10)
          let timef = time.round(2)
          text = (if timef == timef.int.float: $timef.int else: $timef)
          color = "aaa".toColor.static
          this.centerX = parent.left + (i.float * pixelsUntilText[])
          x = (i.float * pixelsUntilText[]) - this.w[] / 2

          - UiRect.new:
            drawLayer = before mouseCacert
            left = parent.center
            top = root.top
            w = 1
            this.binding h:
              if "." in parent.text[]: 5
              else: 8
            
            color = "777"


    - MouseArea.new as rmouse:
      this.fill parent
      acceptedButtons = {MouseButton.right}
      var oldX = 0'f32
      this.mouseX.changed.connectTo this:
        if this.pressed[]:
          startFromPixel[] = startFromPixel[] + (this.mouseX[] - oldX)
        oldX = this.mouseX[]


    - MouseArea.new as mouse:
      this.fill parent
      acceptedButtons = {MouseButton.left}


    - globalShortcut({Key.q}):
      on this.activated:
        root.currentTime[] = root.currentTime[] - initDuration(microseconds = int (timeScale[] / 20 * 1_000_000))
    
    - globalShortcut({Key.e}):
      on this.activated:
        root.currentTime[] = root.currentTime[] + initDuration(microseconds = int (timeScale[] / 20 * 1_000_000))
    
    - globalShortcut({Key.lshift, Key.q}):
      on this.activated:
        root.currentTime[] = root.currentTime[] - initDuration(microseconds = int (timeScale[] * 1_000_000))
    
    - globalShortcut({Key.lshift, Key.e}):
      on this.activated:
        root.currentTime[] = root.currentTime[] + initDuration(microseconds = int (timeScale[] * 1_000_000))
      
    - globalShortcut({Key.lshift, Key.lbracket}):
      on this.activated:
        root.startTime[] = root.currentTime[]
      
    - globalShortcut({Key.lshift, Key.rbracket}):
      on this.activated:
        root.endTime[] = root.currentTime[]
    
    - globalShortcut({Key.space}):
      on this.activated:
        root.playing[] = not root.playing[]
