@tool
class_name Draggable
extends Container

## Draggable control. Can be resized by dragging the border, and constrained to only be movable within its parent Control.

## Emitted when the mouse button is released after the node is moved or resized.
signal drag_ended()

## Enable so the node can be dragged and resized horizontally (X axis)
@export var can_drag_horizontal := true
## Enable so the node can be dragged and resized vertically (Y axis)
@export var can_drag_vertical := true
## Size of the grid to align the node with when the node is moved or resized.
@export var grid_snap := Vector2.ZERO
## Width of the resize border. If the mouse pointer is on this border, the node will be resized, otherwise it will be moved.
## [br] Set to 0 on either axis to prevent resizing on that axis.
@export var resize_margin := Vector2.ZERO:
	set(v):
		resize_margin = v
		queue_redraw()
		queue_sort()
## Color of the rectangle indicating the node's drop position and the selected side of the [member resize_margin].
@export var drop_color := Color(0.5, 0.5, 0.5, 0.75)

## Defines if this node's children are shrunk by the [member resize_margin]'s size.
@export var resize_margin_offset_children := true:
	set(v):
		resize_margin_offset_children = v
		queue_redraw()
		queue_sort()
## Defines if this node can only be resized to multiples of [member grid_snap].
@export var grid_snap_affects_resize := true
## Defines if this node can not be dragged or resized beyond the parent control's bounds.
@export var constrain_rect_to_parent := true

var _mouse_over := false
var _mouse_dragging := false
var _mouse_dragging_direction := Vector2i.ZERO
var _drag_initial_pos := Vector2.ZERO
var _size_buffered := Vector2.ZERO


func _init():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _draw():
	if _mouse_dragging:
		var result_rect := get_rect_after_drop()
		result_rect.position -= position
		draw_rect(result_rect, drop_color)

	elif _mouse_over:
		var result_rect := Rect2(Vector2.ZERO, resize_margin)
		if _mouse_dragging_direction.x == 1:
			result_rect.position.x = size.x - resize_margin.x

		if _mouse_dragging_direction.y == 0:
			result_rect.size.y = size.y

		if _mouse_dragging_direction.y == 1:
			result_rect.position.y = size.y - resize_margin.y

		if _mouse_dragging_direction.x == 0:
			result_rect.size.x = size.x

		draw_rect(result_rect, drop_color)


func get_rect_after_drop() -> Rect2:
	var grid_snap_offset_cur := grid_snap * 0.5 - Vector2.ONE
	var result_position := position
	var result_size := size
	if grid_snap != Vector2.ZERO:
		if _mouse_dragging_direction != Vector2i.ZERO:
			result_position = (result_position - grid_snap * 0.5).snapped(grid_snap)

		else:
			result_position = result_position.snapped(grid_snap)

		if grid_snap_affects_resize:
			result_size = (size + grid_snap_offset_cur).snapped(grid_snap)

	if constrain_rect_to_parent:
		var parent := get_parent()
		if parent is Control:
			var parent_size : Vector2 = get_parent().size
			if size.x > parent_size.x:
				if _mouse_dragging_direction.x < 0:
					result_position.x = 0.0

				result_size.x = parent_size.x

			if size.y > parent_size.y:
				if _mouse_dragging_direction.y < 0:
					result_position.y = 0.0

				result_size.y = parent_size.y

			if result_position.x < 0.0:
				result_position.x = 0.0

			if result_position.y < 0.0:
				result_position.y = 0.0

			if result_position.x > parent_size.x - result_size.x:
				result_position.x = parent_size.x - result_size.x

			if result_position.y > parent_size.y - result_size.y:
				result_position.y = parent_size.y - result_size.y

	if !can_drag_horizontal:
		result_position.x = _drag_initial_pos.x

	if !can_drag_vertical:
		result_position.y = _drag_initial_pos.y

	return Rect2(result_position, result_size)


func _gui_input(event : InputEvent):
	if event is InputEventMouseMotion:
		if _mouse_dragging:
			var is_diagonal := absi(_mouse_dragging_direction.x) + absi(_mouse_dragging_direction.y) == 2
			if _mouse_dragging_direction.x != 0:
				_size_buffered.x += event.relative.x * _mouse_dragging_direction.x

			if _mouse_dragging_direction.y != 0:
				_size_buffered.y += event.relative.y * _mouse_dragging_direction.y

			var pos_change := Vector2.ZERO
			if (is_diagonal || _mouse_dragging_direction.x == 0) && _mouse_dragging_direction.y <= 0 && _size_buffered.y >= get_combined_minimum_size().y:
				pos_change.y = event.relative.y

			if (is_diagonal || _mouse_dragging_direction.y == 0) && _mouse_dragging_direction.x <= 0 && _size_buffered.x >= get_combined_minimum_size().x:
				pos_change.x = event.relative.x

			position += get_transform().basis_xform(pos_change)
			size = _size_buffered
			queue_redraw()

		elif resize_margin == Vector2.ZERO:
			_mouse_dragging_direction = Vector2i.ZERO
			mouse_default_cursor_shape = CURSOR_ARROW

		else:
			_mouse_dragging_direction.x = (
				-1
				if event.position.x < resize_margin.x
				else 0
				if event.position.x <= size.x - resize_margin.x
				else 1
			)
			_mouse_dragging_direction.y = (
				-1
				if event.position.y < resize_margin.y
				else 0
				if event.position.y <= size.y - resize_margin.y
				else 1
			)
			match _mouse_dragging_direction.y + _mouse_dragging_direction.y + _mouse_dragging_direction.y + _mouse_dragging_direction.x:
				-4: mouse_default_cursor_shape = CURSOR_FDIAGSIZE
				-3: mouse_default_cursor_shape = CURSOR_VSIZE
				-2: mouse_default_cursor_shape = CURSOR_BDIAGSIZE
				-1: mouse_default_cursor_shape = CURSOR_HSIZE
				0:  mouse_default_cursor_shape = CURSOR_ARROW
				+1: mouse_default_cursor_shape = CURSOR_HSIZE
				+2: mouse_default_cursor_shape = CURSOR_BDIAGSIZE
				+3: mouse_default_cursor_shape = CURSOR_VSIZE
				+4: mouse_default_cursor_shape = CURSOR_FDIAGSIZE

			Input.set_default_cursor_shape(0)
			queue_redraw()

	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_dragging = event.pressed
		_size_buffered = size
		if !_mouse_dragging:
			var result_rect := get_rect_after_drop()
			position = result_rect.position
			size = result_rect.size
			drag_ended.emit()

		_drag_initial_pos = position
		queue_redraw()


func _on_mouse_entered():
	_mouse_over = true
	queue_redraw()


func _on_mouse_exited():
	_mouse_over = false
	queue_redraw()


func _notification(what : int):
	if what == NOTIFICATION_SORT_CHILDREN:
		var result_child_pos := resize_margin if resize_margin_offset_children else Vector2.ZERO
		for x in get_children(true):
			if x is Control:
				x.position = result_child_pos
				x.size = size - result_child_pos * 2.0
