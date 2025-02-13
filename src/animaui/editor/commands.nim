import std/[algorithm, unicode]
import pkg/[chronos, localize {.all.}]
import ./[entities]


type
  CommandIconKind* = enum
    svg

  CommandIcon* = object
    case kind*: CommandIconKind
    of svg:
      svg*: string

  
  CommandInvokationContext* = ref object of RootObj
    locale*: (Locale, LocaleTable)
    database*: Database

    untyped_editor: ref RootObj


  Command* = object
    name*: string
    icon*: CommandIcon
    action*: proc(ctx: CommandInvokationContext) {.async: (raises: [Exception]).}


  MatchInfo* = object
    score: int
    matchedLetters: set[byte]


  Commands* = ref object
    commands: seq[Command]


proc findByName*(commands: Commands, query: string, trueshold: int = 0): seq[tuple[command: Command, matchInfo: MatchInfo]] =
  proc score(name: string, query: string): MatchInfo =
    let name = name.toLower
    let query = query.toLower

    block startsWith:
      var score = 0

      var i = 0
      while i < min(name.len, query.len):
        if name[i] == query[i]:
          score += 100
          if i < byte.high.int:
            result.matchedLetters.incl i.byte
          inc i
        else:
          break
      
      if i < name.len:
        score = (score - 10 * (name.len - 1 - i)).max(score div 10)
      
      result.score += score
    
    block softSearch:
      var score = 0

      var qi = 0
      var ni = 0
      var ni2 = 0
      while qi < query.len and ni < name.len:
        if query[qi] == name[ni]:
          score += 20
          result.matchedLetters.incl ni.byte
          inc qi
          inc ni
        else:
          ni2 = ni
          while ni2 < name.len and name[ni2] != query[qi]:
            inc ni2
          if ni2 < name.len:
            score += 10
            result.matchedLetters.incl ni2.byte
            ni = ni2 + 1
            inc qi
          else:
            score -= 10
            inc qi

      if qi < query.len:
        score = (score - 10 * (query.len - qi)).max(score div 10)

      result.score += score

  for c in commands.commands:
    let matchInfo = score(c.name, query)
    if matchInfo.score >= trueshold:
      result.add (c, matchInfo)

  result = result.sortedByIt(-it.matchInfo.score)



proc add*(cmds: Commands, cmd: Command) =
  cmds.commands.add(cmd)


template tr*(ctx: CommandInvokationContext, text: static string, context: static string = ""): string =
  bind trImpl
  let langv {.cursor.} = ctx.locale
  trImpl(text, context, instantiationInfo(index=0, fullPaths=true).filename, langv)


proc db*(ctx: CommandInvokationContext): Database {.inline.} = ctx.database


when isMainModule:
  import pkg/print

  var cmds = Commands()

  cmds.commands = @[
    Command(name: "select"),
    Command(name: "rectangle"),
    Command(name: "undo"),
    Command(name: "react"),
    Command(name: "ani"),
    Command(name: "animate"),
  ]

  print cmds.findByName("a", 11)
  print cmds.findByName("an", 11)
  print cmds.findByName("ai", 11)
  print cmds.findByName("ni", 11)
  print cmds.findByName("sel", 11)
  print cmds.findByName("re", 11)
  print cmds.findByName("ee", 11)

