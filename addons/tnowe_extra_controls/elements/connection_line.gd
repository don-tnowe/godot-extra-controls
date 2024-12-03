@tool
class_name ConnectionLine
extends Control

## A line that connects between two [Control]s or [Node2D]s. Targets do not need have the same parent, only be in the same [Viewport].

const _style_offsets : Array[float] = [0.0, 1.0, 0.5, 0.5]

## Emitted when a path point is created by user input, possible if [member allow_point_creation] is enabled.
signal path_point_added(point_index : int, point_position : Vector2)
## Emitted when a path point is moved by user input.
signal path_point_moved(point_index : int, point_position : Vector2)
## Emitted when a path point is removed by user input, possible if [member allow_point_creation] is enabled.
signal path_point_removed(point_index : int, point_position : Vector2)

## Node that will connect to the beginning of the line. May be empty if [member connect_point1] is set.
@export var connect_node1 : CanvasItem:
	set(v):
		connect_node1 = v
		queue_redraw()
		set_process(redraw_every_frame)
		if v != null:
			if !v.is_inside_tree(): await ready
			_connect_node1_parent = v.get_parent()
## Node that will connect to the end of the line. May be empty if [member connect_point2] is set.
@export var connect_node2 : CanvasItem:
	set(v):
		connect_node2 = v
		queue_redraw()
		set_process(redraw_every_frame)
		if v != null:
			if !v.is_inside_tree(): await ready
			_connect_node2_parent = v.get_parent()
## The beginning of the line, in parent's local coordinates. If a [member connect_node1] is provided, this will be the calculated beginning point.[br]
## [b]Warning:[/b] if you set this on initialization and [member allow_drag_pt1] is active, you must call [method update_endpoint_pools].
@export var connect_point1 := Vector2()
## The end of the line, in parent's local coordinates. If a [member connect_node2] is provided, this will be the calculated end point.[br]
## [b]Warning:[/b] if you set this on initialization and [member allow_drag_pt2] is active, you must call [method update_endpoint_pools].
@export var connect_point2 := Vector2()
## The beginning of the line will get anchored to this position, between 0 and 1, within [member connect_node1]'s [Control] rectangle. Using [code](0.5, 0.5)[/code] will anchor the line to the node's center.
@export var connect_anchor1 := Vector2(0.5, 0.5)
## The end of the line will get anchored to this position, between 0 and 1, within [member connect_node2]'s [Control] rectangle. Using [code](0.5, 0.5)[/code] will anchor the line to the node's center.
@export var connect_anchor2 := Vector2(0.5, 0.5)

@export_group("Behaviour")
## Allow dragging the beginning (point 1) of the line to connect it to another node, changing [member connect_node1]. Only works on [Control] targets.
@export var allow_drag_pt1 := false
## Allow dragging the end (point 2) of the line to connect it to another node, changing [member connect_node2]. Only works on [Control] targets.
@export var allow_drag_pt2 := false
## Allow dragging the middle of a segment between points to create a new point, as well as dragging a point onto another to remove all points in between.
@export var allow_point_creation := false
## Allow placement of end and begginning points at a place with no Control underneath. This disconnects the point from its current connected node.
@export var allow_loose_placement := false
## Whether to redraw the line every [code]_process()[/code]. Otherwise, update it with [method CanvasItem.queue_redraw].
@export var redraw_every_frame := true:
	set(v):
		redraw_every_frame = v
		set_process(v)
## Expression to test for [member allow_drag_pt1] and [member allow_drag_pt2] to know if a node can be attached to, executed on that target node. If [code]true[/code], the node will be attached to.[br]
## The [code]from[/code] parameter will be the previously attached node, [code]other[/code] will be the node attached to the opposite end, and [code]line[/code] will be this node. [br]
## For example, expression [code](get_class() == "Button" and other.has_method(&"attach_button_node"))[/code] tests if the new target is a [code]Button[/code] and the other connected node has method [code]attach_button_node[/code]. [br][br]
## [b]Warning: [/b] Some operators are unsupported in expressions, such as [code]is[/code] and ternary [code]if[/code]. Consider calling node's script methods after checking [code]has_method[/code].
@export var drag_reattach_condition := ""
## Expression to execute on the target after reattachment succeeds. Same parameters as [member drag_reattach_condition].
@export var drag_reattach_call_on_success := ""

