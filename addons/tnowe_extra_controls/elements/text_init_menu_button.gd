@tool
class_name TextInitMenuButton
extends MenuButton

## A MenuButton initialized with text. Supports submenus.
##
## Signals of all submenus are broadcast through the popup. Get it using [method MenuButton.get_popup]._add_constant_central_force[br]
## You can use the class in [code]elements/text_init_menu/menu_filler.gd[/code] to initialize your menus with more control.

const MenuFiller := preload("res://addons/tnowe_extra_controls/elements/text_init_menu/menu_filler.gd")

## The menu's items, as text.[br]
## Try:[br]
## [codeblock]
## 0 : NormalItem
## 1 : Checkable Item [ ]
## 2 : Checked Item [X]
## 999 : Submenu:
## >3 : Hehehe, you found me!
## >4 : tshhhhhsk ( )
## >5 : (this was a radio)
## >998 ---
## >6 X (alright, I'll see myself out)
## 997 ---
## 7 : The Final Item
## [/codeblock][br]
##
@export_multiline var items := ""
## The menu's icons, in order. For lines without an icon item, just leave the element empty.
@export var item_icons : Array[Texture2D]
## The menu's shortcuts, in order. For lines without an item with a shortcut, just leave the element empty.
@export var item_shortcuts : Array[Shortcut]

## Click to update the menu.
@export var force_update := true:
	set(_v):
		if is_inside_tree(): fill()

## Click to fill the [member items] property with the menu's items.
@export var load_from_items := true:
	set(_v):
		if is_inside_tree(): get_from_current_items()

var _filler : MenuFiller


func _ready():
	get_popup().child_entered_tree.connect(_on_submenu_entered_tree)


func fill():
	_filler = MenuFiller.new(items, item_icons, item_shortcuts);
	for x in get_popup().get_children():
		if x is PopupMenu:
			x.free();

	return _filler.fill_menu(get_popup());


func get_from_current_items():
	_filler = MenuFiller.new(items, item_icons, item_shortcuts);
	items = _filler.get_from_popup_items(get_popup());


func _on_submenu_id_pressed(id : int):
	get_popup().id_pressed.emit(id)


func _on_submenu_entered_tree(node : Node):
	if node is PopupMenu:
		node.child_entered_tree.connect(_on_submenu_entered_tree)
		node.id_pressed.connect(_on_submenu_id_pressed)
