@tool
class_name ChildTransformContainer
extends Container

## A container that stretches its children to its full rect, then applies position, rotation and scale transform.

## Offset all child controls.
@export_group("Transform")
@export var child_offset := Vector2.ZERO:
	set(v):
		child_offset = v
		parent_queue_sort()
## Rotate all child controls, using their center as pivot.
@export var child_rotation := 0.0:
	set(v):
		child_rotation = v
		child_rotation_xform = Transform2D(deg_to_rad(v), Vector2.ZERO)
		parent_queue_sort()
## Scale all child controls.
@export var child_scale := Vector2.ONE:
	set(v):
		child_scale = v
		parent_queue_sort()

@export_group("Rect")
## Grow the child controls by the specified X and Y, in both directions of the respective axes.
@export var child_grow_rect := Vector2.ZERO:
	set(v):
		child_grow_rect = v
		parent_queue_sort()
## Inherit the minimum size from children's minimum size, taking into account [member child_scale].
@export var minsize_from_children := true:
	set(v):
		minsize_from_children = v
		parent_queue_sort()
## If [member minsize_from_children] enabled, child scale and rotation applies to the min-size of this node.
@export var minsize_from_child_xform := false:
	set(v):
		minsize_from_child_xform = v
		parent_queue_sort()

var child_rotation_xform := Transform2D.IDENTITY


func _get_minimum_size():
	if !minsize_from_children:
		return Vector2.ZERO

	var found_minsize = Vector2.ZERO

	if !minsize_from_child_xform:
		for x in get_children():
			if !x is Control: continue
			var x_cast : Control = x
			var x_minsize := x_cast.get_combined_minimum_size()
			found_minsize = Vector2(
				maxf(found_minsize.x, x_minsize.x),
				maxf(found_minsize.y, x_minsize.y),
			)

		return found_minsize

	for x in get_children():
		if !x is Control: continue
		var x_cast : Control = x
		var x_minsize := (child_rotation_xform * Rect2(Vector2.ZERO, x_cast.get_combined_minimum_size() * child_scale)).size
		found_minsize = Vector2(
			maxf(found_minsize.x, x_minsize.x),
			maxf(found_minsize.y, x_minsize.y),
		)

	return found_minsize


func _notification(what : int):
	if what == NOTIFICATION_SORT_CHILDREN:
		for x in get_children():
			if x is Control:
				sort_child(x)


func sort_child(child : Control):
	fit_child_in_rect(child, Rect2(0, 0, size.x, size.y))
	child.size += child_grow_rect
	child.position += child_offset - (child_rotation_xform * (child.size * 0.5 * child_scale)) + child.size * 0.5 - child_grow_rect * 0.5
	child.rotation = deg_to_rad(child_rotation)
	child.scale = child_scale


func parent_queue_sort():
	if is_inside_tree():
		get_parent().queue_sort()

	queue_sort()
