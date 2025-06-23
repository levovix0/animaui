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
    let obj = SiguiEntity()
    obj.pos = r.xy
    obj.size = r.wh
    obj.setKind(rect)

    obj.scene = ctx.editor.currentScene.typedId

    ctx.database.add obj
    ctx.editor.currentScene.initialFrameEntities.add obj.FrameEntity.typedId
    
    let pair = obj.clone.FrameEntity
    pair.role = FrameEntityRole.current
    pair.scene = ctx.editor.currentScene.typedId

    pair.pair = obj.FrameEntity.typedId
    obj.pair = pair.typedId

    ctx.database.add pair
    ctx.editor.currentScene.currentFrameEntities.add pair.typedId

