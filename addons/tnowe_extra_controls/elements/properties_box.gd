class_name PropertiesBox
extends VBoxContainer

## A form to input multiple values of different types. Supports numbers, strings, and options (as in [UnfoldedOptionButton])

signal value_changed(key : StringName, new_value : Variant)
signal number_changed(key : StringName, new_value : float)
signal string_changed(key : StringName, new_value : String)
signal bool_changed(key : StringName, new_value : bool)

const UnfoldedOptionButton := preload("res://addons/tnowe_extra_controls/elements/unfolded_option_button.gd")

@export var _group_indent := 8.0

var _keys := {}
var _editors := []
var _group_stack := []

## Removes all property editors.
func clear():
	for x in get_children():
		x.queue_free()

	_keys.clear()
	_editors.clear()
	_group_stack.clear()

## Adds a [CheckBox]. Retrieve the value with [method get_bool].
func add_bool(key : StringName, value : bool = false):
	var editor = CheckBox.new()
	editor.button_pressed = value
	_add_property_editor(key, editor, editor.toggled, _on_bool_changed)

## Adds a [SpinBox]. Retrieve the value with [method get_float] or [method get_int].
## If both [code]minvalue[/code] and [code]maxvalue[/code] are specified, also creates an [HSlider].
func add_int(key : StringName, value : int = 0, minvalue : int = -2147483648, maxvalue : int = 2147483648):
	add_float(key, value, minvalue, maxvalue, 1)

## Adds a [SpinBox]. Retrieve the value with [method get_float] or [method get_int].
## If both [code]minvalue[/code] and [code]maxvalue[/code] are specified, also creates an [HSlider].
func add_float(key : StringName, value : float = 0.0, minvalue : float = -99999900000.0, maxvalue : float = 99999900000.0, step : float = 0.0001):
	var editor = SpinBox.new()
	var is_slider = minvalue > -2147483648 && maxvalue < 2147483648
	editor.value = value
	editor.step = step
	editor.min_value = minvalue
	editor.max_value = maxvalue
	_add_property_editor(key, editor, editor.value_changed, _on_number_changed)
	if is_slider:
		var box = HBoxContainer.new()
		var slider = HSlider.new()
		editor.get_parent().add_child(box)
		editor.get_parent().remove_child(editor)
		box.add_child(editor)
		box.add_child(slider)

		box.size_flags_horizontal = SIZE_EXPAND_FILL
		slider.size_flags_horizontal = SIZE_EXPAND_FILL
		slider.size_flags_vertical = SIZE_FILL
		editor.size_flags_horizontal = SIZE_FILL

		slider.value = value
		slider.step = step
		slider.min_value = minvalue
		slider.max_value = maxvalue

		slider.value_changed.connect(editor.set_value)
		editor.value_changed.connect(slider.set_value)
		slider.value_changed.connect(_on_number_changed.bind(key))

## Adds a [LineEdit]. Retrieve the value with [method get_string].
func add_string(key : StringName, value : String = ""):
	var editor = LineEdit.new()
	editor.text = value
	_add_property_editor(key, editor, editor.text_changed, _on_string_changed)

## Adds an [UnfoldedOptionButton]. Retrieve the value with [method get_option].
## Options are input as an array of strings.
func add_options(key : StringName, options : Array, default_value : int = 0, flags : bool = false):
	var editor = UnfoldedOptionButton.new()
	var options_cast : Array[String] = []
	options_cast.resize(options.size())
	for i in options.size():
		options_cast[i] = options[i]

	editor.flags = flags
	editor.options = options_cast
	editor.value = default_value
	_add_property_editor(key, editor, editor.value_changed, _on_number_changed)

## Adds an [UnfoldedOptionButton]. Retrieve the value with [method get_option].
## Option names are retrieved from a Locale Prefix, appending a 0-based index then translating.
## If it's "format_", the options are "format_0", "format_1", "format_2"...
func add_options_locale(key : StringName, option_locale_prefix : String, option_count : int, default_value : int = 0, flags : bool = false):
	var options = []
	options.resize(option_count)
	for i in option_count:
		options[i] = option_locale_prefix + str(i)

	add_options(key, options, default_value, flags)

