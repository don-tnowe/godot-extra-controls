@tool
class_name Draggable
extends Container

## Draggable control. Can be resized by dragging the border, and constrained to only be movable within its parent Control.
##
## [b]Note:[/b] this container will only be grabbed if the mouse pointer does not overlap children with [member Control.mouse_filter] set to Stop. [br]
## [b]Note:[/b] this can be the child of any [Control], but it is not compatible with [InterpolatedContainer].

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
## Defines if this node can not be dragged or resized beyond the parent control's bounds. In [InterpolatedFreeContainer], this is forced.
@export var constrain_rect_to_parent := true

var _mouse_over := false
var _mouse_dragging := false
var _mouse_dragging_direction := Vector2i.ZERO
var _drag_initial_pos := Vector2.ZERO
var _size_buffered := Vector2.ZERO
var _affected_by_multi_selection : MultiSelection
var _affected_by_free_container : InterpolatedFreeContainer


func _init():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _enter_tree():
	update_configuration_warnings()
	_affected_by_free_container = null
	if get_parent() is InterpolatedFreeContainer:
		_affected_by_free_container = get_parent()

	# Force release the node; changing parents is rather buggy
	_handle_click(false)
	if get_parent() is InterpolatedContainer:
		get_parent().force_release()


func _get_configuration_warnings() -> PackedStringArray:
	if get_parent() is InterpolatedContainer && !(get_parent() is InterpolatedFreeContainer):
		return ["This Draggable is inside of an InterpolatedContainer! The two classes implement separate features, and are incompatible:\n- InterpolatedContainer can have children of any other Control type. Keep it if you need a container for nodes with a way to reorder them and transfer to other containers. \n- Draggable can have a parent of any other type. Keep it if you need free drag-and-drop on a 2D plane."]

	return []


func _draw():
	var used_drop_color := drop_color if (
			_affected_by_free_container == null || !_affected_by_free_container.drop_color_override_children
		) else _affected_by_free_container.drop_color

	if _mouse_dragging:
		var result_rect := get_rect_after_drop()
		result_rect.position -= position
		draw_rect(result_rect, used_drop_color)

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

		draw_rect(result_rect, used_drop_color)


func get_rect_after_drop() -> Rect2:
	var used_grid_snap := grid_snap if _affected_by_free_container == null else _affected_by_free_container.grid_snap
	var grid_snap_offset_cur := used_grid_snap * 0.5 - Vector2.ONE
	var result_position := position
	var result_size := size
	if used_grid_snap != Vector2.ZERO:
		if _mouse_dragging_direction != Vector2i.ZERO:
			result_position = (result_position - used_grid_snap * 0.5).snapped(used_grid_snap)

		else:
			result_position = result_position.snapped(used_grid_snap)

		if grid_snap_affects_resize:
			result_size = (size + grid_snap_offset_cur).snapped(used_grid_snap)

	var xform_basis := get_transform().translated(-position)
	var xformed_rect := (xform_basis * Rect2(Vector2.ZERO, result_size))
	var xformed_position := xformed_rect.position + result_position
	var xformed_size := xformed_rect.size
	if constrain_rect_to_parent || _affected_by_free_container != null:
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

			if xformed_position.x < 0.0:
				result_position -= xform_basis.affine_inverse() * Vector2(xformed_position.x, 0.0)

			if xformed_position.y < 0.0:
				result_position -= xform_basis.affine_inverse() * Vector2(0.0, xformed_position.y)

			if xformed_position.x > parent_size.x - xformed_size.x:
				result_position -= xform_basis.affine_inverse() * Vector2(xformed_position.x - (parent_size.x - xformed_size.x), 0.0)

			if xformed_position.y > parent_size.y - xformed_size.y:
				result_position -= xform_basis.affine_inverse() * Vector2(0.0, xformed_position.y - (parent_size.y - xformed_size.y))

	if !can_drag_horizontal:
		result_position.x = _drag_initial_pos.x

	if !can_drag_vertical:
		result_position.y = _drag_initial_pos.y

	return Rect2(result_position, result_size)


func _gui_input(event : InputEvent, called_by : Draggable = null):
	if event is InputEventMouseMotion:
		if _mouse_dragging:
			_universal_input(_mouse_dragging_direction, event.relative)
			if _affected_by_multi_selection != null:
				var own_xform_inv := get_global_transform().affine_inverse()
				for x in _affected_by_multi_selection._selected_nodes:
					if !(x is Draggable) || x == self:
						continue

					if _mouse_dragging_direction == Vector2i.ZERO:
						x._universal_input(_mouse_dragging_direction, (x.get_global_transform() * own_xform_inv).affine_inverse().basis_xform(event.relative))

					else:
						x._universal_input(_mouse_dragging_direction, event.relative)

				_affected_by_multi_selection.queue_redraw()

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
		if _affected_by_multi_selection == null:
			_handle_click(event.pressed)
			return

		for x in _affected_by_multi_selection._selected_nodes:
			if !(x is Draggable):
				continue

			x._handle_click(event.pressed)


func _universal_input(input_resize_direction : Vector2, drag_amount : Vector2):
	var is_diagonal := absi(input_resize_direction.x) + absi(input_resize_direction.y) == 2
	if input_resize_direction.x != 0:
		_size_buffered.x += drag_amount.x * input_resize_direction.x

	if input_resize_direction.y != 0:
		_size_buffered.y += drag_amount.y * input_resize_direction.y

	var pos_change := Vector2.ZERO
	if (is_diagonal || input_resize_direction.x == 0) && input_resize_direction.y <= 0 && _size_buffered.y >= _get_resize_minimum_size().y:
		pos_change.y = drag_amount.y

	if (is_diagonal || input_resize_direction.y == 0) && input_resize_direction.x <= 0 && _size_buffered.x >= _get_resize_minimum_size().x:
		pos_change.x = drag_amount.x

	position += get_transform().basis_xform(pos_change)
	size = _size_buffered
	queue_redraw()


func _handle_click(button_pressed : bool):
	_mouse_dragging = button_pressed
	if !_mouse_dragging:
		var result_rect := get_rect_after_drop()
		if _affected_by_free_container == null:
			position = result_rect.position
			size = result_rect.size

		drag_ended.emit()

	_size_buffered = size
	_drag_initial_pos = position
	queue_redraw()


func _on_mouse_entered():
	_mouse_over = true
	queue_redraw()


func _on_mouse_exited():
	_mouse_over = false
	queue_redraw()


func _get_resize_minimum_size() -> Vector2:
	var result_size := Vector2(0.0, 0.0)
	for x in get_children(true):
		if x is Control:
			result_size.x = maxf(result_size.x, x.get_combined_minimum_size().x)
			result_size.y = maxf(result_size.y, x.get_combined_minimum_size().y)

	if resize_margin_offset_children:
		result_size += resize_margin + resize_margin

	return Vector2(
		maxf(result_size.x, custom_minimum_size.x),
		maxf(result_size.y, custom_minimum_size.y),
	)


func _get_minimum_size() -> Vector2:
	return _get_resize_minimum_size()


func _notification(what : int):
	if what == NOTIFICATION_SORT_CHILDREN:
		var result_child_pos := resize_margin if resize_margin_offset_children else Vector2.ZERO
		for x in get_children(true):
			if x is Control:
				x.position = result_child_pos
				x.size = size - result_child_pos * 2.0
