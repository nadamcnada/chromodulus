class_name SquareView
extends Button
## A hand square drawn from the stock deck (or a wildcard, configured or not).

var square_id: int = -1
var data: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(66, 86)
	focus_mode = Control.FOCUS_NONE
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_theme_font_size_override("font_size", 18)


## [param selected] outlines the square in orange when it's the currently
## selected square in hand.
func set_data(sq: Dictionary, selected: bool = false) -> void:
	data = sq
	square_id = sq["id"]
	_apply_style(selected)
	text = _label_for(sq)
	tooltip_text = _tooltip_for(sq)


func _apply_style(selected: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	if data.get("color", "") != "":
		sb.bg_color = ColorRules.rgb(data["color"])
	else:
		sb.bg_color = Color(0.82, 0.82, 0.85)

	if selected:
		sb.border_width_left = 4
		sb.border_width_right = 4
		sb.border_width_top = 4
		sb.border_width_bottom = 4
		sb.border_color = ColorRules.HIGHLIGHT_ORANGE
	else:
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.border_color = Color.BLACK

	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, sb)

	var fc: Color = ColorRules.text_color(data["color"]) if data.get("color", "") != "" else Color.BLACK
	for cstate in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		add_theme_color_override(cstate, fc)


func _label_for(sq: Dictionary) -> String:
	var lines: Array[String] = []
	match sq["wtype"]:
		"COLOR":
			lines.append("Color?")
		"NUMBER":
			lines.append("Number?")
		"CHROMODULUS":
			lines.append("Chromodulus")
		"INVERT":
			lines.append("Invert")
	if sq["number"] >= 0:
		lines.append(str(sq["number"]))
	if sq.get("inverted", false):
		lines.append("(invert)")
	var out: String = ""
	for i in range(lines.size()):
		if i > 0:
			out += "\n"
		out += lines[i]
	return out


func _tooltip_for(sq: Dictionary) -> String:
	match sq["wtype"]:
		"COLOR":
			return "Color Wildcard - preset number %d, choose the color when played." % sq["number"]
		"NUMBER":
			return "Number Wildcard - preset color %s, choose the number when played." % ColorRules.color_name(sq["color"])
		"CHROMODULUS":
			return "Chromodulus Wildcard - choose both color and number when played."
		"INVERT":
			return "Invert Wildcard - apply to another square in your hand to subtract instead of add."
		_:
			return "%s %d" % [ColorRules.color_name(sq["color"]), sq["number"]]


func set_selected(on: bool) -> void:
	_apply_style(on)
