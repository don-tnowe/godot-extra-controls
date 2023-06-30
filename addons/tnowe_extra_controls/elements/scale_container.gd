@tool
extends Container

## Container that scales children to fit it, instead of resizing them. Can be used for pixel-perfect game viewports.

enum StretchMode {
	IGNORE_ASPECT, ## Scale the control to this node's full rectangle, not preserving aspect.
	ASPECT_CENTERED, ## Scale the control so that the longer side fits the bounding rectangle. The other side clips to this node's limits.[br]For SubViewports, this shows MORE of the play area.
	ASPECT_COVERED, ## Scale the control so that the shorter side fits the bounding rectangle. The other side clips to this node's limits.[br]For SubViewports, this shows LESS of the play area.
}

## Stretch mode of children controls. See [enum StretchMode].
@export var stretch_mode : StretchMode = 0:
	set(v):
		stretch_mode = v
		queue_sort()

## If [code]true[/code], scale will only receive integer values.
## Good for scaling the gameplay viewport in a pixel-art game.
@export var integer_scale := false:
	set(v):
		integer_scale = v
		queue_sort()


func _notification(what : int):
	if what == NOTIFICATION_SORT_CHILDREN:
		for x in get_children():
			if x is Control:
				_scale_child(x)


func _scale_child(child : Control):
	var minsize := child.get_combined_minimum_size()
	var result_scale := size / minsize
	var result_offset := Vector2.ZERO
	match stretch_mode:
		StretchMode.ASPECT_CENTERED:
			if integer_scale: result_scale = result_scale.floor()
			result_scale = Vector2.ONE * min(result_scale.x, result_scale.y)

		StretchMode.ASPECT_COVERED:
			if integer_scale: result_scale = result_scale.ceil()
			result_scale = Vector2.ONE * max(result_scale.x, result_scale.y)
	
	var result_size := minsize * size / minsize / result_scale
	if result_size.x < minsize.x:
		result_offset.x = (result_size.x - minsize.x) * result_scale.x * 0.5

	if result_size.y < minsize.y:
		result_offset.y = (result_size.y - minsize.y) * result_scale.y * 0.5

	fit_child_in_rect(child, Rect2(result_offset, result_size))
	child.scale = result_scale
