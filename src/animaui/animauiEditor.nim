import std/[algorithm, times, sequtils, logging, osproc, importutils, options, tables]
import pkg/[siwin, cligen, localize, chronos]
import sigui/[uibase, mouseArea, globalShortcut, animations, layouts]
import window, windowHeader
import editor/[fonts, timeline, toolbar, keyframes, scene, editor, commands, commands_core, entities]
import editor/commands_core/[add_rect]

requireLocalesToBeTranslated ("ru", "")

type
  ButtonKind* = enum
    normal
    suggested
  
  Button* = ref object of UiRect
    text*: CustomProperty[string]
    clicked*: Event[void]
    kind*: Property[ButtonKind]

registerComponent Button


method init(this: Button) =
  procCall this.UiRect.init()
  
  this.makeLayout:
    this.radius[] = 5

    this.binding color:
      case root.kind[]
      of normal:
        if mouse.pressed[]: Color "404040"
        elif mouse.hovered[]: Color "505050"
        else: Color "202020"
      of suggested:
        if mouse.pressed[]: Color "215cda"
        elif mouse.hovered[]: Color "628fff"
        else: Color "557DFF"
    
    - UiText():
      parent.binding w: this.w[] + 20
      parent.binding h: this.h[] + 10
      this.font[] = fonts.notoSans.withSize(14)
      this.centerX = parent.center
      this.centerY = parent.center
      this.color[] = "fff"

      root.text = CustomProperty[string](
        get: proc: string = this.text[],
        set: proc(s: string) = this.text[] = s
      )
    
    - MouseArea() as mouse:
      this.fill parent
      this.mouseDownAndUpInside.connectTo this: root.clicked.emit()

proc animaui =
  logging.addHandler newConsoleLogger(fmtStr = "[$date at $time]:$levelname ")
  logging.addHandler newFileLogger("animaui.log", fmWrite, fmtStr = "[$date at $time]:$levelname ")

  var root = newSiwinGlobals().newOpenglWindow(title="animaui editor", frameless = true, transparent = true).newDecoratedWindow
  let win = root

  globalLocale[0] = systemLocale()

  fonts.firaCode = static(staticRead "../../fonts/FiraCode.ttf").parseTtf
  fonts.comfortaa = static(staticRead "../../fonts/Comfortaa.ttf").parseTtf
  fonts.notoSans = static(staticRead "../../fonts/NotoSans-Regular.ttf").parseTtf


  root.makeLayout:
    let this = root.newChildsObject

    type CurrentCommand = object
      future: Future[void]

    var currentCommand: Option[CurrentCommand]
    let editor = Editor(currentSceneView: scene)
    let database = Database.new
    addRegistredEntityTypeInfosToDatabase(database)

    editor.currentScene = Scene.new
    database.add editor.currentScene


    privateAccess CommandInvokationContext
    let cictx = CommandInvokationContext(
      locale: (systemLocale(), LocaleTable.default),
      untyped_editor: editor,
      database: database
    )
    

    proc cancelCurrentCommand() =
      editor.cancelAllPendingRequests()

      if currentCommand.isSome:
        currentCommand.get.future.cancelAndWait().waitFor
        currentCommand = none CurrentCommand


    proc spawnCommand(action: proc(ctx: CommandInvokationContext) {.async: (raises: [Exception]).}) =
      cancelCurrentCommand()

      currentCommand = some CurrentCommand(
        future: (proc(ctx: CommandInvokationContext) {.async: (raises: [Exception]).} =
          action(ctx).await
          currentCommand = none CurrentCommand
        )(cictx)
      )


    proc currentCommandReraiseErrorsLoop() {.async: (raises: [Exception]).} =
      while true:
        if currentCommand.isSome:
          if currentCommand.get.future.failed:
            raise currentCommand.get.future.readError
            # currentCommand = none CurrentCommand
            # todo: don't crush whole app on non-critical exceptions in command
        await sleepAsync(1.millis)


    asyncSpawn editor.reraiseErrorsLoop()
    asyncSpawn currentCommandReraiseErrorsLoop()


    this.onSignal.connectTo this, signal:
      if signal of WindowEvent:
        let ev = signal.WindowEvent.event
        if ev of MouseButtonEvent:
          let e = (ref MouseButtonEvent)ev
          editor.on_mouseButton(e[])


    toolbar.currentTool.changed.connectTo this:
      case toolbar.currentTool[]
      of ToolKind.rect:
        spawnCommand (proc(ctx: CommandInvokationContext) {.async: (raises: [Exception]).} =
          command_add_rect(ctx).await
          try:
            {.cast(gcsafe).}:
              currentCommand = none CurrentCommand
              toolbar.currentTool[] = ToolKind.arrow
          except: discard
        )

      else:
        cancelCurrentCommand()


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

      - SceneView() as scene:
        const aspectRatio = 16/9
        
        this.database = database

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

        timelinePanel.currentTime.changed.connectTo this:
          this.database[this.scene].currentTime = timelinePanel.currentTime[]
      
      # --- borders ---
      - UiRect():
        this.drawLayer = after scenearea
        this.top = parent.top
        this.bottom = scene.top
        this.fillHorizontal parent
        this.color[] = "10101080"
      
      - UiRect():
        this.drawLayer = after scenearea
        this.bottom = parent.bottom
        this.top = scene.bottom
        this.fillHorizontal parent
        this.color[] = "10101080"

      - UiRect():
        this.drawLayer = after scenearea
        this.left = parent.left
        this.right = scene.left
        this.fillVertical parent
        this.color[] = "10101080"
      
      - UiRect():
        this.drawLayer = after scenearea
        this.right = parent.right
        this.left = scene.right
        this.fillVertical parent
        this.color[] = "10101080"



    - globalShortcut({Key.del}):
      this.activated.connectTo this:
        ##
        # if selectedObject[] != nil:
        #   selectedObject[].kind[] = none
        #   selectedObject[].parent[].childs.delete selectedObject[].parent[].childs.find(selectedObject[])
        #   selectedObject[] = nil


    - TimelinePanel() as timelinePanel:
      this.fillHorizontal parent
      bottom = parent.bottom
      h = 150

      this.parentUiWindow.onTick.connectTo this, e:
        if timelinePanel.playing[]:
          timelinePanel.currentTime[] = timelinePanel.currentTime[] + e.deltaTime
    
    - Toolbar() as toolbar:
      top = header.bottom
      bottom = timelinePanel.top
      left = parent.left
      w = 40

    - WindowHeader() as header:
      this.fillHorizontal parent
      h = 40
      win.binding titleHeight: this.h[]

      - Layout():
        left = parent.left + 10
        centerY = parent.center
        spacing = 10
        orientation = horizontal

        - Button():
          kind = suggested
          text = tr"Render"

          this.clicked.connectTo this:
            # render(scene, vec2(1280, 720), "out.mp4", 30, timelinePanel.startTime[], timelinePanel.endTime[])
            render(scene, vec2(1920, 1080), "out.mp4", 30, timelinePanel.startTime[], timelinePanel.endTime[])

        - Button():
          text = tr"Add file"

          this.clicked.connectTo this:
            echo execCmdEx("kdialog --getopenfilename").output.strip



  win.onTick.connectTo win:
    chronos.poll()

  run win.siwinWindow


when isMainModule:
  dispatch animaui
  updateTranslations()
