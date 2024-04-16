@tool
class_name RadialContainer
extends Container

## Radial menu container. Radius is based on own size. Supports texturing and [Control.size_flags_stretch_ratio].

## Behaviour when a node goes beyond the size of a specified array
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

@export_group("Dimensions")
@export var radius_factor_outer := 1.0:
	set(v):
		if v < 0.0: v = 0.0
		radius_factor_outer = v
		queue_sort()
@export var item_radius_inner := 0.0:
	set(v):
		if v < 0.0: v = 0.0
		item_radius_inner = v
		queue_sort()
@export var item_radius_factor := 0.5:
	set(v):
		if v < 0.0: v = 0.0
		item_radius_factor = v
		queue_sort()
@export var item_radius_factor_per : Array[float] = [1.0]:
	set(v):
		item_radius_factor_per = v
		queue_sort()
@export var item_radius_factor_per_behaviour := OutOfBoundsBehaviour.CLAMP:
	set(v):
		item_radius_factor_per_behaviour = v
		queue_sort()

@export var border_width := 4.0:
	set(v):
		if v < 0.0: v = 0.0
		border_width = v
		queue_redraw()
@export var sector_points := 60:
	set(v):
		if v < 2: v = 2
		sector_points = v
		queue_redraw()
@export var sector_radius_inner := 0.0:
	set(v):
		if v < 0.0: v = 0.0
		sector_radius_inner = v
		queue_redraw()
@export_range(0.0, 1.0) var sector_radius_inner_factor := 0.0:
	set(v):
		sector_radius_inner_factor = v
		queue_redraw()
@export var outline_width := 0.0:
	set(v):
		if v < 0.0: v = 0.0
		outline_width = v
		queue_redraw()

@export_group("Style")
@export var colors : Array[Color] = [Color.WHITE]:
	set(v):
		colors = v
		queue_redraw()
@export var colors_behaviour := OutOfBoundsBehaviour.CLAMP:
	set(v):
		colors_behaviour = v
		queue_redraw()
@export var outline_colors : Array[Color] = [Color.WHITE]:
	set(v):
		outline_colors = v
		queue_redraw()
@export var outline_colors_behaviour := OutOfBoundsBehaviour.CLAMP:
	set(v):
		outline_colors_behaviour = v
		queue_redraw()
@export var textures : Array[Texture2D] = []:
	set(v):
		textures = v
		queue_redraw()
@export var textures_behaviour := OutOfBoundsBehaviour.CLAMP:
	set(v):
		textures_behaviour = v
		queue_redraw()

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

## Retrieves the item index from a direction.
func get_index_from_direction(direction : Vector2):
	var angle_progress := fposmod(direction.angle() / TAU - progress_offset + 0.5, 1.0)
	for i in _child_stretch_sum_until.size() - 1:
		if _child_stretch_sum_until[i + 1] > angle_progress:
			return i

	return 0

## Returns the radius of the empty space inside the wheel.
func get_inner_radius():
	var outer_radius := minf(size.x, size.y) * 0.5 * radius_factor_outer
	return clampf(sector_radius_inner_factor * outer_radius + sector_radius_inner, 2.0 * border_width, outer_radius)


static func get_index_with_oob(index : int, max_index : int, oob : OutOfBoundsBehaviour):
	if max_index <= 1:
		return 0

	match oob:
		OutOfBoundsBehaviour.CLAMP:
			return mini(index, max_index - 1)
		OutOfBoundsBehaviour.REPEAT:
			return index % max_index
		OutOfBoundsBehaviour.PINGPONG:
			var iter := (index) / (max_index - 1)
			if iter % 2 == 0:
				return index % (max_index - 1)
			else:
				return (max_index - 1) - index % (max_index - 1)


func _has_point(point : Vector2):
	var radius := minf(size.x, size.y) * 0.5 * radius_factor_outer
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
				sort_child(x, child_index, child_stretch_ratio_sum_current, child_stretch_ratio_sum_next)
				child_stretch_ratio_sum_current = child_stretch_ratio_sum_next
				child_index += 1

		queue_redraw()