@export_group("Style")
## The line's color.
@export var line_color := Color.BLACK
## Line width, affecting the clickable area.
@export var line_width := 4.0
## Texture stretching along the line.
@export var line_texture : Texture2D
## If [code]true[/code], [member texture] will repeat along the line. [member CanvasItem.texture_repeat] of the [ConnectionLine] node must be CanvasItem.TEXTURE_REPEAT_ENABLED or CanvasItem.TEXTURE_REPEAT_MIRROR for it to work properly.
@export var line_texture_tile := false
## The spacing between this connection's edge and the node's rect.
@export var connection_margin := 4.0
## Minimum line length. If a redraw of the line would make it shorter than this, it extends back to this length.
@export var line_min_length := 0.0
## The style of the end touching [member connect_node1].
@export_enum("None", "Arrow", "Circle", "Line") var end_style1 := 0
## The style of the end touching [member connect_node2].
@export_enum("None", "Arrow", "Circle", "Line") var end_style2 := 1
## The size of the arrow at the tip of the line. Affects [member end_style1] and [member end_style2] differently.
@export var line_arrow_size := Vector2(6.0, 8.0)
## When a drag via [member allow_drag_pt1] or [member allow_drag_pt2] is possible, this is the color of the hint circle.
@export var drag_hint_color := Color(1.0, 1.0, 1.0, 0.75)
## When a drag via [member allow_drag_pt1] or [member allow_drag_pt2] is possible, this is the radius of the hint circle.
@export var drag_hint_radius := 8.0

var _mouse_over := false
var _mouse_dragging := -1
var _label_clickable_rect := Rect2()
var _path_curve : Curve2D
var _last_rect1 := Rect2()
var _last_rect2 := Rect2()
var _connect_node1_parent : Node
var _connect_node2_parent : Node


func _init():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _process(delta : float):
	if !is_instance_valid(connect_node1) || !is_instance_valid(connect_node2):
		set_process(false)
		return

	# Redraw, but only if positions changed.
	if connect_node1 is Control && _last_rect1 != connect_node1.get_global_rect():
		_last_rect1 = connect_node1.get_global_rect()
		queue_redraw()
		return

	if connect_node1 is Node2D && connect_node1.position != _last_rect1.position:
		_last_rect1.position = connect_node1.position
		queue_redraw()
		return

	if connect_node2 is Control && _last_rect2 != connect_node2.get_global_rect():
		_last_rect2 = connect_node2.get_global_rect()
		queue_redraw()
		return

	if connect_node2 is Node2D && connect_node2.position != _last_rect2.position:
		_last_rect2.position = connect_node2.position
		queue_redraw()
		return


func _has_point(point : Vector2) -> bool:
	if !Rect2(Vector2.ZERO, size).has_point(point):
		return false

	if allow_drag_pt1 && _is_in_radius(connect_point1 - position, point):
		return true

	if allow_drag_pt2 && _is_in_radius(connect_point2 - position, point):
		return true

	if _path_curve != null:
		if _get_overlapped_path_point(point + position) != -1:
			return true

		# TODO: block mouse input when pointer is on the line
		# if (point + position).distance_squared_to(_path_curve.get_closest_point(point + position)) <= line_width * line_width:
		# 	return true

	if allow_point_creation && _get_overlapped_path_midpoint(point + position) != -1:
		return true

	return false


