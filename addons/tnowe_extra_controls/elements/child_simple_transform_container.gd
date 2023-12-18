@tool
class_name ChildSimpleTransformContainer
extends Container

## A container that stretches its children to its full rect, then applies rect-constrained transform. [br]
## Less granular control compared to [ChildTransformContainer], but fits to children's size more reliably.

## Rotate children by 90 degrees clockwise. [br]
## For counter-clockwise, also enable [member flip_h] and [member flip_v].
@export var rotate90 := false:
	set(v):
		rotate90 = v
		parent_queue_sort()
## Flips children horizontally, before rotation.
@export var flip_h := false:
	set(v):
		flip_h = v
		parent_queue_sort()
## Flips children vertically, before rotation.
@export var flip_v := false:
	set(v):
		flip_v = v
		parent_queue_sort()


func _get_minimum_size():
	var found_minsize = Vector2.ZERO
	for x in get_children():
		if !x is Control: continue
		var x_cast : Control = x
		var x_minsize := x_cast.get_combined_minimum_size()
		found_minsize = Vector2(
			max(found_minsize.x, x_minsize.x),
			max(found_minsize.y, x_minsize.y),
		) if !rotate90 else Vector2(
			max(found_minsize.x, x_minsize.y),
			max(found_minsize.y, x_minsize.x),
		)

	return found_minsize


func _notification(what : int):
	if what == NOTIFICATION_SORT_CHILDREN:
		for x in get_children():
			if x is Control:
				sort_child(x)


func parent_queue_sort():
	if is_inside_tree():
		get_parent().queue_sort()

	_notification(NOTIFICATION_SORT_CHILDREN)


func sort_child(child : Control):
	if !rotate90:
		fit_child_in_rect(child, Rect2(0, 0, size.x, size.y))
		if flip_h: child.position.x += child.size.x
		if flip_v: child.position.y += child.size.y
		child.rotation = 0.0

	else:
		fit_child_in_rect(child, Rect2(0, 0, size.y, size.x))
		if flip_h: child.position.y += child.size.x
		if flip_v: child.position.x += 0.0
		else: child.position.x += child.size.y
		child.rotation = PI * 0.5

	child.scale = Vector2(
		-1 if flip_h else 1,
		-1 if flip_v else 1,
	)