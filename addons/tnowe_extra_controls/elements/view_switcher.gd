@tool
class_name ViewSwitcher
extends Control

## When a child becomes visible, hides all other children. Optional, background to show while any item is visible.

## Shown when at least one other child is visible, hidden when none are visible.
@export var background : NodePath

var _hiding := false;
var _was_visible := false;


func _init():
	child_entered_tree.connect(_on_child_entered_tree)


func _on_child_entered_tree(child : Node):
	if (child is CanvasItem):
		child.visibility_changed.connect(_on_child_visibility_changed.bind(child));


func _on_child_visibility_changed(child : CanvasItem):
	if _was_visible != visible:
		_was_visible = visible;
		if child.visible: return;

	if _hiding: return;

	_hiding = true;
	if child.visible:
		for x in get_children():
			if (x is CanvasItem):
				x.hide();

		child.show();
		if has_node(background): get_node(background).show();

	else:
		if has_node(background): get_node(background).hide();

	_hiding = false;
