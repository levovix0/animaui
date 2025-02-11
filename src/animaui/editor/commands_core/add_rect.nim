import std/[asyncdispatch]
import pkg/[localize, bumpy, vmath]
import pkg/sigui/[uibase]
import ../[commands, editor, scene]


proc command_add_rect*(ctx: CommandInvokationContext) {.async.} =
  let a = ctx.editor.getRequiredPoint(tr("Select first point:"))
  let b = ctx.editor.getRequiredPoint(tr("Select second point:"))

  var r = bumpy.rect(a.vec2, (b - a).vec2)
  if r.w < 0:
    r.x = r.x + r.w
    r.w = -r.w
  if r.h < 0:
    r.y = r.y + r.h
    r.h = -r.h
  
  ctx.scene.makeLayout:
    - SceneObject() as o:
      this.kind[] = rect
      this.color[] = "fff"
      this.opacity[] = 1

      this.x[] = r.x
      this.y[] = r.y
      this.w[] = r.w
      this.h[] = r.h
