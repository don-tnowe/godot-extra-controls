@tool
extends EditorPlugin

const elements_dir := "res://addons/tnowe_extra_controls/elements/"

var element_scripts := [
	["DataDropper", preload(elements_dir + "data_dropper.gd"), null],
	["FlippedHSplitContainer", preload(elements_dir + "flipped_h_split_container.gd"), null],
	["FlippedVSplitContainer", preload(elements_dir + "flipped_v_split_container.gd"), null],
	["UnfoldedOptionButton", preload(elements_dir + "unfolded_option_button.gd"), null],
	["PropertiesBox", preload(elements_dir + "properties_box.gd"), null],
# Currently broken  # ["TextInitMenuButton", preload(elements_dir + "text_init_menu_button.gd"), null],
# See above, this is a similar class  # ["TextInitPopupMenu", preload(elements_dir + "text_init_popup_menu.gd"), null],
	["ThemeIconButton", preload(elements_dir + "theme_icon_button.gd"), null],
	["ViewSwitcher", preload(elements_dir + "view_switcher.gd"), null],
	["ScaleContainer", preload(elements_dir + "scale_container.gd"), null],
	["ChildTransformContainer", preload(elements_dir + "child_transform_container.gd"), null],
	["ChildSimpleTransformContainer", preload(elements_dir + "child_simple_transform_container.gd"), null],
	["RemoteTransformRect", preload(elements_dir + "remote_transform_rect.gd"), null],
	["RadialContainer", preload(elements_dir + "radial_container.gd"), null],
	["RadialContainerTheme", preload(elements_dir + "radial_container_theme.gd"), null],
	["InterpolatedFlowContainer", preload(elements_dir + "interpolated_container/interpolated_flow_container.gd"), null],
	["InterpolatedBoxContainer", preload(elements_dir + "interpolated_container/interpolated_box_container.gd"), null],
	["InterpolatedFreeContainer", preload(elements_dir + "interpolated_container/interpolated_free_container.gd"), null],
	["ContainerQuantityKeeper", preload(elements_dir + "interpolated_container/container_quantity_keeper.gd"), null],
	["Draggable", preload(elements_dir + "draggable.gd"), null],
	["ConnectionLine", preload(elements_dir + "connection_line.gd"), null],
	["MultiSelection", preload(elements_dir + "multi_selection.gd"), null],
]


func _enter_tree():
	var editor_base_node := get_editor_interface().get_base_control()
	for x in element_scripts:
		var x_icon = x[2]
		if x_icon == null:
			x_icon = x[1].get_instance_base_type()

		if x_icon is StringName || x_icon is String:
			x_icon = editor_base_node.get_theme_icon(x_icon, "EditorIcons")

		add_custom_type(x[0], x[1].get_instance_base_type(), x[1], x_icon)


func _exit_tree():
	for x in element_scripts:
		remove_custom_type(x[0])
