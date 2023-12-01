class_name DockContainer
extends Container

enum ContainerType {
	TAB = 0,
	HBOX,
	VBOX
}

@export var enable_tabs := false

@export var dock_drop_edge_margin := 100
@export var dock_tabs_height := 100
@export var dock_region_preview_color := Color(1.0, 1.0, 1.0, 0.5)

var _virtual_tree : MarginContainer
var _drop_preview : Control
var _dragging_node : Control
var _dragging_container : Container
var _dragging_container_edge : int
var _node_virtual_counterpart := {}


func _init():
	_virtual_tree = MarginContainer.new()
	_drop_preview = Control.new()
	_drop_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_drop_preview.draw.connect(_on_preview_draw)
	child_entered_tree.connect(_on_child_entered_tree)
	child_exiting_tree.connect(_on_child_exited_tree)

	add_child(_virtual_tree, false, INTERNAL_MODE_FRONT)
	add_child(_drop_preview, false, INTERNAL_MODE_BACK)
	_virtual_tree.add_child(HBoxContainer.new())

## Gets the side of a [Rect2], represented by one of the [Vector2i] direction constants if within [code]border_width[/code] of an edge, or [code](0, 0)[/code] if not.
static func get_dock_region(rect : Rect2, drop_position : Vector2, border_width : float = -1) -> Vector2i:
	if border_width >= 0 && rect.grow(-border_width).has_point(drop_position):
		return Vector2i.ZERO

	var startpos := drop_position - rect.position
	var endpos := rect.end - drop_position
	var relpos := startpos / rect.size
	if relpos.x < 0.5:
		if startpos.x < startpos.y && startpos.x < endpos.y:
			return Vector2i.LEFT

	if endpos.x < startpos.y && endpos.x < endpos.y:
		return Vector2i.RIGHT

	elif relpos.y < 0.5:
		return Vector2i.UP

	else:
		return Vector2i.DOWN

## Drops node onto this container, placing inside the dock under the specified position. If not a child, reparents the node.
func drop_node(node : Control, on_global_position : Vector2):
	var inverse_xform := get_global_transform().affine_inverse()
	var on_local_position := inverse_xform * on_global_position
	if !Rect2(Vector2.ZERO, size).has_point(on_local_position):
		return

	if node.get_parent() != self:
		if node.get_parent() != null:
			node.reparent(self)

		else:
			add_child(node)

	var virtual_node_above := _get_or_create_virtual(node)
	var virtual_node_below := _get_virtual_node_at(on_local_position)
	if virtual_node_above == virtual_node_below:
		return

	var virtual_node_below_rect := Rect2(inverse_xform * virtual_node_below.global_position, inverse_xform.basis_xform(virtual_node_below.size))
	var dock_region := get_dock_region(virtual_node_below_rect, on_local_position, -1 if !enable_tabs else dock_drop_edge_margin)
	var previous_container := virtual_node_above.get_parent()

	if dock_region == Vector2i.ZERO:
		var new_c := _add_container(virtual_node_below, ContainerType.TAB)
		virtual_node_above.reparent(new_c)

	else:
		var new_c : Container
		if dock_region.y == 0:
			new_c = _add_container(virtual_node_below, ContainerType.HBOX)
			virtual_node_above.reparent(new_c)

		if dock_region.x == 0:
			new_c = _add_container(virtual_node_below, ContainerType.VBOX)
			virtual_node_above.reparent(new_c)

		var index_offset := 1 if (dock_region.x > 0 || dock_region.y > 0) else 0
		new_c.move_child.call_deferred(virtual_node_above, virtual_node_below.get_index() + index_offset)
		new_c.queue_sort()

	if previous_container.get_child_count() == 1:
		_dissolve_container(previous_container.get_child(0))


func _get_virtual_node_at(local_position : Vector2, seek_edge : bool = false) -> Control:
	var current_node := _virtual_tree.get_child(0)
	local_position -= current_node.position
	while true:
		if current_node is HBoxContainer:
			for x in current_node.get_children():
				if x.position.x < local_position.x:
					current_node = x
					continue

		if current_node is VBoxContainer:
			for x in current_node.get_children():
				if x.position.y < local_position.y:
					current_node = x
					continue

		if current_node is MarginContainer:
			for x in current_node.get_children():
				if x.visible:
					current_node = x
					continue

		return current_node

	return null


func _add_container(virtual_node : Control, of_type : ContainerType) -> Container:
	if !is_instance_valid(virtual_node):
		return

	var new_c : Control
	var v_node_parent := virtual_node.get_parent()
	queue_sort()
	match of_type:
		ContainerType.TAB:
			if v_node_parent is MarginContainer:
				return v_node_parent

			new_c = MarginContainer.new()
		ContainerType.HBOX:
			if v_node_parent is HBoxContainer:
				return v_node_parent

			new_c = HBoxContainer.new()
		ContainerType.VBOX:
			if v_node_parent is VBoxContainer:
				return v_node_parent

			new_c = VBoxContainer.new()

	virtual_node.add_sibling(new_c)
	v_node_parent.remove_child(virtual_node)
	new_c.add_child(virtual_node)
	new_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return new_c


func _dissolve_container(virtual_node : Control) -> Container:
	if !is_instance_valid(virtual_node):
		return null

	var v_node_index := virtual_node.get_index()
	var v_node_parent := virtual_node.get_parent()
	var v_node_parent_parent := v_node_parent.get_parent()
	if v_node_parent_parent == _virtual_tree:
		return

	var index_offset := 0
	for x in v_node_parent.get_children():
		x.reparent(v_node_parent_parent)
		v_node_parent_parent.move_child(x, v_node_index + index_offset)
		index_offset += 1

	v_node_parent.queue_free()
	if v_node_parent_parent.get_child_count() <= 1:
		return _dissolve_container(v_node_parent)

	queue_sort()
	return v_node_parent_parent


