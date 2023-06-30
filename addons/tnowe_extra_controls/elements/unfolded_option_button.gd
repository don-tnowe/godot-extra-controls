@tool
class_name UnfoldedOptionButton
extends VBoxContainer

## A list of option laid out as a vertical box of checkboxes. Supports multi-select similar to the "export_flags" export hint.

## Emitted when a button is checked.
signal value_changed(value : int)

## If enabled, allows multi-select.
@export var flags := false:
	set(v):
		flags = v
		_recreate_children()

	get: return flags

## Labels for each button.
@export var options : Array[String]:
	set(v):
		options = v.duplicate()
		_recreate_children()

	get: return options.duplicate()

## If [member flags] disabled, the currently selected option.[br]
## If enabled, check if an option is selected using: [code]value & (1 << OPTION_INDEX) != 0[/code].
@export var value := -1:
	set(v):
		v = clamp(v, 0, options.size() - 1 if !flags else (1 << options.size()) - 1)
		value = v

		var child_count = get_child_count()
		if (flags):
			for i in child_count:
				get_child(i).button_pressed = ((1 << i ) & v) != 0

		else:
			for i in child_count:
				get_child(i).button_pressed = i == v

	get: return value


func _recreate_children():
	for x in get_children():
		x.queue_free()

	var group := null if flags else ButtonGroup.new()
	for i in options.size():
		var option := CheckBox.new()
		option.button_group = group
		option.button_pressed = (value & i) != 0 if flags else value == i
		option.text = options[i]
		option.button_group = group
		add_child(option)
		option.toggled.connect(_on_button_toggled.bind(option))


func _on_button_toggled(toggled : bool, button : Button):
	var buttonIndex = button.get_index()
	if flags:
		if (toggled): value = value | (1 << buttonIndex)
		else: value = value & ~(1 << buttonIndex)

	else:
		if !toggled: return
		value = buttonIndex

	value_changed.emit(value)
