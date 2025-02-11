import std/[strutils]
import sigui/[uibase, uiobj, scrollArea, layouts, textArea]

type
  Logs* = ref object
    text*: string
    added*: Event[string]

  LogsView* = ref object of Uiobj
    logs*: Property[Logs]
    
    font*: Property[Font]
    textColor*: Property[Color]

    multilineText: ChangableChild[Layout]
    scrollAtEnd: bool = true
    
    multilineText_update_eh: EventHandler
  
  PromptLine* = ref object of Uiobj
    text*: Property[string]
  
  PromptSuggestions* = ref object of Uiobj

  PromptArea* = ref object of Uiobj


proc newLogs*(): Logs =
  new result


proc write*(logs: Logs, text: string) =
  logs.text.add text
  logs.added.emit(text)


proc echo*(logs: Logs, text: varargs[string, `$`]) =
  logs.write text.join() & "\n"


method init(this: LogsView) =
  procCall this.super.init()
  
  this.makeLayout:
    - ScrollArea() as scrollArea:
      this.fill parent
      
      this.targetY.changed.connectTo root:
        const trueshold_px = 50
        if this.targetY[] >= this.scrollH[] - this.h[] - trueshold_px:
          root.scrollAtEnd = true
        else:
          root.scrollAtEnd = false
      
      root.multilineText --- Layout():
        proc subscribe_multilineText_change_to_logs_added =
          disconnect root.multilineText_update_eh
          if root.logs[] != nil:
            root.logs[].added.connectTo root.multilineText_update_eh:
              root.multilineText[] = Layout()
        
        subscribe_multilineText_change_to_logs_added()
        on root.logs.changed: subscribe_multilineText_change_to_logs_added()
        
        this.fillHorizontal parent
        
        orientation = vertical
        hugContent = true
        fillContainer = true
        align = start

        if root.logs[] != nil:
          for line in root.logs[].text.splitLines:
            - UiText():
              font := root.font[]
              text = line
              color := root.textColor[]
              bounds = vec2(parent.w[], 0)
        
        if root.scrollAtEnd:
          scrollArea.targetY[] = scrollArea.scrollH[] - scrollArea.h[]
      

