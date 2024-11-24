@tool
class_name InterpolatedFreeContainer
extends InterpolatedContainer

## A container that does not impose positioning rules. The user can freely move children around this control's rect, with a smooth repositioning feature for out-of-bounds drops.
##
## Supports [Draggable] as children to allow resizing. In this case, overrides child [member grid_snap]. [br]
## Unlike a plain [Control] with [Draggable] children, allows transferring children between [InterpolatedContainer]s if relevant properties are set.[br]
## [b]Note:[/b] users can only move/transfer children that have [member Control.mouse_filter] set to Stop. [br]

## Size of the grid to align children with when moved or resized.
@export var grid_snap := Vector2.ZERO
## Color of the rectangle indicating a child's drop position.
@export var drop_color := Color(0.5, 0.5, 0.5, 0.75)
## Overrides preview color of child [Draggable] nodes.
@export var drop_color_override_children := false


func _draw():
	if _dragging_node == null || _dragging_node.get_parent() != self:
		return

	if !(_dragging_node is Draggable):
		var result_rect := get_rect_after_drop(_dragging_node)
		draw_rect(result_rect, drop_color)

	if _affected_by_multi_selection == null:
		return

	for x in _affected_by_multi_selection._selected_nodes:
		if !(x is Draggable):
			var result_rect := get_rect_after_drop(x)
			result_rect.position -= position
			draw_rect(result_rect, drop_color)


func _sort_children():
	for child in get_children():
		if child is Control && child != _dragging_node:
			fit_interpolated(child, get_rect_after_drop(child))

	queue_redraw()


func get_rect_after_drop(of_node : Control) -> Rect2:
	if of_node is Draggable:
		return of_node.get_rect_after_drop()

	var grid_snap_offset_cur := grid_snap * 0.5 - Vector2.ONE
	var result_position := of_node.position
	var result_size := of_node.size
	if grid_snap != Vector2.ZERO:
		result_position = result_position.snapped(grid_snap)

	var xform_basis := of_node.get_transform().translated(-of_node.position)
	var xformed_rect := (xform_basis * Rect2(Vector2.ZERO, result_size))
	var xformed_position := xformed_rect.position + result_position
	var xformed_child_size := xformed_rect.size
	if xformed_position.x < 0.0:
		result_position -= xform_basis.affine_inverse() * Vector2(xformed_position.x, 0.0)

	if xformed_position.y < 0.0:
		result_position -= xform_basis.affine_inverse() * Vector2(0.0, xformed_position.y)

	if xformed_position.x > size.x - xformed_child_size.x:
		result_position -= xform_basis.affine_inverse() * Vector2(xformed_position.x - (size.x - xformed_child_size.x), 0.0)

	if xformed_position.y > size.y - xformed_child_size.y:
		result_position -= xform_basis.affine_inverse() * Vector2(0.0, xformed_position.y - (size.y - xformed_child_size.y))

	return Rect2(result_position, result_size)


func _input(event : InputEvent):
	if event is InputEventMouse:
		queue_redraw()

	super(event)
