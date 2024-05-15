@tool
class_name InterpolatedFlowContainer
extends Container

## A container that displays children in a row, wrapping overflow around or squishing them to fit width, with an additional smooth repositioning feature.

enum ItemAlignment {
	BEGIN,
	CENTER,
	END,
}

@export var alignment : ItemAlignment:
	set(v):
		alignment = v
		queue_sort()
## Time it takes for children to move into position.
@export var move_time := 0.5
## Easing factor to interpolate children to their target position. 1 is linear, [0, 1] is Ease Out, 1 and higher is Ease In, below -1 is Ease In-Out.
@export var easing_factor := 0.5

var _row_start_child_index : Array[int] = [0]
var _separation := Vector2()
var _total_row_height := 0.0

var _children_xforms_start : Array[Transform2D] = []
var _children_xforms_end : Array[Transform2D] = []
var _children_sizes_start : Array[Vector2]= []
var _children_sizes_end : Array[Vector2]= []
var _interp_progress_factor := 0.0
var _dragging_node : Control


func start_drag(of_node : Control):
	_dragging_node
	set_process_input(true)


func end_drag():
	_children_xforms_start[_dragging_node.get_index()].origin = _dragging_node.global_position - _dragging_node.get_global_transform().basis_xform(_dragging_node.size)
	_dragging_node = null
	set_process_input(false)


func parent_queue_sort():
	if is_inside_tree():
		get_parent().queue_sort()

	queue_sort()


func _process(delta : float):
	if move_time == 0.0:
		return

	_interp_progress_factor += 1.0 / move_time * delta
	var progress_eased := ease(_interp_progress_factor, easing_factor)
	var children := get_children()
	for i in children.size():
		if !(children[i] is Control && children[i] != _dragging_node):
			continue

		var cur_child : Control = children[i]
		var child_xform := _children_xforms_start[i].interpolate_with(_children_xforms_end[i], progress_eased)
		cur_child.size = _children_sizes_start[i].lerp(_children_sizes_end[i], progress_eased)
		cur_child.position = child_xform.origin - child_xform.basis_xform(cur_child.size * 0.5)
		cur_child.rotation = child_xform.get_rotation()
		cur_child.scale = child_xform.get_scale()

	if _interp_progress_factor >= 1.0:
		set_process(false)


func _input(event : InputEvent):
	if event is InputEventMouseButton && !event.pressed:
		end_drag()


func _get_minimum_size():
	var found_minsize := 0.0
	for x in get_children():
		if !(x is Control && x.visible): continue
		var x_minsize : Vector2 = x.get_combined_minimum_size()
		found_minsize = maxf(found_minsize, x_minsize.x)

	return Vector2(found_minsize, _total_row_height)


func _notification(what : int):
	if what == NOTIFICATION_SORT_CHILDREN:
		_sort_children()


func _sort_children():
	var child_count := get_child_count()
	_children_xforms_start.resize(child_count)
	_children_sizes_start.resize(child_count)
	_children_xforms_end.resize(child_count)
	_children_sizes_end.resize(child_count)
	_separation = Vector2(get_theme_constant(&"h_separation", &"FlowContainer"), get_theme_constant(&"v_separation", &"FlowContainer"))

	var cur_row := 0
	var cur_row_top_offset := 0.0
	var cur_row_width := 0.0
	var cur_row_height := 0.0
	var cur_row_expand_count := 0
	var children_in_row := 0
	var cur_minsize := Vector2.ZERO
	for x in get_children():
		if !(x is Control && x.visible):
			continue

		var cur_child : Control = x
		cur_minsize = cur_child.get_combined_minimum_size()
		cur_row_width += cur_minsize.x
		if cur_row_width > size.x:
			cur_row += 1
			cur_row_width -= cur_minsize.x
			_row_start_child_index.resize(cur_row + 1)
			_row_start_child_index[cur_row] = x.get_index()

			_fit_children_row(
				_row_start_child_index[cur_row - 1],
				_row_start_child_index[cur_row],
				cur_row_top_offset,
				Vector2(cur_row_width, cur_row_height),
				cur_row_expand_count,
			)
			cur_row_top_offset += cur_row_height + _separation.y
			cur_row_height = 0.0
			cur_row_width = cur_minsize.x - _separation.x
			cur_row_expand_count = 0
			children_in_row = 0

		children_in_row += 1
		cur_row_width += _separation.x
		cur_row_height = maxf(cur_row_height, cur_minsize.y)
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
	_interp_progress_factor = 0.0
	set_process(true)


func _fit_children_row(start_child : int, end_child : int, row_top_offset : float, row_size : Vector2, expand_node_count : int):
	var cur_offset := 0.0
	if expand_node_count == 0:
		if alignment == ItemAlignment.CENTER:
			cur_offset += (size.x - row_size.x) * 0.5

		if alignment == ItemAlignment.END:
			cur_offset += size.x - row_size.x

	for i in end_child - start_child:
		var child_index := start_child + i
		var child_testing := get_child(child_index)
		if !(child_testing is Control && child_testing.visible):
			continue

		var cur_child : Control = child_testing
		var cur_child_width := cur_child.get_combined_minimum_size().x
		if cur_child.size_flags_horizontal & SIZE_EXPAND != 0:
			cur_child_width += (size.x - row_size.x) / expand_node_count

		var child_start_xform := cur_child.get_global_transform()
		child_start_xform.origin += child_start_xform.basis_xform(cur_child.size * 0.5)
		_children_xforms_start[child_index] = get_global_transform().affine_inverse() * child_start_xform
		_children_sizes_start[child_index] = cur_child.size

		fit_child_in_rect(cur_child, Rect2(cur_offset, row_top_offset, cur_child_width, row_size.y))
		_children_xforms_end[child_index] = Transform2D(Vector2(1, 0), Vector2(0, 1), cur_child.position + cur_child.size * 0.5)
		_children_sizes_end[child_index] = cur_child.size

		cur_offset += cur_child_width + _separation.x
