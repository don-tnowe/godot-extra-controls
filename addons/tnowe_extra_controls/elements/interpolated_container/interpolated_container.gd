@tool
class_name InterpolatedContainer
extends Container

## Base class for containers that, when children inserted, animate their movement toward their target position.
##
## Provides optional drag-and-drop feature to reorder items via pointer. [br]
## [b]Note:[/b] users can only reorder/transfer children that have [member Control.mouse_filter] set to Stop. [br]
## [b]Note:[/b] this works with any [Control] type and does not require children to be [Draggable].

## Emitted when a node was dragged to be rearranged via [member allow_drag_reorder], every time the child order changes.
signal order_changed()
## Emitted if [member allow_drag_reorder] enabled, when a node was grabbed to be rearranged, once.
signal drag_started(node : Control)
## Emitted if [member allow_drag_reorder] enabled, when a node was placed down after dragging, once. [br]
## [b]Note:[/b] if transfered into another container, will be emitted by that container.
signal drag_ended(node : Control)
## Emitted if [member allow_drag_reorder] enabled, every time a node is moved by the mouse while being dragged.
signal drag_moved(node : Control)
## Emitted if [member allow_drag_transfer] enabled, once a node is transfered to another container by being dragged.
signal drag_transfered_out(node : Control, into : InterpolatedContainer)
## Emitted if [member allow_drag_insert] enabled, once a node is transfered out of another container by being dragged.
signal drag_transfered_in(node : Control, from : InterpolatedContainer)

## Child alignment enum.
enum ItemAlignment {
	BEGIN,
	CENTER,
	END,
}

## Alignment of the items in the container, when behaviours such as Expand Sizing and Compaction are not active.
@export var alignment : ItemAlignment:
	set(v):
		alignment = v
		queue_sort()
## Time it takes for children to move into position.
@export var move_time := 0.5
## Easing factor to interpolate children to their target position. 1 is linear, [0, 1] is Ease Out, 1 and higher is Ease In, below -1 is Ease In-Out.
@export var easing_factor := 0.5

@export_group("Drag and Drop")
@export var allow_drag_reorder := true
## Enable dragging children to be placed in other InterpolatedBoxContainers, by using the mouse pointer.
@export var allow_drag_transfer := false
## Enable nodes to be placed here from other InterpolatedBoxContainers, by using the mouse pointer.
@export var allow_drag_insert := false:
	set(v):
		allow_drag_insert = v
		if is_inside_tree():
			if v: _all_boxes.append(self)
			else: _all_boxes.erase(self)
## If the child count matches this, new children cannot be added through [member allow_drag_insert]. Does not prevent other means of adding children.[br]
## Set to [code]-1[/code] to remove the limit. [br]
## This is equivalent to [member drag_insert_condition] set to [code]into.get_child_count() < (count)[/code].
@export var drag_max_count := -1:
	set(v):
		if v < -1: v = -1
		drag_max_count = v
## Expression to test for [member allow_drag_insert] to know if a node can be inserted, executed on the node. If [code]true[/code], the node will be inserted.[br]
## The [code]from[/code] parameter will be a reference to the node it's dragged from, and [code]into[/code] will be this node. [br][br]
## For example, expression [code](get_class() == "Button" and into.has_method(&"insert_button_node"))[/code] tests if the dragged node is [code]Button[/code] and the destination has method[code]insert_button_node[/code]. [br][br]
## [b]Warning: [/b] Some operators are unsupported in expressions, such as [code]is[/code] and ternary [code]if[/code]. Consider calling node's script methods after checking [code]has_method[/code].
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

static var _all_boxes : Array[InterpolatedContainer] = []

var _drag_insert_condition_exp : Expression
var _dragging_node : Control
var _children_xforms_start : Array[Transform2D] = []
var _children_xforms_end : Array[Transform2D] = []
var _children_sizes_start : Array[Vector2] = []
var _children_sizes_end : Array[Vector2] = []
var _interp_progress_factor := 0.0
var _skip_next_reorder := false
var _affected_by_multi_selection : MultiSelection

## Override to define the behaviour for dragging a node via drag-and-drop rearrangement. [br]
## Should emit [signal order_changed] if the node's index was successfully changed.
func _insert_child_at_position(child : Control):
	pass

## Override to define positions of all child nodes. [br]
## Must change [member custom_minimum_size] to trigger sorting for parent container. [br]
## Must call [method fit_interpolated] on each child to set their position.
func _sort_children():
	pass

## Sets the target [Rect2] for a child. It will be smoothly animated to fit into that rect, adhering to [method Control.fit_child_in_rect] constraints.[br]
## Must be called on each child during [method _sort_children] to set their target position.
func fit_interpolated(child : Control, rect : Rect2):
	var child_index : int = child.get_index()
	var child_start_xform := child.get_global_transform()
	child_start_xform.origin += child_start_xform.basis_xform(child.size * 0.5)

	_children_xforms_start[child_index] = get_global_transform().affine_inverse() * child_start_xform
	_children_sizes_start[child_index] = child.size
	fit_child_in_rect(child, rect)
	_children_xforms_end[child_index] = Transform2D(Vector2(1, 0), Vector2(0, 1), child.position + child.size * 0.5)
	_children_sizes_end[child_index] = child.size

