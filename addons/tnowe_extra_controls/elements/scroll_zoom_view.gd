@tool
class_name ScrollZoomView
extends MarginContainer

## A container that offsets and/or smoothly resizes its child control when panned with mouse pointer, or the scroll wheel is used.

## The mouse buttons that will scroll through the view when panning.
@export_flags("Left", "Right", "Middle", "Back:128", "Forward:256") var pan_button := 7
## The size of the child if [member zoom_amount] is 1.0. Set to negative to make it inherit this node's size.
@export var child_size := Vector2(-1.0, -1.0):
	set(v):
		child_size = v
		if !is_inside_tree(): await ready
		var child := get_child(0)
		child.size.x = v.x if v.x >= 0.0 else size.x
		child.size.y = v.y if v.y >= 0.0 else size.y
## The minimum and maximum zoom amount.
@export var zoom_range := Vector2(0.125, 8.0)
## The smallest dragging distance to be considered a valid panning gesture, in pixels.
@export var pan_min_distance := 4.0
## The applied zoom amount with one tick of the scroll wheel, multiplicative.
@export_range(1.0, 2.0) var zoom_step := 1.2
## The speed at which the visible zoom amount moves toward the target amount, 0-1 factor. [br]
## Set to 0 to prevent zoom. Set to 1 to make it instant.
@export_range(0.0, 1.0) var zoom_interp_speed := 0.25
## If [code]true[/code], zooming tries to ensure that the mouse cursor's position stays in place while zooming. Otherwise, use this node's center as pivot.
@export var zoom_use_mouse_as_pivot := true

@export_group("State")
## The current zoom amount. If set at runtime, will interpolate smoothly using [member zoom_interp_speed].
@export var zoom_amount := 1.0:
	set(v):
		zoom_amount = v
		set_process(true)
## The current panning position, relative to this node's origin.
@export var scroll_offset := Vector2():
	set(v):
		scroll_offset = v
		if !is_inside_tree(): await ready
		get_child(0).position = v


var _input_dragging := false
var _input_drag_start := Vector2()
var _input_drag_can_move := false
var _zoom_pivot := Vector2()
var _zoom_visible := 1.0:
	set(v):
		_zoom_visible = v
		if !is_inside_tree(): await ready
		get_child(0).scale = Vector2(v, v)


func _process(_delta : float):
	if !zoom_use_mouse_as_pivot:
		_zoom_pivot = get_global_transform().basis_xform_inv(size * 0.5)

	var old_zoom := _zoom_visible
	_zoom_visible = lerp(_zoom_visible, zoom_amount, zoom_interp_speed)

	var scroll_offset_result := scroll_offset - _zoom_pivot
	scroll_offset_result *= _zoom_visible / old_zoom
	scroll_offset = scroll_offset_result + _zoom_pivot

	if is_equal_approx(zoom_amount, _zoom_visible):
		_zoom_visible = zoom_amount
		set_process(false)


func _gui_input(event : InputEvent):
	if event is InputEventMouseMotion:
		if !_input_dragging:
			_zoom_pivot = get_global_transform().affine_inverse() * event.global_position
			return

		if !_input_drag_can_move:
			if ((event.position - _input_drag_start) / zoom_amount).length_squared() > pan_min_distance * pan_min_distance:
				_input_drag_can_move = true

			return

		scroll_offset += event.relative

	if event is InputEventMouseButton:
		if !event.pressed || event.button_mask & pan_button != 0:
			_input_dragging = event.pressed
			_input_drag_start = event.position
			_input_drag_can_move = false

		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_amount = minf(zoom_amount * (1.0 + (zoom_step - 1.0) * event.factor), zoom_range.y)

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_amount = maxf(zoom_amount / (1.0 + (zoom_step - 1.0) * event.factor), zoom_range.x)
