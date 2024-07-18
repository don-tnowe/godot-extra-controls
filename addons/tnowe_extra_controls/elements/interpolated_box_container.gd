@tool
class_name InterpolatedBoxContainer
extends Container

## A container that displays children in a row or column, compacting them to fit width if too many, with a smooth repositioning feature.
##
## Provides optional drag-and-drop feature to reorder items via pointer. [br]
## Handles children with the Expand size flag. Sort of. [br]
## Control spacing by setting the theme's BoxContainer constants.

## Emitted when a node was dragged to be rearranged via [member allow_drag_reorder], every time the child order changes.
signal order_changed()

enum ItemAlignment {
	BEGIN,
	CENTER,
	END,
}

## Alignment of the items in the container, if their total size does not go beyond this node's size.
@export var alignment : ItemAlignment:
	set(v):
		alignment = v
		queue_sort()
## Time it takes for children to move into position.
@export var move_time := 0.5
## Easing factor to interpolate children to their target position. 1 is linear, [0, 1] is Ease Out, 1 and higher is Ease In, below -1 is Ease In-Out.
@export var easing_factor := 0.5
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
@export var allow_drag_reorder := true
## Enable dragging children to be placed in other InterpolatedBoxContainers, by using the mouse pointer.
@export var allow_drag_transfer := false
## Enable nodes to be placed here from other InterpolatedBoxContainers, by using the mouse pointer.
@export var allow_drag_insert := false:
	set(v):
		allow_drag_insert = v
		if v: _all_boxes.append(self)
		else: _all_boxes.erase(self)
## Expression to test for [member allow_drag_insert] to know if a node can be inserted, executed on the node. If [code]true[/code], the node will be inserted.[br]
## The [code]from[/code] parameter will be a reference to the node it's dragged from, and [code]into[/code] will be this node. [br][br]
## For example, expression [code](get_class() == "Button" and into.has_method(&"insert_button_node"))[/code] tests if the dragged node is [code]Button[/code] and the destination has method[code]insert_button_node[/code]. [br][br]
## [b]Note: [/b] Some operators are unsopported in expressions, such as [code]is[/code] and ternary [code]if[/code]. Consider calling node's script methods after checking [code]has_method[/code].
@export var drag_insert_condition := "":
	set(v):
		drag_insert_condition = v
		if v.is_empty():
			_drag_insert_condition_exp = null

		else:
			_drag_insert_condition_exp = Expression.new()
			_drag_insert_condition_exp.parse(v, ["from", "into"])
## Expression to execute on the node after insertion succeeds. Same parameters as [member drag_insert_condition].
@export var drag_insert_call_on_success := ""

static var _all_boxes : Array[InterpolatedBoxContainer] = []

var _separation := 0.0
var _dragging_node : Control

var _children_xforms_start : Array[Transform2D] = []
var _children_xforms_end : Array[Transform2D] = []
var _children_sizes_start : Array[Vector2] = []
var _children_sizes_end : Array[Vector2] = []
var _interp_progress_factor := 0.0
var _skip_next_reorder := false
var _drag_insert_condition_exp : Expression


func parent_queue_sort():
	if is_inside_tree():
		get_parent().queue_sort()

	queue_sort()


func _enter_tree():
	child_entered_tree.connect(_on_child_entered_tree)
	child_exiting_tree.connect(_on_child_exiting_tree)
	set_process_input(false)


func _exit_tree():
	child_entered_tree.disconnect(_on_child_entered_tree)
	child_exiting_tree.disconnect(_on_child_exiting_tree)


func _process(delta : float):
	if move_time == 0.0:
		set_process(false)
		return

	_skip_next_reorder = false
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


func _notification(what : int):
	if what == NOTIFICATION_SORT_CHILDREN:
		_sort_children()


