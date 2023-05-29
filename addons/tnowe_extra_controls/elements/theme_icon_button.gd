@tool
class_name ThemeIconButton
extends Button

## A button that grabs its icon from a Theme.

## The theme class to grab the icon from.
@export var icon_class := &"EditorIcons":
	set(v):
		icon_class = v
		update_icon()

## The theme icon name to grab the icon from.
@export var icon_name := &"Node":
	set(v):
		icon_name = v
		update_icon()


func update_icon():
	if has_theme_icon(icon_name, icon_class):
		icon = get_theme_icon(icon_name, icon_class)


func _ready():
	update_icon()
