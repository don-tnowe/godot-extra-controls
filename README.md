# Naddy's Extra Controls

More control elements. Simple as.
A collection of control nodes usable in a variety of games and GUI applications.

## Containers:

- **Interpolated Box/Flow**: Containers that smoothly animate children when they enter or change order. Drag-and-drop reordering and drag-and-drop to move between containers in both variants. Vertical layout and compacting children to fit are features supported in the Box variant.
- **Radial Container**: script-based "Pie menu", supports texturing, tweening, different item sizes (*via size_flags_stretch_ratio*), and multiple position-to-index functions.
- **ScaleContainer**: When resized, scales children instead of resizing them. With the integer scale setting, can be used for pixel-perfect viewports.
- **Child Transform Container**: transform a Control's children while preserving minimum size.
- **Draggable**: node that can be dragged and resized with the mouse pointer, with grid snapping, parent-clipping, and a visible resize margin.
- **ScrollZoomView**: node that can have one child and allows to scroll and zoom using the mouse. Allows smooth zoom.
- **MaxSizeContainer**: Limits child size to a max size.
- **View Switcher**: Keeps only one child, and optionally a background, visible.

## Utility:

- **Remote Transform Rect**: transform a Control remotely similar to RemoteTransform2D/3D
- **Data Dropper**: passes drag-and-drop via signal
- **Flipped Split**: SplitContainer anchored to the other side for when the parent is resized

## Input:

- **Theme Icon Button**: I use it in my other plugins all the time! Grabs icon from theme by name.
- **Properties Box**: Form to input values like you'd use the inspector. Strings, bools, numbers (*sliders supported*) and enums. Allows foldable groups.
- **Unfolded Option Button**: list of options, pick one or use as bit flags

#

Made by Don Tnowe in 2023.

[My Website](https://redbladegames.netlify.app)

[Itch](https://don-tnowe.itch.io)

[Twitter](https://twitter.com/don_tnowe)

Copying and Modification is allowed in accordance to the MIT license, full text is included.
