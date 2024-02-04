import std/[times, strutils]
import sigui/[uibase, mouseArea], siwin
import ../[utils]
import ./[fonts, keyframes]

type
  TimelinePanel* = ref object of UiRect
    actions*: Property[seq[Keyframe[void]]]
    currentTime*: Property[Duration]
    
    actionsView: CustomProperty[Uiobj]


proc newTimelinePanel*(fonts: Fonts): TimelinePanel =
  result = TimelinePanel()

  result.makeLayout:
    var timeScale = 0.5.property  # seconds per label
    var pixelsUntilText = 50.0.property  # pixels per label
    var startFromPixel = 20.0.property

    this.color[] = "303030"

    this.actionsView --- Uiobj():
      this.fillHorizontal parent
      this.h[] = 1
      this.bottom = parent.bottom - 10

      block:
        for x in root.actions:
          proc impl(x: Keyframe[void]) =  ## todo [in siwin]: make this automatic capture
            this.makeLayout:
              - UiRect():
                this.h[] = 1
                this.binding x: (x.time.inMicroseconds() / 1_000_000) * (pixelsUntilText[] / timeScale[]) + startFromPixel[]
                this.color[] = "8f8"
                this.w[] = 1
                this.binding w: (x.changeDuration.toDuration.inMicroseconds() / 1_000_000) * (pixelsUntilText[] / timeScale[])
          impl(x)

    this.actions.changed.connectTo this: this.actionsView[] = UiObj(); redraw this

    - UiRect():
      this.fillVertical parent
      this.binding w: parent.w[]
      this.binding x: (startFromPixel[] - this.w[]).max(-this.w[]).min(0)

      this.color[] = "282828"

    - UiRect() as mouseCacert:
      this.fillVertical parent
      this.w[] = 1
      this.binding visibility:
        if mouse.hovered[]: Visibility.visible
        else: Visibility.hiddenTree
      this.binding x: vec2(mouse.mouseX[], 0).posToLocal(parent).x
      this.color[] = "777"

      proc updateX =
        if not mouse.pressed[]: return
        let d = vec2(mouse.mouseX[], 0).posToLocal(parent).x
        root.currentTime[] = initDuration(microseconds=1) * (((-startFromPixel[] + d) * (timeScale[] / pixelsUntilText[])) * 1_000_000).int
      
      mouse.mouseX.changed.connectTo this: updateX()
      mouse.pressed.changed.connectTo this:
        if mouse.pressed[]: updateX()
    
    - UiRect() as cacert:
      this.fillVertical parent
      this.w[] = 1
      this.binding x: (root.currentTime[].inMicroseconds() / 1_000_000) * (pixelsUntilText[] / timeScale[]) + startFromPixel[]
      this.color[] = "aaa"

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
          this.centerY = parent.center
          this.font[] = (fonts.firaCode)(10)
          let timef = time.round(2)
          this.text[] = (if timef == timef.int.float: $timef.int else: $timef)
          this.color[] = "aaa"
          this.centerX = parent.left + (i.float * pixelsUntilText[])

          - UiRect():
            this.drawLayer = before mouseCacert
            this.left = parent.center
            this.top = root.top
            this.w[] = 1
            this.binding h:
              if "." in parent.text[]: 5
              else: 8
            
            this.color[] = "777"

      proc update =
        let count = (this.w[] / pixelsUntilText[]).int
        if this.childs.len > count+2: this.childs[count+1..^1] = @[]

        for i in (this.childs.len)..(count+1):
          let originalRoot = root
          this.makeLayout:
            - UiText():
              this.centerY = parent.center
              this.font[] = (fonts.firaCode)(10)
              this.color[] = "aaa"
              this.centerX = parent.left + (i.float * pixelsUntilText[])

              - UiRect():
                this.drawLayer = before mouseCacert
                this.left = parent.center
                this.top = originalRoot.top
                this.w[] = 1
                this.binding h:
                  if "." in parent.text[]: 5
                  else: 8
                
                this.color[] = "777"
        
        for i, x in this.childs:
          let time = (-(startFromPixel[] / pixelsUntilText[]).int + i).float * timeScale[]
          let timef = time.round(2)
          x.UiText.text[] = (if timef == timef.int.float: $timef.int else: $timef)
        
        redraw this

      startFromPixel.changed.connectTo this: update()
      this.w.changed.connectTo this: update()
    
    timeScale.changed.connectTo this: texts[] = UiObj(); redraw this
    pixelsUntilText.changed.connectTo this: texts[] = UiObj(); redraw this

    - MouseArea() as rmouse:
      this.fill parent
      this.acceptedButtons[] = {MouseButton.right}
      var oldX = 0'f32
      this.mouseX.changed.connectTo this:
        if this.pressed[]:
          startFromPixel[] = startFromPixel[] + (this.mouseX[] - oldX)
        oldX = this.mouseX[]

    - MouseArea() as mouse:
      this.fill parent
      this.acceptedButtons[] = {MouseButton.left}