func _get_or_create_virtual(to_node : Control) -> Control:
	var virtual_node := _node_virtual_counterpart.get(to_node, null)
	if virtual_node == null:
		# virtual_node = ColorRect.new()  # For Debug
		virtual_node = Control.new()
		virtual_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		virtual_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_node_virtual_counterpart[to_node] = virtual_node
		_virtual_tree.get_child(0).add_child(virtual_node)
		virtual_node.gui_input.connect(_virtual_node_gui_input.bind(to_node))
		virtual_node.resized.connect(_position_child.bind(to_node))

	return virtual_node


func _position_child(x : Control):
	var virtual_node := _get_or_create_virtual(x)
	virtual_node.custom_minimum_size = x.get_combined_minimum_size()
	x.global_position = virtual_node.global_position
	x.size = virtual_node.size


func _position_all_children():
	_virtual_tree.position = Vector2.ZERO
	_virtual_tree.size = size
	_drop_preview.position = Vector2.ZERO
	_drop_preview.size = size
	for x in get_children():
		if x == _dragging_node:
			x.z_index = 1
			continue

		if x is Control:
			x.z_index = 0
			_position_child(x)


func _notification(what : int):
	if what == NOTIFICATION_SORT_CHILDREN:
		_position_all_children()


func _virtual_node_gui_input(event : InputEvent, of_real_node : Control):
	if event is InputEventMouseMotion:
		_drop_preview.queue_redraw()

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed: _dragging_node = of_real_node
				elif _dragging_node == of_real_node:
					_dragging_node = null
					drop_node(of_real_node, event.global_position)
					_drop_preview.queue_redraw()


func _gui_input(event : InputEvent):
	queue_sort.call_deferred()
	if event is InputEventMouseMotion:
		if _dragging_container != null:
			var first_node := _dragging_container.get_child(_dragging_container_edge)
			var second_node := _dragging_container.get_child(_dragging_container_edge + 1)
			if _dragging_container is HBoxContainer:
				var ratio_delta : float = event.relative.x / first_node.size.x * first_node.size_flags_stretch_ratio
				if first_node.size_flags_stretch_ratio == 0.0:
					if event.relative.x < 0: return
					ratio_delta = event.relative.x / second_node.size.x * second_node.size_flags_stretch_ratio

				first_node.size_flags_stretch_ratio = maxf(first_node.size_flags_stretch_ratio + ratio_delta, 0.0)
				second_node.size_flags_stretch_ratio = maxf(second_node.size_flags_stretch_ratio - ratio_delta, 0.0)

			if _dragging_container is VBoxContainer:
				var ratio_delta : float = event.relative.y / first_node.size.y * first_node.size_flags_stretch_ratio
				if first_node.size_flags_stretch_ratio == 0.0:
					if event.relative.y < 0: return
					ratio_delta = event.relative.y / second_node.size.y * second_node.size_flags_stretch_ratio

				first_node.size_flags_stretch_ratio = maxf(first_node.size_flags_stretch_ratio + ratio_delta, 0.0)
				second_node.size_flags_stretch_ratio = maxf(second_node.size_flags_stretch_ratio - ratio_delta, 0.0)

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					var grabbed_node := _get_virtual_node_at(event.position, true)
					_dragging_container = grabbed_node.get_parent()
					_dragging_container_edge = grabbed_node.get_index()

				else:
					_dragging_container = null
					_dragging_container_edge = -1
					_drop_preview.queue_redraw()


func _on_preview_draw():
	if _dragging_node == null:
		return

	var mouse_local_pos := get_local_mouse_position()
	var inverse_xform := get_global_transform().affine_inverse()
	var virtual_node_below := _get_virtual_node_at(mouse_local_pos)
	if virtual_node_below == _node_virtual_counterpart[_dragging_node]:
		return

	var virtual_node_below_rect := Rect2(inverse_xform * virtual_node_below.global_position, inverse_xform.basis_xform(virtual_node_below.size))
	var dock_side := get_dock_region(virtual_node_below_rect, mouse_local_pos)
	var drawn_rect := virtual_node_below_rect
	var cur_margin := dock_drop_edge_margin
	if dock_side == Vector2i.ZERO:
		drawn_rect = drawn_rect.grow(-cur_margin)

	if dock_side.y == 0:
		drawn_rect.size.x = min(cur_margin, virtual_node_below_rect.size.x * 0.5)
		if dock_side.x > 0:
			drawn_rect.position.x += virtual_node_below_rect.size.x - cur_margin

	if dock_side.x == 0:
		drawn_rect.size.y = min(cur_margin, virtual_node_below_rect.size.y * 0.5)
		if dock_side.y > 0:
			drawn_rect.position.y += virtual_node_below_rect.size.y - cur_margin

	_drop_preview.draw_rect(drawn_rect, dock_region_preview_color)


func _on_child_entered_tree(child : Node):
	if child == _virtual_tree || child == _drop_preview: return
	_get_or_create_virtual(child)


func _on_child_exited_tree(child : Node):
	var virtual_node := _node_virtual_counterpart.get(child, null)
	if virtual_node == null:
		return

	if virtual_node.get_parent().get_child_count() <= 2:
		_dissolve_container(virtual_node)

	virtual_node.free()
