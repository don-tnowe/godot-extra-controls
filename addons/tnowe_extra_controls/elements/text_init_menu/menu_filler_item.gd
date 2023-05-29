extends Object

const INDENT_CHAR = ">"

var id := 0
var name := ""
var checkable_type := 0
var checked := false
var disabled := false
var separator := false
var submenu_level = 0


func _init(text : String = ""):
  if text == "": return

  text = text.strip_edges(true, false)
  submenu_level = 0
  while text.begins_with(INDENT_CHAR):
    text = text.substr(INDENT_CHAR.length())
    submenu_level += 1

  var last_token := text.substr(text.rfind(" "))
  if (last_token.length() == 3):
    if (last_token[0] == "[" && last_token[2] == "]"):
      checkable_type = 1
      checked = last_token[1] != " "
      text = text.left(text.length() - 4)

    if (last_token[0] == "(" && last_token[2] == ")"):
      checkable_type = 1
      checked = last_token[1] != " "
      text = text.left(text.length() - 4)

  var id_length := text.find(" ")
  id = int(text.left(id_length))
  var prefix_end := text.find(" ", id_length + 1)
  if (prefix_end == -1 || prefix_end == id_length):
    separator = true
    return

  var prefix := text.substr(id_length, prefix_end - id_length + 1)
  if (prefix[1] == "X"): disabled = true
  elif (prefix[1] != ":"): separator = true
  name = text.substr(prefix_end + 1)


func _to_string():
  var indent = INDENT_CHAR.repeat(submenu_level)
  var prefix = " : "
  if disabled: prefix = " X "
  if separator: prefix = " --- "
  var check = ""
  if checkable_type == 1: check = " [x]" if checked else " [ ]"
  if checkable_type == 2: check = " (x)" if checked else " ( )"
  return "".join([indent, id, prefix, name, check, "\n"])