func sort_child(child : Control, child_index : int, progress_min : float, progress_max : float):
	var radius := minf(size.x, size.y) * 0.5 * radius_factor_outer
	radius = lerp(item_radius_inner, radius, item_radius_factor)
	if item_radius_factor_per.size() != 0:
		radius *= item_radius_factor_per[get_index_with_oob(child_index, item_radius_factor_per.size(), item_radius_factor_per_behaviour)]

	child.size = child.get_combined_minimum_size()
	child.position = size * 0.5 + Vector2(radius, 0).rotated(TAU * (progress_min + progress_max + progress_offset + progress_offset) * 0.5) - child.size * 0.5


func _draw():
	var radius := minf(size.x, size.y) * 0.5 * radius_factor_outer
	var inner_radius_f := clampf(sector_radius_inner_factor + sector_radius_inner / radius, 2.0 * border_width / radius, 0.999 * radius_factor_outer)
	var border_rad := asin(0.5 * border_width / radius) * 0.5
	var border_rad_inner := asin(0.5 * border_width / (radius * inner_radius_f)) * 0.5
	if is_nan(border_rad_inner): border_rad_inner = 0.0
	for i in _child_stretch_sum_until.size() - 1:
		var start_rad := (progress_offset + _child_stretch_sum_until[i]) * TAU + border_rad
		var end_rad := (progress_offset + _child_stretch_sum_until[i + 1]) * TAU - border_rad
		if end_rad <= start_rad: continue

		var start_rad_inner := (progress_offset + _child_stretch_sum_until[i]) * TAU + border_rad_inner
		var end_rad_inner := (progress_offset + _child_stretch_sum_until[i + 1]) * TAU - border_rad_inner
		if end_rad_inner <= start_rad_inner: continue

		var sector_points_cur := (maxi((end_rad - start_rad) / TAU * sector_points, 2)) * 2
		var sector_points_step := 2.0 / (sector_points_cur - 2)

		var result_color := Color.WHITE
		if colors.size() != 0:
			result_color = colors[get_index_with_oob(i, colors.size(), colors_behaviour)]

		var result_tex : Texture2D = null
		if textures.size() != 0:
			result_tex = textures[get_index_with_oob(i, textures.size(), textures_behaviour)]

		var result_positions := PackedVector2Array()
		var result_uv := PackedVector2Array()
		result_positions.resize(sector_points_cur)
		result_uv.resize(sector_points_cur)

		for j in sector_points_cur / 2:
			var pt_angle := lerp(start_rad, end_rad, sector_points_step * j)
			var pt_angle_inner := lerp(start_rad_inner, end_rad_inner, sector_points_step * j)
			var pt_uv := Vector2(cos(pt_angle), sin(pt_angle))
			var pt_uv_inner := Vector2(cos(pt_angle_inner), sin(pt_angle_inner)) * inner_radius_f
			result_uv[j] = (pt_uv + Vector2.ONE) * 0.5
			result_uv[sector_points_cur - 1 - j] = (pt_uv_inner + Vector2.ONE) * 0.5
			result_positions[j] = (pt_uv * radius + size * 0.5)
			result_positions[sector_points_cur - 1 - j] = pt_uv_inner * radius + size * 0.5

		draw_colored_polygon(
			result_positions,
			result_color,
			result_uv,
			result_tex,
		)
		if outline_width > 0.0:
			var result_outline_color := Color.WHITE
			if outline_colors.size() != 0:
				result_outline_color = outline_colors[get_index_with_oob(i, outline_colors.size(), outline_colors_behaviour)]
	
			var result_positions_outline1 := PackedVector2Array()
			var result_positions_outline2 := PackedVector2Array()
			result_positions_outline1.resize(sector_points_cur)
			result_positions_outline2.resize(sector_points_cur)
			var outline_width_factor := outline_width / (radius * (1.0 - inner_radius_f))
			for j in sector_points_cur / 2:
				var alt_j := sector_points_cur - 1 - j
				result_positions_outline1[j] = lerp(result_positions[alt_j], result_positions[j], outline_width_factor)
				result_positions_outline1[alt_j] = result_positions[alt_j]

			for j in sector_points_cur / 2:
				var alt_j := sector_points_cur - 1 - j
				result_positions_outline2[j] = result_positions[j]
				result_positions_outline2[alt_j] = lerp(result_positions[alt_j], result_positions[j], 1.0 - outline_width_factor)

			draw_colored_polygon(
				result_positions_outline1,
				result_outline_color,
				result_uv,
				null,
			)
			draw_colored_polygon(
				result_positions_outline2,
				result_outline_color,
				result_uv,
				null,
			)
