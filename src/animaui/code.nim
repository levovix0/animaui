import os, sequtils, unicode, times, strutils, sugar
import sigui/uibase, jsony
import text, syntax_highlighting, basic

type
  ColorTheme* = object
    cActive*: ColorRGB
    cInActive*: ColorRGB
    cMiddle*: ColorRGB
  
    bgScrollBar*: ColorRGB
    bgVerticalLine*: ColorRGB
    bgLineNumbers*: ColorRGB
    bgLineNumbersSelect*: ColorRGB
    bgTextArea*: ColorRGB
    bgStatusBar*: ColorRGB
    bgExplorer*: ColorRGB
    bgSelectionLabel*: ColorRGB
    bgSelection*: ColorRGB
    bgTitleBar*: ColorRGB
    bgTitleBarSelect*: ColorRGB

    sKeyword*: ColorRGB
    sOperatorWord*: ColorRGB
    sBuiltinType*: ColorRGB
    sControlFlow*: ColorRGB
    sType*: ColorRGB
    sStringLit*: ColorRGB
    sStringLitEscape*: ColorRGB
    sNumberLit*: ColorRGB
    sFunction*: ColorRGB
    sComment*: ColorRGB
    sTodoComment*: ColorRGB
    sError*: ColorRGB
    
    sLineNumber*: ColorRGB
    
    sText*: ColorRGB


  Code* = ref object of UiObj
    text*: Property[string]
    font*: Property[Font]
    textObj*: CustomProperty[UiObj]
  

  TextConstructMode* = enum
    lineByLine


proc parseHook*(s: string, i: var int, v: var ColorRGB) =
  try:
    var str: string
    parseHook(s, i, str)
    v = parseHex(str).rgb
  except: discard

proc dumpHook*(s: var string, v: ColorRGB) =
  s.add v.color.toHex.toJson


proc readColorTheme(s: string): ColorTheme =
  result = s.readFile.fromJson(ColorTheme)

const theme {.strdefine.} = "vscode"

var colorTheme* = readColorTheme("themes" / (theme & ".json"))


proc color*(sk: CodeKind): ColorRGB =
  case sk
  of sKeyword, sOperatorWord, sBuiltinType:
    colorTheme.sKeyword

  of sControlFlow:
    colorTheme.sControlFlow
  
  of sType:
    colorTheme.sType
  
  of sStringLit, sCharLit:
    colorTheme.sStringLit
  
  of sStringLitEscape, sCharLitEscape:
    colorTheme.sStringLitEscape
  
  of sNumberLit:
    colorTheme.sNumberLit
  
  of sFunction:
    colorTheme.sFunction
  
  of sComment:
    colorTheme.sComment
  
  of sTodoComment:
    colorTheme.sTodoComment
  
  of sLineNumber:
    colorTheme.sLineNumber
  
  of sError:
    colorTheme.sError
  
  else: colorTheme.sText

proc colors*(scs: openarray[CodeKind]): seq[ColorRgb] =
  scs.map(color)


method init*(this: Code) =
  if this.initialized: return
  procCall this.super.init()

  this.makeLayout:
    this.textObj --- UiObj():
      if root.font != nil:
        let text = root.text[].newText
        let typeset = root.font[].typeset(root.text[])
        var highlighting = parseNimCode(text, NimParseState(), text.len).segments.colors
        var maxw, maxh: float32

        for i, x in typeset.selectionRects:
          maxw = max(maxw, x.x + x.w)
          maxh = max(maxh, x.y + x.h)

          - UiText():
            this.xy[] = x.xy
            this.text[] = $typeset.runes[i]
            this.color[] = highlighting[i].color
            this.font[] = root.font[]

        this.w[] = maxw
        this.h[] = maxh

        root.w[] = maxw
        root.h[] = maxh
    
    this.binding textObj:
      discard root.text[]
      discard root.font[]
      UiObj()


proc textAutoConstruct*(
  this: Code,
  mode: TextConstructMode,
  timepoint: Duration,
  total, pauseTotal: Duration,
  slideUp: float = 0,
  slideDown: float = 0,
  slideLeft: float = 0,
  slideRight: float = 0,
) =
  case mode
  of lineByLine:
    let lineCount = this.text[].splitLines.len
    let appearTime = (total - pauseTotal) div lineCount
    let appearPause = pauseTotal div (lineCount-1)
    
    var line = 0

    # make all transparent
    for x in this.textObj[].childs:
      let x = x.UiText
      var transparentCol = x.color[]
      transparentCol.a = 0
      x.color[] = transparentCol

    # appear line by line
    for x in this.textObj[].childs:
      let x = x.UiText
      
      if x.text[] == "\n":
        inc line
        continue
      
      capture x, line:
        timeactions.add (timepoint + ((appearTime + appearPause) * line), proc() {.closure.} =
          x.appear(
            slideUp = slideUp,
            slideDown = slideDown,
            slideLeft = slideLeft,
            slideRight = slideRight,
            changeDuration = appearTime,
          )
        )


proc stripCode*(text: string): string =
  result = text.strip(chars = {' '})
  if result.startsWith("\n"): result = result[1..^1]
  if result.endsWith("\n"): result = result[0..^2]
  result = result.unindent(text.indentation)
