@tool
class_name RadialContainer
extends Container

## Radial menu container. Radius is based on own size. Supports texturing, tweening and [Control.size_flags_stretch_ratio].

## Behaviour when an index goes beyond the size of an array.
enum OutOfBoundsBehaviour {
	CLAMP, ## Use the last array item.
	REPEAT, ## Repeat from index 0 in the same order.
	PINGPONG, ## Repeat in reverse order, starting from previous item.
}

## Starting angle offset, 0-1 range.
@export_range(0, 1) var progress_offset := 0.0:
	set(v):
		progress_offset = v
		queue_sort()
		queue_redraw()
## Width of the border in between sectors.
@export var border_between_width := 4.0:
	set(v):
		if v < 0.0: v = 0.0
		border_between_width = v
		queue_redraw()
## Minimum total number of points on the circle.
@export_range(2, 3600) var sector_points := 60:
	set(v):
		if v < 2: v = 2
		sector_points = v
		queue_redraw()

## [RadialContainerTheme] applied to all objects.
@export var radial_theme : RadialContainerTheme:
	set(v):
		if radial_theme != null:
			radial_theme.changed.disconnect(_on_radial_theme_changed)

		radial_theme = v
		if v != null:
			v.changed.connect(_on_radial_theme_changed)

		_on_radial_theme_changed()
## [RadialContainerTheme] applied to each individual child. Color, textures and item positions are overriden entirely, while others are combined with [member radial_theme]. [br]
## Use [method set_theme_at] and [method set_theme_tweened] to change an item's theme and update visuals.
@export var radial_theme_per : Array[RadialContainerTheme]:
	set(v):
		for x in radial_theme_per:
			if x != null && x.changed.is_connected(_on_radial_theme_changed):
				x.changed.disconnect(_on_radial_theme_changed)

		radial_theme_per = v
		for x in v:
			if x != null && !x.changed.is_connected(_on_radial_theme_changed):
				x.changed.connect(_on_radial_theme_changed)

		_on_radial_theme_changed()
## Behaviour when new children get added, but [member radial_theme_per] is not expanded.
@export var radial_theme_per_behaviour : OutOfBoundsBehaviour:
	set(v):
		radial_theme_per_behaviour = v
		_on_radial_theme_changed()

var _child_stretch_ratio_sum := 0.0
var _child_stretch_sum_until : Array[float] = []

## Retrieves the item index from an angle, in radians, on the wheel.
func get_index_from_angle(angle_degrees : float) -> int:
	var angle_progress := fposmod(angle_degrees / TAU - progress_offset + 0.5, 1.0)
	for i in _child_stretch_sum_until.size() - 1:
		if _child_stretch_sum_until[i + 1] >= angle_progress:
			return i

	return 0

## Retrieves the item index from an angle, in degrees, on the wheel.
func get_index_from_angle_degrees(angle_degrees : float) -> int:
	return get_index_from_angle(deg_to_rad(angle_degrees))

## Retrieves the item index from a direction relative to circle's center. Does not check if [method is_inside_circle].
func get_index_from_direction(direction : Vector2) -> int:
	var angle_progress := fposmod(direction.angle() / TAU - progress_offset + 0.5, 1.0)
	for i in _child_stretch_sum_until.size() - 1:
		if _child_stretch_sum_until[i + 1] > angle_progress:
			return i

	return 0

## Retrieves the item index from a position in global space. Does not check if [method is_inside_circle].
func get_index_from_global_position(global_pos : Vector2) -> int:
	var from_center_pos := -(get_global_transform().affine_inverse() * global_pos - size * 0.5)
	var angle_progress := fposmod(from_center_pos.angle() / TAU - progress_offset + 0.5, 1.0)
	for i in _child_stretch_sum_until.size() - 1:
		if _child_stretch_sum_until[i + 1] > angle_progress:
			return i

	return 0

## Returns [code]true[/code] if a position in global space is overlapping the visible circle or sector. [br]
## "Bound" parameters specify if [member RadialContainerTheme.radius_factor_outer] and [member RadialContainerTheme.radius_factor_inner] should be considered. [br]
## [code]use_specific_sector[/code] specifies whether the circle should use [member radial_theme_per] themes, or only operate on the shared, size-constrained radius.
func is_inside_circle(global_pos : Vector2, inner_bound : bool = true, outer_bound : bool = true, use_specific_sector : bool = true) -> bool:
	var from_center_pos := -(get_global_transform().affine_inverse() * global_pos - size * 0.5)
	var dist_factor := from_center_pos.length() / minf(size.x, size.y) * 2.0
	var selected_theme : RadialContainerTheme
	if use_specific_sector:
		selected_theme = get_index_with_oob(get_index_from_direction(from_center_pos), radial_theme_per, radial_theme_per_behaviour, null)
		if selected_theme == null && radial_theme == null:
			return !outer_bound || dist_factor <= 1.0

	if radial_theme == null:
		return (
			(!outer_bound || dist_factor <= selected_theme.radius_factor_outer)
			&& (!inner_bound || dist_factor >= selected_theme.radius_factor_inner)
		)

	return (
		(!outer_bound || dist_factor <= selected_theme.radius_factor_outer * radial_theme.radius_factor_outer)
		&& (!inner_bound || dist_factor >= selected_theme.radius_factor_inner * radial_theme.radius_factor_inner)
	)


