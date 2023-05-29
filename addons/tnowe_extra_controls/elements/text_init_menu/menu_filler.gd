extends RefCounted

const MenuItem := preload("res://addons/tnowe_extra_controls/elements/text_init_menu/menu_filler_item.gd")

var _lines := []
var _item_icons := []
var _item_shortcuts := []


func _init(text : String, item_icons : Array[Texture2D], item_shortcuts : Array[Shortcut]):
  _lines = text.split('\n')
  _item_icons = item_icons
  _item_icons.resize(_lines.size())
  _item_shortcuts = item_shortcuts
  _item_shortcuts.resize(_lines.size())


func get_from_popup_items(p : PopupMenu, submenu_level : int = 0):
  var items := ""
  for i in p.get_item_count():
    var new_item := MenuItem.new()
    new_item.id = p.get_item_id(i)
    new_item.name = p.get_item_text(i)
    new_item.checkable_type = 2 if p.is_item_radio_checkable(i) else 1 if p.is_item_checkable(i) else 0
    new_item.checked = p.is_item_checked(i)
    new_item.disabled = p.is_item_disabled(i)
    new_item.separator = p.is_item_separator(i)
    new_item.submenu_level = submenu_level
    items += new_item.to_string()
    new_item.free()

  return items


func fill_menu(p : PopupMenu, start_from_line : int = 0, submenu_level : int = 0):
  var item_index := 0
  var last_text := ""
  p.clear()
  for i in range(start_from_line, _lines.size()):
    if (_lines[i] == ""): continue

    var item := MenuItem.new(_lines[i])
    if (item.submenu_level < submenu_level): return item_index
    if (item.submenu_level > submenu_level):    
      var new_submenu := PopupMenu.new()
      new_submenu.name = last_text
      p.add_child(new_submenu)
      p.set_item_submenu(item_index - 1, last_text)
      i += fill_menu(new_submenu, i, item.submenu_level)
      continue

    p.add_item(item.text, item.id)
    p.set_item_checked(item_index, item.checked)
    p.set_item_as_checkable(item_index, item.checkable_type == 1)
    p.set_item_as_radio_checkable(item_index, item.checkable_type == 2)
    p.set_item_as_separator(item_index, item.separator)
    p.set_item_disabled(item_index, item.disabled)

    p.set_item_shortcut(item_index, _item_shortcuts[i], true)
    p.set_item_icon(item_index, _item_icons[i])

    last_text = item.name
    item_index += 1
    item.free()

  return item_index
