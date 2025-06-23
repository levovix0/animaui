import pkg/[localize, bumpy, vmath, chronos]
import pkg/sigui/[uibase]
import ../[commands, editor, scene, entities]


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
    let obj = ctx.database.new SiguiEntity()
    obj.pos = r.xy.sceneToPx(ctx.editor.currentSceneView)
    obj.size = r.wh.sceneToPx(ctx.editor.currentSceneView)
    obj.color = "ffffff".color
    obj.opacity = 1
    obj.setKind(rect)
    
    ctx.scene.add obj

    redraw ctx.editor.currentSceneView

