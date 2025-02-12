import pkg/[localize, bumpy, vmath, chronos]
import pkg/sigui/[uibase]
import ../[commands, editor, scene]


proc command_add_rect*(ctx: CommandInvokationContext) {.async: (raises: [Exception]).} =
  let a = ctx.editor.getRequiredPoint(ctx.tr("Select first point:"))
  let b = ctx.editor.getRequiredPoint(ctx.tr("Select second point:"))

  if a == b: return

  var r = bumpy.rect(a.vec2, (b - a).vec2)
  if r.w < 0:
    r.x = r.x + r.w
    r.w = -r.w
  if r.h < 0:
    r.y = r.y + r.h
    r.h = -r.h
  
  {.cast(gcsafe).}:
    ctx.scene.makeLayout:
      - SceneObject() as o:
        this.kind[] = rect
        this.color[] = "fff"
        this.opacity[] = 1

        this.x[] = r.x
        this.y[] = r.y
        this.w[] = r.w
        this.h[] = r.h

