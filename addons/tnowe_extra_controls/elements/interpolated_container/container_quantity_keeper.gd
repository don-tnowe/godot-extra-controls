class_name ContainerQuantityKeeper
extends Node

## Keeps track quantity of duplicates in a node, such as an [InterpolatedContainer]. Only one instance of each matching node will be present, and can be added or removed if enough were added. May be infinite.

## The container to track.
@export var container : Node:
	set(v):
		if container != null:
			container.child_entered_tree.disconnect(_on_container_child_entered_tree)
			container.child_exiting_tree.disconnect(_on_container_child_exiting_tree)
			for k in _item_counts:
				for i in _item_counts[k] - 1:
					container.add_child(_item_by_key[k].duplicate())

			_item_counts.clear()
			_item_by_key.clear()

		container = v

		if v != null:
			v.child_entered_tree.connect(_on_container_child_entered_tree)
			v.child_exiting_tree.connect(_on_container_child_exiting_tree)
			if !v.is_inside_tree():
				await v.ready

			for x in v.get_children().duplicate():
				var item_key := _item_key_getter_expr.execute([], x)
				if !_item_counts.has(item_key):
					_item_counts[item_key] = 1
					_item_by_key[item_key] = x

				else:
					if _item_by_key[item_key] == x:
						continue

					_item_counts[item_key] += 1
					_changing_children += 1
					x.queue_free()

## Enable to prevent children from being deleted, allowing to infinitely take out items. It will still merge incoming duplicates.[br]
## Those that don't match the [member item_can_group] condition won't be deleted or duplicated.
@export var infinite_count := false

## The expression to retrieve an item's key, for comparing with already inserted items, incrementing quantity when a duplicate key is added. [br]
## For example, [code]text + self_modulate.to_html()[/code] will group nodes that match both text AND color.
@export var item_key_getter := "":
	set(v):
		item_key_getter = v
		_item_key_getter_expr.parse(v)

## The expression to check if an item can be grouped with its duplicates. Leave blank to allow everything. [br]
## [b]Warning: [/b] Some operators are unsupported in expressions, such as [code]is[/code] and ternary [code]if[/code]. Consider calling node's script methods after checking [code]has_method[/code].
@export var item_can_group := "":
	set(v):
		item_can_group = v
		_item_can_group_expr.parse(v)

var _item_key_getter_expr := Expression.new()
var _item_can_group_expr := Expression.new()
var _item_counts := {}
var _item_by_key := {}
var _changing_children := 0

## Returns [code]true[/code] if an item with the same key is inside the container.
func has(item : Node) -> bool:
	var new_key := _item_key_getter_expr.execute([], item)
	return _item_counts.has(new_key)

## Returns the quantity of an item's duplicates.
func get_count(item : Node) -> int:
	var new_key := _item_key_getter_expr.execute([], item)
	return _item_counts.get(new_key, 0)

## Set the quantity of an item's duplicates, creating a duplicate if there was none or removing an instance if set to zero.
func set_count(item : Node, to_count : int):
	var new_key := _item_key_getter_expr.execute([], item)
	if !_item_counts.has(new_key):
		container.add_child(item.duplicate())

	elif to_count <= 0:
		_item_by_key[new_key].queue_free()
		_item_counts.erase(new_key)
		_item_by_key.erase(new_key)


func _on_container_child_entered_tree(child : Node):
	if item_can_group != "" && !_item_can_group_expr.execute([], child):
		return

	if _changing_children > 0:
		_changing_children -= 1
		return

	var item_key := _item_key_getter_expr.execute([], child)
	if _item_counts.has(item_key):
		_item_counts[item_key] += 1

		_changing_children += 1
		_item_by_key[item_key].queue_free.call_deferred()

	else:
		_item_counts[item_key] = 1

	_item_by_key[item_key] = child


func _on_container_child_exiting_tree(child : Node):
	if item_can_group != "" && !_item_can_group_expr.execute([], child):
		return

	if _changing_children > 0:
		_changing_children -= 1
		return

	var item_key := _item_key_getter_expr.execute([], child)
	if infinite_count || _item_counts.get(item_key, 0) > 1:
		var new_node := child.duplicate()
		var old_child_index := child.get_index()

		_changing_children += 1
		container.add_child.call_deferred(new_node)
		container.move_child.call_deferred(new_node, old_child_index)

		_item_counts[item_key] -= 1
		_item_by_key[item_key] = new_node

	else:
		_item_counts.erase(item_key)
		_item_by_key.erase(item_key)
