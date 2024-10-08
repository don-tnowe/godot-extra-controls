@tool
class_name InterpolatedFlowContainer
extends InterpolatedContainer

## A container that displays children in a row, wrapping overflow around, with an additional smooth repositioning feature.
##
## Handles children with the Expand size flag. [br]
## Control spacing by setting the theme's FlowContainer constants. [br]
## Provides optional drag-and-drop feature to reorder items via pointer. [br]
## [b]Note:[/b] users can only reorder/transfer children that have [member Control.mouse_filter] set to Stop. [br]
## [b]Note:[/b] this works with any [Control] type and does not require children to be [Draggable].

var _row_start_child_index : Array[int] = [0]
var _row_tops : Array[float] = [0]
var _separation := Vector2()
var _total_row_height := 0.0


func _sort_children():
	var child_count := get_child_count()
	_separation = Vector2(get_theme_constant(&"h_separation", &"FlowContainer"), get_theme_constant(&"v_separation", &"FlowContainer"))
	_row_start_child_index.resize(1)
	_row_tops.resize(1)

	var cur_row := 0
	var cur_row_top_offset := 0.0
	var cur_row_width := 0.0
	var cur_row_height := 0.0
	var cur_row_expand_count := 0
	var children_in_row := 0
	var cur_child_minsize := Vector2.ZERO
	var largest_child := 0.0
	for x in get_children():
		if !(x is Control && x.visible):
			continue

		var cur_child : Control = x
		cur_child_minsize = cur_child.get_combined_minimum_size()
		cur_row_width += cur_child_minsize.x
		if cur_row_width > size.x:
			cur_row += 1
			cur_row_width -= cur_child_minsize.x
			_row_start_child_index.append(x.get_index())

			_fit_children_row(
				_row_start_child_index[cur_row - 1],
				_row_start_child_index[cur_row],
				cur_row_top_offset,
				Vector2(cur_row_width, cur_row_height),
				cur_row_expand_count,
			)
			cur_row_top_offset += cur_row_height + _separation.y
			cur_row_height = 0.0
			cur_row_width = cur_child_minsize.x
			cur_row_expand_count = 0
			children_in_row = 0

			_row_tops.append(cur_row_top_offset)

		children_in_row += 1
		cur_row_width += _separation.x
		cur_row_height = maxf(cur_row_height, cur_child_minsize.y)
		largest_child = maxf(largest_child, cur_child_minsize.x)
		if cur_child.size_flags_horizontal & SIZE_EXPAND != 0:
			cur_row_expand_count += 1

	if children_in_row > 0:
		_fit_children_row(
			_row_start_child_index[cur_row],
			child_count,
			cur_row_top_offset,
			Vector2(cur_row_width, cur_row_height),
			cur_row_expand_count,
		)

	_total_row_height = cur_row_top_offset + (cur_row_height if children_in_row > 0 else 0.0)
	_row_tops.append(_total_row_height)
	_row_start_child_index.append(get_child_count())
	custom_minimum_size = Vector2(largest_child, _total_row_height)


func _fit_children_row(start_child : int, end_child : int, row_top_offset : float, row_size : Vector2, expand_node_count : int):
	var cur_offset := 0.0
	if expand_node_count == 0:
		if alignment == ItemAlignment.CENTER:
			cur_offset += (size.x - row_size.x + _separation.x) * 0.5

		if alignment == ItemAlignment.END:
			cur_offset += size.x - row_size.x + _separation.x

	for i in end_child - start_child:
		var child_index := start_child + i
		var child_testing := get_child(child_index)
		if !(child_testing is Control && child_testing.visible):
			continue

		var cur_child : Control = child_testing
		var cur_child_width := cur_child.get_combined_minimum_size().x
		if cur_child.size_flags_horizontal & SIZE_EXPAND != 0:
			cur_child_width += (size.x - row_size.x) / expand_node_count

		if _dragging_node == child_testing:
			# Consider its size for other children, but don't move the dragged child.
			cur_offset += cur_child_width + _separation.x
			continue

		fit_interpolated(cur_child, Rect2(cur_offset, row_top_offset, cur_child_width, row_size.y))
		cur_offset += cur_child_width + _separation.x


func _insert_child_at_position(child : Control):
	var child_former_index := child.get_index()
	var result_row := -1
	var row_change_offset := 0
	for i in _row_tops.size() - 1:
		if lerp(_row_tops[i], _row_tops[i + 1], 0.5) > child.position.y:
			if _row_start_child_index[i] > child_former_index:
				row_change_offset = -1

			result_row = i
			break

	var children := get_children()
	if result_row == -1:
		result_row = _row_tops.size() - 2

	for i in _row_start_child_index[result_row + 1] - _row_start_child_index[result_row]:
		i += _row_start_child_index[result_row]
		if children.size() <= i:
			break

		if !(children[i] is Control && children[i].visible):
			continue

		var cur_node : Control = children[i]
		var result_index := (i if i <= child_former_index else i - 1) - row_change_offset
		if _children_xforms_end[i].origin.x - child.size.x * 0.5 > child.position.x:
			if result_index != child_former_index:
				move_child(child, minf(result_index, children.size()))
				order_changed.emit()

			return

	var result_index := _row_start_child_index[result_row + 1]
	if _row_start_child_index[result_row] < child_former_index:
		result_index -= 1

	if child_former_index != result_index:
		move_child(child, minf(result_index, children.size()))
		order_changed.emit()