func _draw():
	var xform_start := Transform2D(Vector2(1.0, 0.0), Vector2(0.0, 1.0), connect_point1)
	var xform_end := Transform2D(Vector2(1.0, 0.0), Vector2(0.0, 1.0), connect_point2)
	var parent_xform_inv : Transform2D = Transform2D.IDENTITY
	if get_parent() is CanvasItem:
		parent_xform_inv = get_parent().get_global_transform().affine_inverse()
		xform_start.origin -= parent_xform_inv.origin
		xform_end.origin -= parent_xform_inv.origin

	if connect_node1 != null:
		xform_start = connect_node1.get_global_transform()

	if connect_node2 != null:
		xform_end = connect_node2.get_global_transform()

	xform_start = parent_xform_inv * xform_start
	xform_end = parent_xform_inv * xform_end

	# Determine line endpoints
	var line_start := xform_start.origin
	var line_end := xform_end.origin
	if connect_node1 is Control:
		line_start += xform_start.basis_xform_inv(connect_node1.size * connect_anchor1)

	if connect_node2 is Control:
		line_end += xform_end.basis_xform_inv(connect_node2.size * connect_anchor2)

	var line_direction_forward := (line_end - line_start).normalized()
	var line_direction_backward := (line_start - line_end).normalized()
	if _path_curve != null:
		line_direction_forward = (line_end - _path_curve.get_point_position(_path_curve.point_count - 1)).normalized()
		line_direction_backward = (line_start - _path_curve.get_point_position(0)).normalized()

	# Turn center positions into edge positions (if applicable)
	if connect_node1 is Control && !(connect_node1 is ConnectionLine):
		if connect_anchor1 == Vector2(0.5, 0.5):
			line_start = xform_start * get_rect_edge_position(
				Rect2(Vector2.ZERO, connect_node1.size),
				xform_start.basis_xform_inv(-line_direction_backward).normalized(),
				connection_margin,
			)

		else:
			line_start = xform_start * get_rect_edge_position_ratio(
				Rect2(Vector2.ZERO, connect_node1.size),
				xform_start.basis_xform_inv(-line_direction_backward).normalized(),
				connection_margin,
				connect_anchor1,
			)

	if connect_node2 is Control && !(connect_node2 is ConnectionLine):
		if connect_anchor2 == Vector2(0.5, 0.5):
			line_end = xform_end * get_rect_edge_position(
				Rect2(Vector2.ZERO, connect_node2.size),
				xform_end.basis_xform_inv(-line_direction_forward).normalized(),
				connection_margin,
			)

		else:
			line_end = xform_end * get_rect_edge_position_ratio(
				Rect2(Vector2.ZERO, connect_node2.size),
				xform_end.basis_xform_inv(-line_direction_forward).normalized(),
				connection_margin,
				connect_anchor2,
			)
			

	# Correction if resulting path is too short
	if line_start.distance_squared_to(line_end) < line_min_length * line_min_length:
		var line_start_plus_end := line_start + line_end
		line_start = (line_start_plus_end - line_direction_backward * line_min_length) * 0.5
		line_end = (line_start_plus_end + line_direction_forward * line_min_length) * 0.5

	# Define render rect
	var result_rect := Rect2(line_start, Vector2.ZERO).expand(line_end)
	if _path_curve != null:
		for i in _path_curve.point_count:
			result_rect = result_rect.expand(_path_curve.get_point_position(i))

	result_rect = result_rect.grow(drag_hint_radius)
	position = result_rect.position
	size = result_rect.size

	# Save endpoint positions in parent's local space
	connect_point1 = line_start
	connect_point2 = line_end

	# Finally draw
	var mouse_point := get_local_mouse_position() + position
	if _mouse_dragging == -2: line_start = mouse_point
	if _mouse_dragging == -3: line_end = mouse_point

	draw_set_transform(-position)
	if line_texture == null:
		_draw_line_untextured(line_start, line_end, line_direction_backward, line_direction_forward)

	else:
		_draw_line_textured(line_start, line_end, line_direction_backward, line_direction_forward)

	if _path_curve == null:
		_draw_arrow(line_end, line_start, end_style1)
		_draw_arrow(line_start, line_end, end_style2)

	else:
		_draw_arrow(_path_curve.get_point_position(0), line_start, end_style1)
		_draw_arrow(_path_curve.get_point_position(_path_curve.point_count - 1), line_end, end_style2)

	# Drag Area Hint
	if allow_drag_pt1 && _is_in_radius(line_start, mouse_point):
		draw_circle(line_start, drag_hint_radius, drag_hint_color)

	if allow_drag_pt2 && _is_in_radius(line_end, mouse_point):
		draw_circle(line_end, drag_hint_radius, drag_hint_color)

	if _path_curve != null:
		var pt_under_mouse := _get_overlapped_path_point(mouse_point)
		if pt_under_mouse != -1:
			draw_circle(_path_curve.get_point_position(pt_under_mouse), drag_hint_radius, drag_hint_color)
			return

		if !allow_point_creation:
			return

		pt_under_mouse = _get_overlapped_path_midpoint(mouse_point)
		if pt_under_mouse != -1:
			var prev_point_pos := line_start
			var next_point_pos := line_end
			if pt_under_mouse != 0:
				prev_point_pos = _path_curve.get_point_position(pt_under_mouse - 1)

			if pt_under_mouse < _path_curve.point_count:
				next_point_pos = _path_curve.get_point_position(pt_under_mouse)

			draw_circle((prev_point_pos + next_point_pos) * 0.5, drag_hint_radius, drag_hint_color)

	elif _is_in_radius((line_start + line_end) * 0.5, mouse_point) && allow_point_creation:
		draw_circle((line_start + line_end) * 0.5, drag_hint_radius, drag_hint_color)

