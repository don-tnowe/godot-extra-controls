@tool
class_name RemoteTransformRect
extends Control

## Pushes its rect size and position to another Control node, similar to [RemoteTransform2D]. Useful for attaching nodes to another node that is inside a container.

## The [Control] whose size will be changed.
@export var target : Control:
  set(v):
    target = v
    queue_redraw()
## Whether to update the target's position.
@export var update_position := true:
  set(v):
    update_position = v
    queue_redraw()
## Whether to update the target's size.
@export var update_size := true:
  set(v):
    update_size = v
    queue_redraw()
## If updating position, whether to use global coordinates, or coordinates relative to this node's parent.
@export var use_global_coordinates := true:
  set(v):
    use_global_coordinates = v
    queue_redraw()
## If updating size, multiplies result by this vector.
@export var target_scale := Vector2.ONE:
  set(v):
    target_scale = v
    queue_redraw()

func _draw():
  if target == null: return

  var xform := get_global_transform()
  if update_size:
    var new_size := size * target_scale * xform.get_scale()
    target.custom_minimum_size = new_size
    target.size = new_size

  if update_position:
    if use_global_coordinates: target.global_position = xform.origin
    else: target.position = position