## Set the [RadialContainerTheme] for a specific sector, updating all visuals and expanding the array of needed.
func set_theme_at(index : int, new_theme : RadialContainerTheme):
	if index >= radial_theme_per.size():
		var new_themes := radial_theme_per.duplicate()
		var count := radial_theme_per.size()
		while index >= count:
			radial_theme_per.append(get_index_with_oob(count, new_themes, radial_theme_per_behaviour))
			count += 1

	radial_theme_per[index] = new_theme
	radial_theme_per = radial_theme_per

## Set the [RadialContainerTheme] for a specific sector, animated. A copied theme will be created, its properties will transition smoothly to the specified theme's properties.
func set_theme_tweened(
	index : int, new_theme : RadialContainerTheme, tween_time : float,
	tween_trans := Tween.TRANS_LINEAR, tween_ease := Tween.EASE_OUT
) -> Tween:
	if index >= radial_theme_per.size():
		var new_themes := radial_theme_per.duplicate()
		var count := radial_theme_per.size()
		while index >= count:
			radial_theme_per.append(get_index_with_oob(count, new_themes, radial_theme_per_behaviour))
			count += 1

	var new_new_theme := RadialContainerTheme.new()
	var tween := create_tween().set_ease(tween_ease).set_trans(tween_trans)
	var old_theme := radial_theme_per[index] if radial_theme_per[index] != null else radial_theme
	tween.tween_method(func(x : float): new_new_theme.lerp_theme(old_theme, new_theme, x), 0.0, 1.0, tween_time)

	radial_theme_per[index] = new_new_theme
	radial_theme_per = radial_theme_per
	return tween

## Utility function to apply [enum OutOfBoundsBehaviour] to an array index, then retrieve the array's item.
static func get_index_with_oob(index : int, array : Array, oob : OutOfBoundsBehaviour, default_if_empty = null):
	var max_index := array.size()
	if max_index < 1:
		return default_if_empty

	match oob:
		OutOfBoundsBehaviour.CLAMP:
			return array[mini(index, max_index - 1)]
		OutOfBoundsBehaviour.REPEAT:
			return array[index % max_index]
		OutOfBoundsBehaviour.PINGPONG:
			var iter := (index) / (max_index - 1)
			if iter % 2 == 0:
				return array[index % (max_index - 1)]
			else:
				return array[(max_index - 1) - index % (max_index - 1)]

## Utility function to fill the array with one value but a specific index with another value.
static func set_all_except(all_value, except_value, all_count : int, except_index : int, array : Array):
	if all_count > 1:
		array.resize(all_count)

	array.fill(all_value)
	array[except_index] = except_value


func _has_point(point : Vector2):
	var radius := minf(size.x, size.y) * 0.5
	return (point - size * 0.5).length_squared() <= radius * radius


func _notification(what : int):
	if what == NOTIFICATION_SORT_CHILDREN:
		_child_stretch_ratio_sum = 0.0
		var children := get_children()
		var children_visible := 0
		for x in children:
			if x is Control && x.visible:
				_child_stretch_ratio_sum += x.size_flags_stretch_ratio
				children_visible += 1

		var child_index := 0
		var child_stretch_ratio_sum_current := 0.0
		var child_stretch_ratio_sum_next := 0.0
		_child_stretch_sum_until.resize(children.size() + 1)
		_child_stretch_sum_until.fill(1.0)
		for x in children:
			if x is Control && x.visible:
				_child_stretch_sum_until[child_index] = child_stretch_ratio_sum_current
				child_stretch_ratio_sum_next = child_stretch_ratio_sum_current + x.size_flags_stretch_ratio / _child_stretch_ratio_sum
				_sort_child(x, child_index, child_stretch_ratio_sum_current, child_stretch_ratio_sum_next)
				child_stretch_ratio_sum_current = child_stretch_ratio_sum_next
				child_index += 1

		queue_redraw()


func _sort_child(child : Control, child_index : int, progress_min : float, progress_max : float):
	var radius := minf(size.x, size.y) * 0.5
	var sector_theme : RadialContainerTheme = RadialContainerTheme.new().merge(
		get_index_with_oob(child_index, radial_theme_per, radial_theme_per_behaviour, null),
		radial_theme,
	)
	child.size = child.get_combined_minimum_size()
	child.scale = sector_theme.item_scale
	child.position = (
		size * 0.5
		+ Vector2(lerp(
			sector_theme.radius_factor_inner,
			sector_theme.radius_factor_outer,
			sector_theme.item_radius_factor,
			) * radius, 0)
			.rotated(TAU * (progress_min + progress_max + progress_offset + progress_offset) * 0.5)
		- child.size * child.scale * 0.5
	)