## Add a point to the path, in this node's parent's local coordinates. Index 0 is the first point [b]after[/b] the start point.
func path_add(new_index : int, new_position : Vector2):
	if _path_curve == null:
		_path_curve = Curve2D.new()

	_path_curve.add_point(new_position, Vector2.ZERO, Vector2.ZERO, new_index)
	queue_redraw()

## Set a point's position, in this node's parent's local coordinates. Index 0 is the first point [b]after[/b] the start point.
func path_set(point_index : int, new_position : Vector2):
	if _path_curve == null:
		return

	_path_curve.set_point_position(point_index, new_position)
	queue_redraw()

## Remove a point from the path.
func path_remove(index : int):
	if _path_curve == null: return
	if _path_curve.point_count == 1:
		_path_curve = null
		return

	_path_curve.remove_point(index)
	queue_redraw()

## Clear all path points, reverting the path to a straight line.
func path_clear():
	_path_curve = null
	queue_redraw()

## Returns the number of points in the path, not including [member connect_point1] and [member connect_point2].
func path_get_count() -> int:
	return 0 if _path_curve == null else _path_curve.point_count

## Returns a copy of this node's array of path points, not including [member connect_point1] and [member connect_point2].
func path_get_points() -> Array[Vector2]:
	if _path_curve == null:
		return []

	var result : Array[Vector2] = []
	result.resize(_path_curve.point_count)
	for i in result.size():
		result[i] = _path_curve.get_point_position(i)

	return result

## Sample a [code]0-1[/code] value on the path, with additional path points taken into account. [code]0.5[/code] returns the middle position, [code]0[/code] returns the start position, [code]1[/code] returns the end position.
func path_sample(unit_progress : float) -> Vector2:
	if _path_curve == null:
		return lerp(connect_point1, connect_point2, unit_progress)

	var vec_first := _path_curve.get_point_position(0) - connect_point1
	var vec_last := _path_curve.get_point_position(_path_curve.get_point_count() - 1) - connect_point2
	var length_first := vec_first.length()
	var length_last := vec_last.length()
	var length_total := length_first + _path_curve.get_baked_length() + length_last
	var px_progress := length_total * unit_progress
	if px_progress < length_first:
		return connect_point1 + px_progress * vec_first.normalized()

	elif px_progress > length_total - length_last:
		return connect_point2 + (length_total - px_progress) * vec_last.normalized()

	return _path_curve.sample_baked(px_progress - length_first)

## Manually updates the nodes whose children this line can be attached to via [member allow_drag_pt1] and [member allow_drag_pt2].
func update_endpoint_pools(parent1 : Node, parent2 : Node):
	_connect_node1_parent = parent1
	_connect_node2_parent = parent2

## Utility function to get a point on the intersection of the [code]rect[/code]'s border and the ray cast from a 0-1 position [code]ratio[/code] in [code]direction[/code]. [br]
static func get_rect_edge_position_ratio(rect : Rect2, direction : Vector2, margin : float = 0.0, ratio : Vector2 = Vector2(0.5, 0.5)) -> Vector2:
	var rect_size := rect.size + Vector2(margin, margin)
	var direction_sign := direction.sign()
	# Farther from the target edge = rect appears larger.
	rect_size *= Vector2(0.5, 0.5) + (Vector2(0.5, 0.5) - ratio) * direction_sign
	var use_vertical := absf(direction.y) > rect_size.y / rect_size.length()
	if use_vertical:
		direction *= rect_size.y / absf(direction.y)

	else:
		direction *= rect_size.x / absf(direction.x)

	return rect.position + rect.size * ratio + direction


