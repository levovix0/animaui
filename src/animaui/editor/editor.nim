import std/[importutils, asyncdispatch]
import pkg/[vmath, siwin, localize]
import pkg/sigui/[uibase]
import ./[scene, commands]

type
  EditorRequestResultStatus* = enum
    ok
    canceled
  
  EditorRequestResult*[T] = object
    case status*: EditorRequestResultStatus
    of ok:
      value*: T
    of canceled:
      discard


  EditorRequestKind = enum
    point

  EditorPointRequest* = object
    message*: string


  EditorRequest = object
    case kind: EditorRequestKind
    of point:
      point_args: EditorPointRequest
      point_future: Future[EditorRequestResult[Vec3]]

  
  Editor* = ref object of RootObj
    currentScene*: Scene

    startedRequest*: Event[EditorRequest]
    finishedRequest*: Event[EditorRequest]

    pendingRequests: seq[EditorRequest]


# todo: move to another file -->

proc vec3*(v: Vec2): Vec3 =
  vec3(v.x, v.y, 0)

proc vec2*(v: Vec3): Vec2 =
  vec2(v.x, v.y)

# todo: <-- move to another file



proc addPendingRequest(editor: Editor, request: EditorRequest) =
  editor.pendingRequests.add(request)
  if editor.pendingRequests.len == 1:
    editor.startedRequest.emit(request)


proc finishCurrentRequest(editor: Editor) =
  if editor.pendingRequests.len == 0: return

  editor.finishedRequest.emit(editor.pendingRequests[0])
  editor.pendingRequests.delete(0)

  if editor.pendingRequests.len != 0:
    editor.startedRequest.emit(editor.pendingRequests[0])


proc editor*(ctx: CommandInvokationContext): Editor =
  privateAccess CommandInvokationContext
  ctx.untyped_editor.Editor


proc scene*(ctx: CommandInvokationContext): Scene =
  ctx.editor.currentScene


proc getPoint*(editor: Editor, args: EditorPointRequest): Future[EditorRequestResult[Vec3]] =
  result = newFuture[EditorRequestResult[Vec3]]("getPoint")
  editor.addPendingRequest EditorRequest(kind: point, point_args: args, point_future: result)


proc getPoint*(
  editor: Editor,
  message: string = tr("Select point:")
): Future[EditorRequestResult[Vec3]] =
  editor.getPoint(EditorPointRequest(
    message: message,
  ))


template getRequiredPoint*(
  editor: Editor,
  message: string = tr("Select point:")
): Vec3 =
  let p_rr = editor.getPoint(message).await
  if p_rr.status != ok: return

  p_rr.value


method on_mouseButton*(editor: Editor, event: MouseButtonEvent) {.base.} =
  block accept_pending_point_requests:
    if editor.currentScene == nil:
      break accept_pending_point_requests

    if editor.pendingRequests.len == 0 or editor.pendingRequests[0].kind != point:
      break accept_pending_point_requests

    if event.button == MouseButton.left and not event.pressed:
      let scene_local_pos = event.window.mouse.pos.posToLocal(editor.currentScene)
      if (
        scene_local_pos.x notin 0'f32..editor.currentScene.w[] or
        scene_local_pos.y notin 0'f32..editor.currentScene.h[]
      ):
        break accept_pending_point_requests

      let pos = scene_local_pos.pxToScene(editor.currentScene)

      editor.pendingRequests[0].point_future.complete(
        EditorRequestResult[Vec3](status: ok, value: vec3(pos.x, pos.y, 0))
      )

      editor.finishCurrentRequest()

