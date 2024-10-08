@tool
class_name InterpolatedBoxContainer
extends InterpolatedContainer

## A container that displays children in a row or column, compacting them to fit width if too many, with a smooth repositioning feature.
##
## Handles children with the Expand size flag. [br]
## Control spacing by setting the theme's BoxContainer constants. [br]
## Provides optional drag-and-drop feature to reorder items via pointer. [br]
## [b]Note:[/b] users can only reorder/transfer children that have [member Control.mouse_filter] set to Stop. [br]
## [b]Note:[/b] this works with any [Control] type and does not require children to be [Draggable].


## Enable if the box should behave like a [VBoxContainer]. Otherwise, works like an [HBoxContainer].
@export var vertical := false:
	set(v):
		vertical = v
		queue_sort()
## If total child size exceeds this node's size, change child positions to fit inside this node. Otherwise, change this node's minimum size.
@export var compact_if_overflow := true:
	set(v):
		compact_if_overflow = v
		queue_sort()
## Enable reordering by using the mouse pointer.

var _separation := 0.0


func _sort_children():
	var child_count := get_child_count()
	_separation = get_theme_constant(&"separation", &"BoxContainer")

	var cur_child_minsize := Vector2.ZERO
	var cur_row_length := 0.0
	var widest_child := 0.0
	var cur_row_expand_count := 0
	var ordering_direction := Vector2.DOWN if vertical else Vector2.RIGHT
	for x in get_children():
		if !(x is Control && x.visible):
			continue

		var cur_child : Control = x
		cur_child_minsize = cur_child.get_combined_minimum_size()
		if vertical:
			cur_row_length += cur_child_minsize.y + _separation
			widest_child = maxf(cur_child_minsize.x, widest_child)
			if cur_child.size_flags_vertical & SIZE_EXPAND != 0:
				cur_row_expand_count += 1

		else:
			cur_row_length += cur_child_minsize.x + _separation
			widest_child = maxf(cur_child_minsize.y, widest_child)
			if cur_child.size_flags_horizontal & SIZE_EXPAND != 0:
				cur_row_expand_count += 1


	cur_row_length -= _separation
	var result_size := Vector2(widest_child, cur_row_length) if vertical else Vector2(cur_row_length, widest_child)
	_fit_children_row(result_size, cur_row_expand_count)

	if compact_if_overflow:
		custom_minimum_size = Vector2(widest_child, 0.0) if vertical else Vector2(0.0, widest_child)

	else:
		custom_minimum_size = result_size


func _fit_children_row(row_size : Vector2, expand_node_count : int):
	var cur_offset := 0.0
	if expand_node_count == 0:
		if vertical:
			if alignment == ItemAlignment.CENTER:
				cur_offset += (size.y - row_size.y) * 0.5

			if alignment == ItemAlignment.END:
				cur_offset += size.y - row_size.y

		else:
			if alignment == ItemAlignment.CENTER:
				cur_offset += (size.x - row_size.x) * 0.5

			if alignment == ItemAlignment.END:
				cur_offset += size.x - row_size.x

	var compact_factor := 1.0
	if vertical:
		if row_size.y > size.y:
			var last_child_length : float = get_child(get_child_count() - 1).get_combined_minimum_size().y
			compact_factor = (size.y - last_child_length) / (row_size.y - last_child_length)
			cur_offset = 0.0
			expand_node_count = 0

	else:
		if row_size.x > size.x:
			var last_child_length : float = get_child(get_child_count() - 1).get_combined_minimum_size().x
			compact_factor = (size.x - last_child_length) / (row_size.x - last_child_length)
			cur_offset = 0.0
			expand_node_count = 0

	for child in get_children():
		if !(child is Control && child.visible):
			continue

		var cur_child : Control = child
		var cur_child_width := 0.0
		if vertical:
			cur_child_width = cur_child.get_combined_minimum_size().y
			if expand_node_count != 0 && cur_child.size_flags_horizontal & SIZE_EXPAND != 0:
				cur_child_width += (size.y - row_size.y) / expand_node_count

		else:
			cur_child_width = cur_child.get_combined_minimum_size().x
			if expand_node_count != 0 && cur_child.size_flags_horizontal & SIZE_EXPAND != 0:
				cur_child_width += (size.x - row_size.x) / expand_node_count

		if _dragging_node == child:
			# Consider its size for other children, but don't move the dragged child.
			cur_offset += cur_child_width + _separation
			continue

		if vertical:
			fit_interpolated(child, Rect2(0.0, cur_offset * compact_factor, row_size.x, cur_child_width))

		else:
			fit_interpolated(child, Rect2(cur_offset * compact_factor, 0.0, cur_child_width, row_size.y))

		cur_offset += cur_child_width + _separation


func _insert_child_at_position(child : Control):
	var children := get_children()
	var child_former_index := child.get_index()
	for i in children.size():
		if !(children[i] is Control && children[i].visible):
			continue

		var cur_node : Control = children[i]
		if (
			(vertical && cur_node.position.y > child.position.y)
			|| (!vertical && cur_node.position.x > child.position.x)
			):
			var result_index := i if i < child_former_index else i - 1
			if result_index != child_former_index:
				move_child(child, result_index)
				order_changed.emit()

			return

	if child_former_index != children.size():
		move_child(child, children.size())
		order_changed.emit()
