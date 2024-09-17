@tool
class_name ConnectionLine
extends Control

## A line that connects between two [Control]s or [Node2D]s. Must be in the same coordinate system with the targets, for example having the same parent.

const _style_offsets := [0.0, 1.0, 0.5, 0.5]

## Node that will connect to the beginning of the line.
@export var connect_node1 : CanvasItem:
	set(v):
		connect_node1 = v
		queue_redraw()
		set_process(redraw_every_frame)
## Node that will connect to the end of the line.
@export var connect_node2 : CanvasItem:
	set(v):
		connect_node2 = v
		queue_redraw()
		set_process(redraw_every_frame)

@export_group("Behaviour")
## Allow dragging the beginning (point 1) of the line to connect it to another node, changing [member connect_node1]. Only works on [Control] targets.
@export var allow_drag_pt1 := false
## Allow dragging the end (point 2) of the line to connect it to another node, changing [member connect_node2]. Only works on [Control] targets.
@export var allow_drag_pt2 := false
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
var _mouse_dragging := 0
var _label_clickable_rect := Rect2()
var _clickable_line_start := Vector2()
var _clickable_line_end := Vector2()
var _last_rect1 := Rect2()
var _last_rect2 := Rect2()


func _init():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _process(delta : float):
	if !is_instance_valid(connect_node1) || !is_instance_valid(connect_node2):
		set_process(false)
		return

	# Redraw, but only if positions changed.
	if connect_node1 is Control && _last_rect1 != connect_node1.get_rect():
		_last_rect1 = connect_node1.get_rect()
		queue_redraw()
		return

	if connect_node1 is Node2D && connect_node1.position != _last_rect1.position:
		_last_rect1.position = connect_node1.position
		queue_redraw()
		return

	if connect_node2 is Control && _last_rect2 != connect_node2.get_rect():
		_last_rect2 = connect_node2.get_rect()
		queue_redraw()
		return

	if connect_node2 is Node2D && connect_node2.position != _last_rect2.position:
		_last_rect2.position = connect_node2.position
		queue_redraw()
		return


func _has_point(point : Vector2) -> bool:
	if !Rect2(Vector2.ZERO, size).grow(drag_hint_radius).has_point(point):
		return false

	if allow_drag_pt1 && _is_in_radius(_clickable_line_start, point):
		return true

	if allow_drag_pt2 && _is_in_radius(_clickable_line_end, point):
		return true

	return false

	# Line overlap checks: this is buggy and turns out to not actually be useful to detect

	# if (_clickable_line_end == _clickable_line_start):
	# 	return (point - position).length_squared() <= line_width * line_width

	# var delta := _clickable_line_end - _clickable_line_start
	# var h := clampf(point.dot(delta) / delta.dot(delta), 0.0, 1.0);
	# return (point - h * delta).length_squared() <= line_width * line_width * 0.25;


func _draw():
	var xform_start := connect_node1.get_global_transform()
	var xform_end := connect_node2.get_global_transform()
	if get_parent() is CanvasItem:
		var parent_xform : Transform2D = get_parent().get_global_transform().affine_inverse()
		xform_start = parent_xform * xform_start
		xform_end = parent_xform * xform_end

	var line_start := xform_start.origin
	var line_end := xform_end.origin
	if connect_node1 is Control:
		line_start += xform_start.basis_xform_inv(connect_node1.size * 0.5)

	if connect_node2 is Control:
		line_end += xform_end.basis_xform_inv(connect_node2.size * 0.5)

	var line_direction := (line_end - line_start).normalized()
	if connect_node1 is Control:
		line_start = xform_start * get_rect_edge_position(
			Rect2(Vector2.ZERO, connect_node1.size),
			xform_start.basis_xform_inv(+line_direction).normalized(),
			connection_margin,
		)

	if connect_node2 is Control:
		line_end = xform_end * get_rect_edge_position(
			Rect2(Vector2.ZERO, connect_node2.size),
			xform_end.basis_xform_inv(-line_direction).normalized(),
			connection_margin,
		)

	if line_start.distance_squared_to(line_end) < line_min_length * line_min_length || (line_end - line_start).normalized().dot(line_direction) < 0.0:
		var line_start_plus_end := line_start + line_end
		line_start = (line_start_plus_end - line_direction * line_min_length) * 0.5
		line_end = (line_start_plus_end + line_direction * line_min_length) * 0.5

	var result_rect := Rect2(line_start, Vector2.ZERO).expand(line_end)
	position = result_rect.position
	size = result_rect.size

	_clickable_line_start = line_start
	_clickable_line_end = line_end

	var mouse_point := get_local_mouse_position()
	if _mouse_dragging == 1: line_start = mouse_point + position
	if _mouse_dragging == 2: line_end = mouse_point + position

	draw_set_transform(-position)
	draw_line(
		line_start + line_direction * line_arrow_size.y * _style_offsets[end_style1],
		line_end - line_direction * line_arrow_size.y * _style_offsets[end_style2],
		line_color,
		line_width,
	)
	draw_arrow(line_end, line_start, end_style1)
	draw_arrow(line_start, line_end, end_style2)

	# Drag Area Hint
	if allow_drag_pt1 && _is_in_radius(line_start, mouse_point):
		draw_circle(line_start, drag_hint_radius, drag_hint_color)

	if allow_drag_pt2 && _is_in_radius(line_end, mouse_point):
		draw_circle(line_end, drag_hint_radius, drag_hint_color)


