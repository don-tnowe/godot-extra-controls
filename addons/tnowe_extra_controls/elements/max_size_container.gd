@tool
class_name MaxSizeContainer
extends Container

## Container that stretches children to fit, but only up to its set max size.

## Maximum size of child controls. If -1 on either axis, does not affect size on that axis. [br]
## [b]Note:[/b] size cannot go under the control's own minimum size.
@export var max_size := -Vector2.ONE:
	set(v):
		max_size = v
		queue_sort()
## Use [member max_size] as an aspect ratio instead. One axis of [member max_size] must be -1. [br]
## For example, [code](2.5, -1)[/code] will ensure the X axis is no more than 2.5x the width of the Y axis.
@export var proportional_size := false:
	set(v):
		proportional_size = v
		queue_sort()


func _notification(what : int):
	if what == NOTIFICATION_SORT_CHILDREN:
		for x in get_children():
			if x is Control:
				_resize_child(x)


func _resize_child(child : Control):
	if max_size.x < 0.0 && max_size.y < 0.0:
		# Don't affect either side.
		fit_child_in_rect(child, Rect2(Vector2.ZERO, size))
		return

	var minsize := child.get_combined_minimum_size()
	var result_size := Vector2()

	if proportional_size:
		result_size = size
		if max_size.x < 0.0 && size.y / size.x > max_size.y:
			result_size.y = size.x * max_size.y

		if max_size.y < 0.0 && size.x / size.y > max_size.x:
			result_size.x = size.y * max_size.x

	else:
		result_size = Vector2(
			maxf(size.x if max_size.x < 0.0 else minf(max_size.x, size.x), minsize.x),
			maxf(size.y if max_size.y < 0.0 else minf(max_size.y, size.y), minsize.y),
		)

	fit_child_in_rect(child, Rect2((size - result_size) * 0.5, result_size))


func _property_can_revert(property):
	if property == &"max_size":
		return max_size != size


func _property_get_revert(property):
	if property == &"max_size":
		return size