## Utility function to get a point on the intersection of the [code]rect[/code]'s border and the ray cast from its center in [code]direction[/code]. [br]
## Equivalent to calling [method get_rect_edge_position_ratio] with [code]ratio = (0.5, 0.5)[/code].
static func get_rect_edge_position(rect : Rect2, direction : Vector2, margin : float = 0.0) -> Vector2:
	var rect_size := rect.size + Vector2(margin, margin)
	var use_vertical := absf(direction.y) > rect_size.y / rect_size.length()
	if use_vertical:
		direction *= rect_size.y / absf(direction.y) * 0.5

	else:
		direction *= rect_size.x / absf(direction.x) * 0.5

	return rect.position + rect.size * 0.5 + direction


func _draw_line_textured(line_start : Vector2, line_end : Vector2, line_direction_backward : Vector2, line_direction_forward : Vector2):
	var line_start_poly := line_start - line_direction_backward * line_arrow_size.y * _style_offsets[end_style1]
	var line_end_poly := line_end - line_direction_forward * line_arrow_size.y * _style_offsets[end_style2]
	if _path_curve == null:
		_draw_single_segment_textured(line_start_poly, line_end_poly, line_direction_forward)

	else:
		_draw_single_segment_textured(
			line_start_poly,
			_path_curve.get_point_position(0),
			line_direction_backward,
		)
		draw_circle(_path_curve.get_point_position(0), line_width * 0.5, line_color)
		for i in _path_curve.point_count - 1:
			_draw_single_segment_textured(
				_path_curve.get_point_position(i),
				_path_curve.get_point_position(i + 1),
				_path_curve.get_point_position(i).direction_to(_path_curve.get_point_position(i + 1)),
			)
			draw_circle(_path_curve.get_point_position(i + 1), line_width * 0.5, line_color)

		_draw_single_segment_textured(
			_path_curve.get_point_position(_path_curve.point_count - 1),
			line_end_poly,
			line_direction_forward,
		)


func _draw_single_segment_textured(line_start_poly : Vector2, line_end_poly : Vector2, line_direction : Vector2):
	var length_in_textures := (line_end_poly - line_start_poly).length() * (float(line_texture.get_height()) / line_texture.get_width()) / line_width
	var line_direction_rotated := Vector2(-line_direction.y, line_direction.x) * line_width * 0.5
	draw_colored_polygon(
		[
			line_end_poly - line_direction_rotated,
			line_end_poly + line_direction_rotated,
			line_start_poly + line_direction_rotated,
			line_start_poly - line_direction_rotated,
		], line_color, [
			Vector2(length_in_textures, 0.0),
			Vector2(length_in_textures, 1.0),
			Vector2(0.0, 1.0),
			Vector2(0.0, 0.0),
		], line_texture
	)


func _draw_line_untextured(line_start : Vector2, line_end : Vector2, line_direction_backward : Vector2, line_direction_forward : Vector2):
	if _path_curve == null:
		draw_line(
			line_start - line_direction_backward * line_arrow_size.y * _style_offsets[end_style1],
			line_end - line_direction_forward * line_arrow_size.y * _style_offsets[end_style2],
			line_color,
			line_width,
		)

	else:
		draw_line(
			line_start - line_direction_backward * line_arrow_size.y * _style_offsets[end_style1],
			_path_curve.get_point_position(0),
			line_color,
			line_width,
		)
		draw_circle(_path_curve.get_point_position(0), line_width * 0.5, line_color)
		for i in _path_curve.point_count - 1:
			draw_line(
				_path_curve.get_point_position(i),
				_path_curve.get_point_position(i + 1),
				line_color,
				line_width,
			)
			draw_circle(_path_curve.get_point_position(i + 1), line_width * 0.5, line_color)

		draw_line(
			_path_curve.get_point_position(_path_curve.point_count - 1),
			line_end - line_direction_forward * line_arrow_size.y * _style_offsets[end_style2],
			line_color,
			line_width,
		)