## Creates a foldable group to add properties into. Groups can be nested.
## To go back to adding properties in the group above, call [method end_group].
func add_group(label : String):
	var title = Button.new()
	var outer_box = VBoxContainer.new()
	var offset_box = HBoxContainer.new()
	var offset = Control.new()
	var inner_box = VBoxContainer.new()

	title.text = label
	title.toggle_mode = true
	title.button_pressed = true
	title.alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.icon = get_theme_icon("arrow", "Tree")
	title.toggled.connect(offset_box.set_visible)
	offset_box.size_flags_horizontal = SIZE_EXPAND_FILL
	offset_box.add_theme_constant_override("separation", 0)
	offset.custom_minimum_size = Vector2(_group_indent, 0)
	inner_box.size_flags_horizontal = SIZE_EXPAND_FILL

	outer_box.add_child(title)
	outer_box.add_child(offset_box)
	offset_box.add_child(offset)
	offset_box.add_child(inner_box)
	_get_box().add_child(outer_box)

	_group_stack.append(inner_box)

## Ends the last group added by [method add_group].
func end_group():
	if _group_stack.size() >= 1:
		_group_stack.remove_at(_group_stack.size() - 1)

## Get a dictionary containing all keys and values.
func get_all() -> Dictionary:
	var result = {}
	for x in _keys:
		result[x.key] = get_value_at(x.value)

	return result

## Retrieve a value, whatever the type.
func get_value(key : StringName) -> Variant:
	return get_value_at(_keys[key])

## Retrieve a value of whatever type, from a property by its index in the box.
func get_value_at(index : int) -> Variant:
	var editor = _editors[index]
	if editor is Button: return editor.pressed
	if editor is SpinBox: return editor.value
	if editor is LineEdit: return editor.text
	if editor is TextEdit: return editor.text
	if editor is UnfoldedOptionButton: return editor.value
	return null

## Retrieve a boolean.
func get_bool(key : StringName) -> bool:
	var editor = _editors[_keys[key]]
	return editor.pressed

## Retrieve a number or option.
func get_int(key : StringName) -> int:
	var editor = _editors[_keys[key]]
	if editor is SpinBox:
		return editor.value

	elif editor is UnfoldedOptionButton:
		return editor.value

	return 0

## Retrieve a number.
func get_float(key : StringName) -> float:
	var editor = _editors[_keys[key]]
	return editor.value

## Retrieve a string.
func get_string(key : StringName) -> String:
	var editor = _editors[_keys[key]]
	if editor is LineEdit:
		return editor.text

	elif editor is TextEdit:
		return editor.text

	return ""

## Retrieve an option as an integer number.
func get_option(key : StringName) -> int:
	return get_int(key)


func _get_box() -> Control:
	if _group_stack.size() == 0:
		return self

	else:
		return _group_stack[_group_stack.size() - 1]


func _add_property_editor(key : StringName, editor : Control, editor_signal : Signal, signal_handler : Callable):
	_keys[key] = _editors.size()
	_editors.append(editor)

	var box = HBoxContainer.new()
	var label = Label.new()
	label.text = key
	label.clip_text = true
	label.size_flags_vertical = 0
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	editor.size_flags_horizontal = SIZE_EXPAND_FILL

	box.add_child(label)
	box.add_child(editor)
	_get_box().add_child(box)

	editor_signal.connect(signal_handler.bind(key))


func _on_number_changed(value : float, key : StringName):
	number_changed.emit(key, value)
	value_changed.emit(key, value)


func _on_string_changed(value : String, key : StringName):
	string_changed.emit(key, value)
	value_changed.emit(key, value)


func _on_bool_changed(value : bool, key : StringName):
	bool_changed.emit(key, value)
	value_changed.emit(key, value)
