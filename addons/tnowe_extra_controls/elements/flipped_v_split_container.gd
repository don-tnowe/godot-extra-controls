class_name FlippedVSplitContainer
extends VSplitContainer

## A split container that is anchored to the other side. When it's resized by a parent, the other child item keeps its size.

var _last_rect_size := 0.0


func _ready():
	_last_rect_size = size.y
	resized.connect(_on_resized)


func _on_resized():
	split_offset += size.y - _last_rect_size
	_last_rect_size = size.y
