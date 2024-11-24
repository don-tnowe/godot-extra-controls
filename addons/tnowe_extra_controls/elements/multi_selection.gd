class_name MultiSelection
extends Control

## Adds multiple-selection and box-selection functionality to children of specified nodes. Can detect [CollisionObject2D] and [Control] nodes. Can move [Draggable] and [InterpolatedContainer] nodes.
##
## [b]Note:[/b] selected [Control] nodes will have a box visible around them, but [CollisionObject2D] will not. Consider handling this with this node's signals.
## [b]Note:[/b] usage with [InterpolatedContainer] has visual issues related to controls not being ignored by the animation system while dragged. A fix for this is planned.

## Emitted when a node gets added to the selection.
signal node_added(node : Node)
## Emitted when a node gets removed from the selection.
signal node_removed(node : Node)

## List of nodes whose children will be affected. Make sure to call [method update_targets] after adding or removing targets at runtime.
@export var targets : Array[Node] = []:
	set(v):
		targets = v
		update_targets()
## The [StyleBox] to visualize the selection box, when an empty space is clicked and dragged.
@export var style_selection_box : StyleBox
## The [StyleBox] to show around selected nodes, with [member style_selected_margin].
@export var style_selected : StyleBox
## The amount the [member style_selected] box gets expanded, in pixels.
@export var style_selected_margin : float = 4.0
## The keyboard key to hold down to add nodes to the selection instead of clearing the selection. Affects [method single_select] and 
@export var modifier_key : Key = KEY_SHIFT

var _targets_active : Array[Node] = []
var _selected_nodes : Array[Node] = []
var _modifier_pressed := false

var _box_dragging := false
var _box_corner_start := Vector2.ZERO
var _box_corner_end := Vector2.ZERO


func _draw() -> void:
	var xform := get_global_transform().affine_inverse()
	if _box_corner_start != _box_corner_end:
		draw_set_transform_matrix(xform)
		draw_style_box(style_selection_box, Rect2(_box_corner_start, _box_corner_end - _box_corner_start).abs())

	for x in _selected_nodes:
		if is_instance_valid(x) && x is Control:
			draw_set_transform_matrix(xform * x.get_global_transform())
			draw_style_box(style_selected, Rect2(Vector2.ZERO, x.size).grow(style_selected_margin))

## Start the selection box at the specified position.
func box_start(global_pos : Vector2):
	_box_corner_start = global_pos
	_box_corner_end = global_pos
	queue_redraw()

## Move the selection box's second corner to the specified position.
func box_drag(global_pos : Vector2):
	_box_corner_end = global_pos
	queue_redraw()

## Ends the selection box, selecting all nodes in the box. If [member modifier_key] is held down, adds to current selection instead of clearing the previous selection.
func box_end(global_pos : Vector2):
	var selection_rect := Rect2(_box_corner_start, global_pos - _box_corner_start).abs()
	var selection_shape := RectangleShape2D.new()
	var selection_xform := Transform2D(0.0, selection_rect.position + selection_rect.size * 0.5)
	selection_shape.size = selection_rect.size

	var current_control_shape := RectangleShape2D.new()
	if !_modifier_pressed:
		for x in _selected_nodes:
			node_removed.emit(x)

		_selected_nodes.clear()

	for x in _targets_active:
		if x is InterpolatedContainer || x is Draggable:
			x._affected_by_multi_selection = self

		for y in x.get_children():
			if y is Area2D:
				for z in y.get_children():
					if z is CollisionShape2D:
						if z.shape != null && z.shape.collide(z.get_global_transform(), selection_shape, selection_xform):
							_selected_nodes.append(y)
							node_added.emit(y)
							break

			if y is Control:
				current_control_shape.size = y.size
				if current_control_shape.collide(y.get_global_transform().translated_local(current_control_shape.size * 0.5), selection_shape, selection_xform):
					_selected_nodes.append(y)
					node_added.emit(y)

	_box_corner_end = _box_corner_start
	queue_redraw()

## Handles a click on a node, with different behaviour based on if [member modifier_key] is held: [br]
## - If not held and node is unselected, clears selection and selects the node.[br]
## - If not held and node is selected, nothing happens.[br]
## - If held and node is unselected, adds node to selection.[br]
## - If held and node is selected, removes node from selection.[br]
func single_select(node : Node):
	if node is InterpolatedContainer || node is Draggable:
		node._affected_by_multi_selection = self

	if !_modifier_pressed:
		if (!_selected_nodes.has(node)):
			var node_was_selected := false
			for x in _selected_nodes:
				if x == node:
					node_was_selected = true
					continue

				node_removed.emit(x)

			_selected_nodes.clear()
			_selected_nodes.append(node)
			if !node_was_selected:
				node_added.emit(node)

		queue_redraw()
		return

	if _selected_nodes.has(node):
		_selected_nodes.erase(node)

	else:
		_selected_nodes.append(node)

	queue_redraw()

## Update targets whose children will be selectable. Must be called after changing [member targets] at runtime.
func update_targets():
	for x in _targets_active:
		x.child_entered_tree.disconnect(_on_target_child_entered_tree)
		x.child_exiting_tree.disconnect(_on_target_child_exiting_tree)
		for y in x.get_children():
			_on_target_child_exiting_tree(y)

	_targets_active = targets.duplicate()
	for x in _targets_active:
		x.child_entered_tree.connect(_on_target_child_entered_tree)
		x.child_exiting_tree.connect(_on_target_child_exiting_tree)
		for y in x.get_children():
			_on_target_child_entered_tree(y)


func _gui_input(event: InputEvent):
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			box_start(event.global_position)
			_box_dragging = true

		else:
			box_end(event.global_position)
			_box_dragging = false


func _input(event: InputEvent):
	if event is InputEventKey && !event.is_echo() && event.keycode == modifier_key:
		_modifier_pressed = event.is_pressed()

	if event is InputEventMouseMotion && _box_dragging:
		box_drag(event.global_position)


func _target_gui_input(event: InputEvent, node : Node):
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT && event.is_pressed():
		single_select(node)


func _target_collision_gui_input(_viewport: Node, event: InputEvent, _shape_idx: int, node : Node):
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT && event.is_pressed():
		single_select(node)


func _on_target_child_entered_tree(child : Node):
	if child is Control:
		child.gui_input.connect(_target_gui_input.bind(child))

	if child is Area2D:
		child.input_event.connect(_target_collision_gui_input.bind(child))


func _on_target_child_exiting_tree(child : Node):
	if child is Control:
		child.gui_input.disconnect(_target_gui_input)

	if child is Area2D:
		child.input_event.disconnect(_target_collision_gui_input)
