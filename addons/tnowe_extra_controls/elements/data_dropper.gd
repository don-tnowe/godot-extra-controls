extends Control

signal data_drop_request(at_position : Vector2, data : Variant)
signal data_dropped(at_position : Vector2, data : Variant)


func _can_drop_data(at_position, data):
	data_drop_request.emit(at_position, data)
	return true


func _drop_data(at_position, data):
	data_dropped.emit(at_position, data)