func _draw_arrow(line_start : Vector2, line_end : Vector2, style : int):
	var line_direction := (line_end - line_start).normalized()
	match style:
		1:
			draw_colored_polygon(
				[
					line_end + line_direction,
					line_end - line_direction * line_arrow_size.y + line_arrow_size.x * Vector2(
						line_direction.y,
						-line_direction.x,
					),
					line_end - line_direction * line_arrow_size.y + line_arrow_size.x * Vector2(
						-line_direction.y,
						line_direction.x,
					),
				],
				line_color,
			)
		2:
			draw_circle(
				line_end - line_direction * line_arrow_size.y * 0.5,
				line_arrow_size.y * 0.5,
				line_color,
			)
		3:
			draw_line(
				line_end - line_direction * line_width + line_arrow_size.x * Vector2(
					line_direction.y,
					-line_direction.x,
				),
				line_end - line_direction * line_width + line_arrow_size.x * Vector2(
					-line_direction.y,
					line_direction.x,
				),
				line_color,
				line_width,
			)


func _is_in_radius(circle_center : Vector2, point : Vector2):
	return circle_center.distance_squared_to(point) <= drag_hint_radius * drag_hint_radius


func _get_overlapped_path_point(point_in_parent : Vector2) -> int:
	if _path_curve == null:
		return -1

	for i in _path_curve.point_count:
		if _is_in_radius(_path_curve.get_point_position(i), point_in_parent):
			return i

	return -1


func _get_overlapped_path_midpoint(point_in_parent : Vector2) -> int:
	if _path_curve == null:
		return 0 if _is_in_radius((connect_point1 + connect_point2) * 0.5, point_in_parent) else -1

	var prev_position := connect_point1
	var next_position := Vector2.ZERO
	for i in _path_curve.point_count:
		next_position = _path_curve.get_point_position(i)
		if _is_in_radius((prev_position + next_position) * 0.5, point_in_parent):
			return i

		prev_position = next_position

	next_position = connect_point2
	if _is_in_radius((prev_position + next_position) * 0.5, point_in_parent):
		return _path_curve.point_count

	return -1


func _get_overlapped_control(of_parent : Node, ignore_node : Node, global_point : Vector2, drag_reattach_condition_expr : Expression, expr_params : Array) -> Control:
	if of_parent == null:
		return null

	if of_parent is CanvasItem:
		global_point = of_parent.get_global_transform().affine_inverse() * global_point

	for x in of_parent.get_children():
		if x == ignore_node || !(x is Control) || !x.get_rect().has_point(global_point):
			continue

		if drag_reattach_condition_expr != null && !drag_reattach_condition_expr.execute(expr_params, x):
			continue

		return x

	return null


