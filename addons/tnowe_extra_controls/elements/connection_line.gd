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

@export_group("Style")
## The line's color.
@export var line_color := Color.BLACK
## Line width, affecting the clickable area.
@export var line_width := 4.0
## The spacing between this connection's edge and the node's rect.
@export var connection_margin := 4.0
## The style of the end touching [member connect_node1].
@export_enum("None", "Arrow", "Circle", "Line") var end_style1 := 0
## The style of the end touching [member connect_node2].
@export_enum("None", "Arrow", "Circle", "Line") var end_style2 := 1
## The size of the arrow at the tip of the line. Affects [member end_style1] and [member end_style2] differently.
@export var line_arrow_size := Vector2(6.0, 8.0)
## Whether to redraw the line every [code]_process()[/code]. Otherwise, update it with [method CanvasItem.queue_redraw].
@export var redraw_every_frame := true:
	set(v):
		redraw_every_frame = v
		set_process(v)

var _mouse_over := false
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
	if !Rect2(Vector2.ZERO, size).grow(line_width).has_point(point):
		return false

	if (_clickable_line_end == _clickable_line_start):
		return (point - position).length_squared() <= line_width * line_width

	var delta := _clickable_line_end - _clickable_line_start
	var h := clampf(point.dot(delta) / delta.dot(delta), 0.0, 1.0);
	return (point - h * delta).length_squared() <= line_width * line_width * 0.25;


func _draw():
	var line_start : Vector2 = connect_node1.position
	var line_end : Vector2 = connect_node2.position
	if connect_node1 is Control:
		line_start += connect_node1.size * 0.5

	if connect_node2 is Control:
		line_end += connect_node2.size * 0.5

	var line_direction := (line_end - line_start).normalized()
	if connect_node1 is Control:
		line_start = get_rect_edge_position(connect_node1.get_rect(), +line_direction, connection_margin)

	if connect_node2 is Control:
		line_end = get_rect_edge_position(connect_node2.get_rect(), -line_direction, connection_margin)

	var result_rect := Rect2(line_start, Vector2.ZERO).expand(line_end)
	position = result_rect.position
	size = result_rect.size

	_clickable_line_start = line_start
	_clickable_line_end = line_end
	draw_set_transform(-position)
	draw_line(
		line_start + line_direction * line_arrow_size.y * _style_offsets[end_style1],
		line_end - line_direction * line_arrow_size.y * _style_offsets[end_style2],
		line_color,
		line_width,
	)
	draw_arrow(line_end, line_start, end_style1)
	draw_arrow(line_start, line_end, end_style2)


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



static func get_rect_edge_position(rect : Rect2, direction : Vector2, margin : float = 0.0) -> Vector2:
	var rect_size := rect.size + Vector2(margin, margin)
	var use_vertical := absf(direction.y) > rect_size.y / rect_size.length()
	if use_vertical:
		direction *= 1.0 / absf(direction.y) * rect_size.y * 0.5

	else:
		direction *= 1.0 / absf(direction.x) * rect_size.x * 0.5

	return rect.position + rect.size * 0.5 + direction


func _gui_input(_event : InputEvent):
	queue_redraw()


func _on_mouse_entered():
	_mouse_over = true
	queue_redraw()


func _on_mouse_exited():
	_mouse_over = false
	queue_redraw()
