import times
import sigui/[uibase, animations]

type
  ChangeDurationKind* = enum
    default
    custom
  
  ChangeDuration* = object
    kind*: ChangeDurationKind
    custom*: Duration

  
  InterpolationKind* = enum
    default
    custom
  
  Interpolation* = object
    kind*: InterpolationKind
    custom*: proc(x: float): float


  Keyframe*[T] = object
    time*: Duration
    changeDuration*: ChangeDuration
    interpolation*: Interpolation  # easing
    value*: T


proc toDuration*(this: ChangeDuration): Duration =
  case this.kind
  of default: 0.2's
  of custom: this.custom


proc getValueAtTime*[T](keyframes: seq[Keyframe[T]], time: Duration): T =
  if keyframes.len == 0: return T.default
  var prevKeyframe = Keyframe[T](time: -initDuration(days=1))
  var currentKeyframe = Keyframe[T](time: -initDuration(days=1))
  for x in keyframes:
    if x.time >= currentKeyframe.time and time >= x.time:
      prevKeyframe = currentKeyframe
      currentKeyframe = x
    elif x.time >= prevKeyframe.time and time >= x.time:
      prevKeyframe = x

  let dur = currentKeyframe.changeDuration.toDuration
  
  let f =
    if currentKeyframe.interpolation.kind == InterpolationKind.default:
      outSquareEasing
    else:
      currentKeyframe.interpolation.custom
  
  if currentKeyframe.time + dur <= time:
    return currentKeyframe.value

  return interpolate(prevKeyframe.value, currentKeyframe.value, f((time - currentKeyframe.time).inMicroseconds.float / dur.inMicroseconds.float))