func _gui_input(event : InputEvent):
	queue_redraw()
	if event is InputEventMouseMotion:
		if _mouse_dragging >= 0:
			path_set(_mouse_dragging, event.position + position)
			path_point_moved.emit(_mouse_dragging, event.position + position)

	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_point : Vector2 = event.position
		if !event.pressed && _mouse_dragging != -1:
			mouse_point += position
			var succeeded_on : Control
			var drag_reattach_condition_expr := Expression.new()
			var expr_params : Array = [
				connect_node1 if _mouse_dragging == -2 else connect_node2,
				connect_node2 if _mouse_dragging == -2 else connect_node1,
				self
			]
			if drag_reattach_condition_expr.parse(drag_reattach_condition, [&"from", &"other", &"line"]) != OK:
				# Couldn't parse expression, so don't call it.
				drag_reattach_condition_expr = null

			if _mouse_dragging == -2:
				succeeded_on = _get_overlapped_control(_connect_node1_parent, connect_node2, event.global_position, drag_reattach_condition_expr, expr_params)
				if succeeded_on == null && allow_loose_placement:
					connect_node1 = null
					connect_point1 = event.position + position

				if succeeded_on != null:
					connect_node1 = succeeded_on

			elif _mouse_dragging == -3:
				succeeded_on = _get_overlapped_control(_connect_node2_parent, connect_node1, event.global_position, drag_reattach_condition_expr, expr_params)
				if succeeded_on == null && allow_loose_placement:
					connect_node2 = null
					connect_point2 = event.position + position

				if succeeded_on != null:
					connect_node2 = succeeded_on

			elif _path_curve != null:
				if _mouse_dragging >= 0 && _mouse_dragging < _path_curve.point_count:
					path_point_moved.emit(_mouse_dragging, mouse_point)
					if !allow_point_creation:
						return

					for i in _path_curve.point_count:
						if _mouse_dragging != i && _path_curve.get_point_position(i).distance_squared_to(mouse_point) < drag_hint_radius * drag_hint_radius:
							var remove_start := i
							if _mouse_dragging < i:
								remove_start = _mouse_dragging + 1

							for remove_i in absi(_mouse_dragging - i):
								var old_pos := _path_curve.get_point_position(remove_start)
								path_remove(remove_start)
								path_point_removed.emit(remove_start, old_pos)

							break

					if connect_point1.distance_squared_to(mouse_point) < drag_hint_radius * drag_hint_radius:
						for remove_i in _mouse_dragging + 1:
							var old_pos := _path_curve.get_point_position(remove_i)
							path_remove(remove_i)
							path_point_removed.emit(remove_i, old_pos)

					elif connect_point2.distance_squared_to(mouse_point) < drag_hint_radius * drag_hint_radius:
						for remove_i in _path_curve.point_count - _mouse_dragging:
							var old_pos := _path_curve.get_point_position(_mouse_dragging)
							path_remove(_mouse_dragging)
							path_point_removed.emit(_mouse_dragging, old_pos)

					else:
						# Snap to grid and constrain to endpoint parents. Only if the point wasn't deleted when placed.
						var result_point := mouse_point
						if _connect_node1_parent != null && _connect_node1_parent is InterpolatedFreeContainer:
							result_point = result_point.snapped(_connect_node1_parent.grid_snap)
							result_point = result_point.clamp(Vector2.ZERO, _connect_node1_parent.size)

						elif connect_node1 != null && connect_node1 is Draggable:
							result_point = result_point.snapped(connect_node1.grid_snap)
							if connect_node1.constrain_rect_to_parent:
								result_point = result_point.clamp(Vector2.ZERO, _connect_node1_parent.size)

						if _connect_node2_parent != null && _connect_node2_parent is InterpolatedFreeContainer:
							result_point = result_point.snapped(_connect_node2_parent.grid_snap)
							result_point = result_point.clamp(Vector2.ZERO, _connect_node2_parent.size)

						elif connect_node2 != null && connect_node2 is Draggable:
							result_point = result_point.snapped(connect_node2.grid_snap)
							if connect_node2.constrain_rect_to_parent:
								result_point = result_point.clamp(Vector2.ZERO, _connect_node2_parent.size)

						path_set(_mouse_dragging, result_point)

			if succeeded_on != null:
				var drag_reattach_call_on_success_expr := Expression.new()
				drag_reattach_call_on_success_expr.parse(drag_reattach_call_on_success, [&"from", &"other", &"line"])
				drag_reattach_call_on_success_expr.execute(expr_params, succeeded_on)

			_mouse_dragging = -1
			return

		_mouse_dragging = -1
		if allow_drag_pt1 && _is_in_radius(connect_point1 - position, mouse_point):
			_mouse_dragging = -2

		elif allow_drag_pt2 && _is_in_radius(connect_point2 - position, mouse_point):
			_mouse_dragging = -3

		else:
			var pt_overlapping := _get_overlapped_path_point(event.position + position)
			if pt_overlapping != -1:
				_mouse_dragging = pt_overlapping
				return

			if allow_point_creation:
				pt_overlapping = _get_overlapped_path_midpoint(event.position + position)
				if pt_overlapping != -1:
					path_add(pt_overlapping, event.position + position)
					path_point_added.emit(pt_overlapping, event.position + position)
					_mouse_dragging = pt_overlapping


func _on_mouse_entered():
	_mouse_over = true
	queue_redraw()


func _on_mouse_exited():
	_mouse_over = false
	queue_redraw()
