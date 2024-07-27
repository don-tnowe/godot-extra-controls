@tool
class_name RadialContainerTheme
extends Resource

@export_group("Dimensions")
## Radius of the outer circle, relative to the node's rect size. Use [code]1[/code] to extend to the rect's full bounds.
@export var radius_factor_outer := 1.0:
	set(v):
		if v < 0.0: v = 0.0
		radius_factor_outer = v
		emit_changed()
## Radius of the outer circle, relative to the node's rect size. Use [code]1[/code] to extend to the rect's full bounds.
@export var radius_factor_inner := 0.1:
	set(v):
		if v < 0.0: v = 0.0
		radius_factor_inner = v
		emit_changed()
## Radius of the ring containing the items, relative to inner and outer radii. Use [code]0[/code] to draw items on the inner circle, [code]1[/code] for outer circle.
@export var item_radius_factor := 0.5:
	set(v):
		if v < 0.0: v = 0.0
		item_radius_factor = v
		emit_changed()
## Scale of the child node in the middle of the sector.
@export var item_scale := Vector2.ONE:
	set(v):
		item_scale = v
		emit_changed()

@export_group("Style")
## Color of the rendered sector. if [member texture] is set, modulates the texture by this color.
@export var color := Color.WHITE:
	set(v):
		color = v
		emit_changed()
## Texture of the rendered sector. if [member color] is set, modulates this texture by the color.
@export var texture : Texture2D:
	set(v):
		texture = v
		emit_changed()

## Set properties of this theme to values interpolated between two themes by a 0-1 progress factor. [br]
## [b]Note:[/b] this operates on the object and does not return a copy of it.
func lerp_theme(from : RadialContainerTheme, to : RadialContainerTheme, factor : float) -> RadialContainerTheme:
	radius_factor_outer = lerpf(from.radius_factor_outer, to.radius_factor_outer, factor)
	radius_factor_inner = lerpf(from.radius_factor_inner, to.radius_factor_inner, factor)
	item_radius_factor = lerpf(from.item_radius_factor, to.item_radius_factor, factor)
	item_scale = from.item_scale.lerp(to.item_scale, factor)
	color = from.color + (to.color - from.color) * factor
	texture = to.texture
	return self

## Set properties of this theme to a combination two other themes, either can be null. Radii will be multiplied, others will be overriden by the [code]sub[/code] theme, if it's not null. [br]
## [b]Note:[/b] this operates on the object and does not return a copy of it.
func merge(base : RadialContainerTheme, sub : RadialContainerTheme) -> RadialContainerTheme:
	var n_radius_factor_outer = 1.0
	var n_radius_factor_inner = 1.0
	var n_item_radius_factor = 0.5
	var n_item_scale = Vector2.ONE
	var n_color = Color.WHITE
	var n_texture = null

	if base != null:
		n_radius_factor_outer *= base.radius_factor_outer
		n_radius_factor_inner *= base.radius_factor_inner
		n_item_radius_factor = base.item_radius_factor
		n_item_scale *= base.item_scale
		n_color = base.color
		n_texture = base.texture

	if sub != null:
		n_radius_factor_outer *= sub.radius_factor_outer
		n_radius_factor_inner *= sub.radius_factor_inner
		n_item_radius_factor = sub.item_radius_factor
		n_item_scale *= sub.item_scale
		if sub.color.a != 0.0: n_color = sub.color
		if sub.texture != null: n_texture = sub.texture

	if base == null && sub == null:
		radius_factor_inner = 0.0

	radius_factor_outer = n_radius_factor_outer
	radius_factor_inner = n_radius_factor_inner
	item_radius_factor = n_item_radius_factor
	item_scale = n_item_scale
	color = n_color
	texture = n_texture
	return self