func _draw():
	var global_radius := minf(size.x, size.y) * 0.5
	var inner_radius_f := 0.0
	if radial_theme != null:
		global_radius *= radial_theme.radius_factor_outer
		inner_radius_f = radial_theme.radius_factor_inner

	for i in _child_stretch_sum_until.size() - 1:
		var sector_theme : RadialContainerTheme = get_index_with_oob(i, radial_theme_per, radial_theme_per_behaviour, null)
		if radial_theme == null:
			inner_radius_f = 1.0

		var border_angle_rad := asin(
			0.5 * border_between_width
			/ (global_radius * (1.0 if sector_theme == null else sector_theme.radius_factor_outer))
		) * 0.5
		var border_angle_rad_inner := asin(
			0.5 * border_between_width
			/ (global_radius * (1.0 if sector_theme == null else sector_theme.radius_factor_inner) * inner_radius_f)
		) * 0.5
		if is_nan(border_angle_rad_inner):
			border_angle_rad_inner = 0.0

		var start_rad := (progress_offset + _child_stretch_sum_until[i]) * TAU + border_angle_rad
		var end_rad := (progress_offset + _child_stretch_sum_until[i + 1]) * TAU - border_angle_rad
		if end_rad <= start_rad:
			var avg := (end_rad + start_rad) * 0.5
			start_rad = avg
			end_rad = avg

		var start_rad_inner := (progress_offset + _child_stretch_sum_until[i]) * TAU + border_angle_rad_inner
		var end_rad_inner := (progress_offset + _child_stretch_sum_until[i + 1]) * TAU - border_angle_rad_inner
		if end_rad_inner <= start_rad_inner:
			var avg := (end_rad_inner + start_rad_inner) * 0.5
			start_rad_inner = avg
			end_rad_inner = avg

		var sector_points_cur := (maxi((end_rad - start_rad) / TAU * sector_points, 2)) * 2
		var sector_points_step := 2.0 / (sector_points_cur - 2)

		var result_positions : Array[Vector2] = []
		var result_uv : Array[Vector2] = []
		result_positions.resize(sector_points_cur)
		result_uv.resize(sector_points_cur)

		for j in sector_points_cur / 2:
			var pt_angle := lerp(start_rad, end_rad, sector_points_step * j)
			var pt_angle_inner := lerp(start_rad_inner, end_rad_inner, sector_points_step * j)
			var pt_uv := Vector2(cos(pt_angle), sin(pt_angle))
			var pt_uv_inner := Vector2(cos(pt_angle_inner), sin(pt_angle_inner)) * inner_radius_f
			result_uv[j] = (pt_uv + Vector2.ONE) * 0.5

			if sector_theme == null:
				result_positions[j] = pt_uv * global_radius + size * 0.5
				result_positions[sector_points_cur - 1 - j] = pt_uv_inner * global_radius + size * 0.5
				result_uv[sector_points_cur - 1 - j] = (pt_uv_inner + Vector2.ONE) * 0.5

			else:
				result_positions[j] = pt_uv * global_radius * sector_theme.radius_factor_outer + size * 0.5
				result_positions[sector_points_cur - 1 - j] = pt_uv_inner * global_radius * sector_theme.radius_factor_inner + size * 0.5
				result_uv[sector_points_cur - 1 - j] = (pt_uv_inner * sector_theme.radius_factor_inner / sector_theme.radius_factor_outer + Vector2.ONE) * 0.5

		if sector_theme != null:
			draw_colored_polygon(
				result_positions,
				sector_theme.color,
				result_uv,
				sector_theme.texture,
			)

		elif radial_theme != null:
			draw_colored_polygon(
				result_positions,
				radial_theme.color,
				result_uv,
				radial_theme.texture,
			)

		else:
			draw_colored_polygon(
				result_positions,
				Color.WHITE,
			)

		# if outline_width > 0.0:
		# 	_draw_outline()


func _draw_outline(
	i : int, outline_width : float, radius : float, inner_radius_f : float, result_outline_color : Color,
	result_uv : Array[Vector2], result_positions : Array[Vector2], sector_points_cur : int
):
	var outline_width_factor := outline_width / (radius * (1.0 - inner_radius_f))
	var result_positions_outline_o := PackedVector2Array()
	result_positions_outline_o.resize(sector_points_cur)
	for j in sector_points_cur / 2:
		var alt_j := sector_points_cur - 1 - j
		result_positions_outline_o[j] = result_positions[j]
		result_positions_outline_o[alt_j] = lerp(result_positions[alt_j], result_positions[j], 1.0 - outline_width_factor)

	draw_colored_polygon(
		result_positions_outline_o,
		result_outline_color,
		result_uv,
		null,
	)

	# if !outline_inner:
	# 	return

	var result_positions_outline_i := PackedVector2Array()
	result_positions_outline_i.resize(sector_points_cur)

	for j in sector_points_cur / 2:
		var alt_j := sector_points_cur - 1 - j
		result_positions_outline_i[j] = lerp(result_positions[alt_j], result_positions[j], outline_width_factor)
		result_positions_outline_i[alt_j] = result_positions[alt_j]

	draw_colored_polygon(
		result_positions_outline_i,
		result_outline_color,
		result_uv,
		null,
	)


func _on_radial_theme_changed():
	queue_redraw()
	queue_sort()