func draw_arrow(line_start : Vector2, line_end : Vector2, style : int):
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


## Utility function to get a point on the intersection of the [code]rect[/code]'s border and the ray cast from its center in [code]direction[/code].
static func get_rect_edge_position(rect : Rect2, direction : Vector2, margin : float = 0.0) -> Vector2:
	var rect_size := rect.size + Vector2(margin, margin)
	var use_vertical := absf(direction.y) > rect_size.y / rect_size.length()
	if use_vertical:
		direction *= 1.0 / absf(direction.y) * rect_size.y * 0.5

	else:
		direction *= 1.0 / absf(direction.x) * rect_size.x * 0.5

	return rect.position + rect.size * 0.5 + direction


func _is_in_radius(circle_center : Vector2, point : Vector2):
	return (circle_center - position).distance_squared_to(point) <= drag_hint_radius * drag_hint_radius


func _gui_input(event : InputEvent):
	queue_redraw()
	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_point : Vector2 = event.position
		if !event.pressed && _mouse_dragging != 0:
			mouse_point += position
			var succeeded_on : Control
			var drag_reattach_condition_expr := Expression.new()
			var expr_params : Array = [
				connect_node1 if _mouse_dragging == 1 else connect_node2,
				connect_node2 if _mouse_dragging == 1 else connect_node1,
				self
			]
			if drag_reattach_condition_expr.parse(drag_reattach_condition, [&"from", &"other", &"line"]) != OK:
				# Couldn't parse expression, so don't call it.
				drag_reattach_condition_expr = null

			if _mouse_dragging == 1:
				for x in connect_node1.get_parent().get_children():
					if x == connect_node2 || !(x is Control) || !x.get_rect().has_point(mouse_point):
						continue

					if drag_reattach_condition_expr != null && !drag_reattach_condition_expr.execute(expr_params, x):
						continue

					connect_node1 = x
					succeeded_on = x
					break

			else:
				for x in connect_node2.get_parent().get_children():
					if x == connect_node1 || !(x is Control) || !x.get_rect().has_point(mouse_point):
						continue

					if drag_reattach_condition_expr != null && !drag_reattach_condition_expr.execute(expr_params, x):
						continue

					connect_node2 = x
					succeeded_on = x
					break

			if succeeded_on != null:
				var drag_reattach_call_on_success_expr := Expression.new()
				drag_reattach_call_on_success_expr.parse(drag_reattach_call_on_success, [&"from", &"other", &"line"])
				drag_reattach_call_on_success_expr.execute(expr_params, succeeded_on)

			_mouse_dragging = 0
			return

		_mouse_dragging = 0
		if allow_drag_pt1 && _is_in_radius(_clickable_line_start, mouse_point):
			_mouse_dragging = 1

		elif allow_drag_pt2 && _is_in_radius(_clickable_line_end, mouse_point):
			_mouse_dragging = 2


func _on_mouse_entered():
	_mouse_over = true
	queue_redraw()


func _on_mouse_exited():
	_mouse_over = false
	queue_redraw()