func _sort_children():
	if _skip_next_reorder:
		# Skip sort if custom_minimum_size changed when sorting children.
		# Prevents animation from not playing. _skip_next_reorder is reset next _process()
		return

	var child_count := get_child_count()
	_children_xforms_start.resize(child_count)
	_children_sizes_start.resize(child_count)
	_children_xforms_end.resize(child_count)
	_children_sizes_end.resize(child_count)
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

		else:
			cur_row_length += cur_child_minsize.x + _separation
			widest_child = maxf(cur_child_minsize.y, widest_child)

		if cur_child.size_flags_horizontal & SIZE_EXPAND != 0:
			cur_row_expand_count += 1

	cur_row_length -= _separation
	var result_size := Vector2(widest_child, cur_row_length) if vertical else Vector2(cur_row_length, widest_child)
	_fit_children_row(result_size, cur_row_expand_count)

	_interp_progress_factor = 0.0
	_skip_next_reorder = true
	if compact_if_overflow:
		custom_minimum_size = Vector2(widest_child, 0.0) if vertical else Vector2(0.0, widest_child)

	else:
		custom_minimum_size = result_size

	set_process(true)


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


	_interp_progress_factor = 0.0
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

	for child_index in get_child_count():
		var child_testing := get_child(child_index)
		if !(child_testing is Control && child_testing.visible):
			continue

		var cur_child : Control = child_testing
		var cur_child_width := 0.0
		if vertical:
			cur_child_width = cur_child.get_combined_minimum_size().y
			if expand_node_count != 0 && cur_child.size_flags_horizontal & SIZE_EXPAND != 0:
				cur_child_width += (size.y - row_size.y) / expand_node_count

		else:
			cur_child_width = cur_child.get_combined_minimum_size().x
			if expand_node_count != 0 && cur_child.size_flags_horizontal & SIZE_EXPAND != 0:
				cur_child_width += (size.x - row_size.x) / expand_node_count

		if _dragging_node == child_testing:
			# Consider its size for other children, but don't move the dragged child.
			cur_offset += cur_child_width + _separation
			continue

		var child_start_xform := cur_child.get_global_transform()
		child_start_xform.origin += child_start_xform.basis_xform(cur_child.size * 0.5)
		_children_xforms_start[child_index] = get_global_transform().affine_inverse() * child_start_xform
		_children_sizes_start[child_index] = cur_child.size

		if vertical:
			fit_child_in_rect(cur_child, Rect2(0.0, cur_offset * compact_factor, row_size.x, cur_child_width))

		else:
			fit_child_in_rect(cur_child, Rect2(cur_offset * compact_factor, 0.0, cur_child_width, row_size.y))

		_children_xforms_end[child_index] = Transform2D(Vector2(1, 0), Vector2(0, 1), cur_child.position + cur_child.size * 0.5)
		_children_sizes_end[child_index] = cur_child.size

		cur_offset += cur_child_width + _separation


func _insert_child_at_position(child : Control):
	var children := get_children()
	var child_former_index := child.get_index()
	for i in children.size():
		if !(children[i] is Control && children[i].visible):
			continue

		var cur_node : Control = children[i]
		var result_index := i if i < child_former_index else i - 1
		if (vertical && cur_node.position.y > child.position.y) || (!vertical && cur_node.position.x > child.position.x): 
			if result_index != child_former_index:
				move_child(child, result_index)
				order_changed.emit()

			return


	move_child(child, children.size())


func _insert_child_in_other(child : Control, mouse_global_position : Vector2):
	for x in _all_boxes:
		if !x.allow_drag_insert || !Rect2(Vector2.ZERO, x.size).has_point(x.get_global_transform().affine_inverse() * mouse_global_position):
			continue

		if x._drag_insert_condition_exp.execute([self, x], child) != true:
			continue

		child.reparent(x)
		x._dragging_node = child
		x.set_process_input(true)
		set_process_input(false)
		if !drag_insert_call_on_success.is_empty():
			# Can be compiled on the spot - not called as often.
			var success_expr := Expression.new()
			success_expr.parse(drag_insert_call_on_success)
			success_expr.execute([self, x], child)

		break


func _on_child_entered_tree(x : Node):
	if x is Control:
		x.gui_input.connect(_child_gui_input.bind(x))


func _on_child_exiting_tree(x : Node):
	if x is Control:
		x.gui_input.disconnect(_child_gui_input)


func _child_gui_input(event : InputEvent, child : Control):
	if !allow_drag_reorder:
		return

	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT && event.pressed:
		_dragging_node = child
		set_process_input(true)


func _input(event : InputEvent):
	if event is InputEventMouseMotion && _dragging_node != null:
		_dragging_node.global_position += event.relative
		_insert_child_at_position(_dragging_node)
		if allow_drag_transfer && !Rect2(Vector2.ZERO, size).has_point(get_global_transform().affine_inverse() * event.global_position):
			_insert_child_in_other(_dragging_node, event.global_position)

	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT && !event.pressed:
		_dragging_node = null
		queue_sort()
		set_process_input(false)
