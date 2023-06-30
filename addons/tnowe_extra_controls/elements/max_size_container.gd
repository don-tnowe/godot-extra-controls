@tool
class_name MaxSizeContainer
extends Container

## Container that stretches children to fit, but only up to its set max size.

## Maximum size of child controls. If -1 on either axis, does not limit size on that axis. [br]
## [b]Note:[/b] size cannot go under the control's own minimum size.
@export var max_size := -Vector2.ONE:
	set(v):
		max_size = v
		queue_sort()


func _notification(what : int):
	if what == NOTIFICATION_SORT_CHILDREN:
		for x in get_children():
			if x is Control:
				_resize_child(x)


func _resize_child(child : Control):
	var minsize := child.get_combined_minimum_size()
	var result_size := Vector2(
		max(size.x if max_size.x < 0 else min(max_size.x, size.x), minsize.x),
		max(size.y if max_size.y < 0 else min(max_size.y, size.y), minsize.y),
	)
	fit_child_in_rect(child, Rect2((size - result_size) * 0.5, result_size))


func _property_can_revert(property):
	if property == &"max_size":
		return max_size != size


func _property_get_revert(property):
	if property == &"max_size":
		return size