## Reorder children by a comparator function, similar to [method Array.sort_custom]. [br]
## Not to be confused with [method _sort_children], which is a method you must override in a script to define child positions and sizes when the container updates.
func sort_children_by_expression(expr : Callable):
	var children := get_children()
	children.sort_custom(expr)
	for i in children.size():
		if children[i].get_index() != i:
			children[i].get_parent().move_child(children[i], i)

## Forcibly releases children that are being dragged.
func force_release():
	drag_ended.emit(_dragging_node)
	_dragging_node = null
	queue_sort()
	set_process_input(false)


func _process(delta : float):
	if move_time == 0.0:
		set_process(false)
		return

	_skip_next_reorder = false
	_interp_progress_factor += 1.0 / move_time * delta
	var progress_eased := ease(_interp_progress_factor, easing_factor)
	var children := get_children()
	var dragged_node_pos := _dragging_node.global_position if _dragging_node != null else Vector2.ZERO
	for i in children.size():
		if !children[i] is Control:
			continue

		var cur_child : Control = children[i]
		var child_xform := _children_xforms_start[i].interpolate_with(_children_xforms_end[i], progress_eased)
		cur_child.size = _children_sizes_start[i].lerp(_children_sizes_end[i], progress_eased)
		cur_child.position = child_xform.origin - child_xform.basis_xform(cur_child.size * 0.5)
		cur_child.rotation = child_xform.get_rotation()
		cur_child.scale = child_xform.get_scale()

	if _dragging_node != null:
		_dragging_node.global_position = dragged_node_pos

	if _interp_progress_factor >= 1.0:
		set_process(false)

	if _affected_by_multi_selection != null:
		_affected_by_multi_selection.queue_redraw()


func _input(event : InputEvent):
	if _dragging_node == null:
		set_process_input(false)
		return

	if event is InputEventMouseMotion && _dragging_node != null:
		if !(_dragging_node is Draggable):
			_dragging_node.global_position += event.relative

		drag_moved.emit(_dragging_node)
		if allow_drag_reorder:
			_insert_child_at_position(_dragging_node)

		if allow_drag_transfer && !Rect2(Vector2.ZERO, size).has_point(get_global_transform().affine_inverse() * event.global_position):
			_insert_child_in_other(_dragging_node, event.global_position)

		if _affected_by_multi_selection == null:
			return

		for x in _affected_by_multi_selection._selected_nodes:
			if !is_instance_valid(x) || !(x is CanvasItem) || x == _dragging_node:
				# CanvasItem doesn't actually have a global position, but both subclasses do.
				continue

			if !(x is Draggable):
				x.global_position += event.relative

			drag_moved.emit(x)
			if allow_drag_transfer && !Rect2(Vector2.ZERO, size).has_point(get_global_transform().affine_inverse() * event.global_position):
				_insert_child_in_other(x, event.global_position)

			_affected_by_multi_selection.queue_redraw()

	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT && !event.pressed:
		drag_ended.emit(_dragging_node)
		_dragging_node = null
		queue_sort()
		set_process_input(false)


func _ready():
	set_process_input(false)
	child_entered_tree.connect(_on_child_entered_tree)
	child_exiting_tree.connect(_on_child_exiting_tree)
	for x in get_children():
		_on_child_entered_tree(x)


func _enter_tree():
	if allow_drag_insert:
		_all_boxes.append(self)


func _exit_tree():
	_all_boxes.erase(self)


func _notification(what : int):
	if what == NOTIFICATION_SORT_CHILDREN:
		if _skip_next_reorder:
			# Skip sort if custom_minimum_size changed when sorting children.
			# Prevents animation from not playing. _skip_next_reorder is reset next _process()
			return

		var child_count := get_child_count()
		_children_xforms_start.resize(child_count)
		_children_sizes_start.resize(child_count)
		_children_xforms_end.resize(child_count)
		_children_sizes_end.resize(child_count)
		_sort_children()
		_skip_next_reorder = true
		_interp_progress_factor = 0.0
		set_process(true)


func _insert_child_in_other(child : Control, mouse_global_position : Vector2):
	for x in _all_boxes:
		if !x.allow_drag_insert || !Rect2(Vector2.ZERO, x.size).has_point(x.get_global_transform().affine_inverse() * mouse_global_position):
			continue

		if x.drag_max_count > -1 && x.get_child_count() >= x.drag_max_count:
			continue

		if x._drag_insert_condition_exp != null && x._drag_insert_condition_exp.execute([self, x], child) != true:
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

		drag_transfered_out.emit(child, x)
		x.drag_transfered_in.emit(child, self)
		break


func _on_child_entered_tree(x : Node):
	if x is Control:
		x.gui_input.connect(_on_child_gui_input.bind(x))


func _on_child_exiting_tree(x : Node):
	if x is Control:
		x.gui_input.disconnect(_on_child_gui_input)


func _on_child_gui_input(event : InputEvent, child : Control):
	if !allow_drag_reorder && !allow_drag_transfer:
		return

	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT && event.pressed:
		_dragging_node = child
		drag_started.emit(child)
		set_process_input(true)
