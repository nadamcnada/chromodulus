class_name CellView
extends Button
## A single 7x7 grid cell: a colored square with a centered number.

var row: int = -1
var col: int = -1


func _ready() -> void:
	custom_minimum_size = Vector2(60, 60)
	focus_mode = Control.FOCUS_NONE
	add_theme_font_size_override("font_size", 22)


func setup(r: int, c: int) -> void:
	row = r
	col = c


## [param in_pattern] outlines the cell in orange when it's currently part of
## a scored pattern on the grid.
func set_data(color: String, number: int, in_pattern: bool = false) -> void:
	text = str(number)
	var sb := StyleBoxFlat.new()
	sb.bg_color = ColorRules.rgb(color)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color.BLACK
	if in_pattern:
		sb.border_width_left = 3
		sb.border_width_right = 3
		sb.border_width_top = 3
		sb.border_width_bottom = 3
		sb.border_color = ColorRules.HIGHLIGHT_ORANGE

	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, sb)

	var fc: Color = ColorRules.text_color(color)
	for cstate in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		add_theme_color_override(cstate, fc)
