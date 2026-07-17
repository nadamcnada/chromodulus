extends Control
## App shell: left navigation sidebar + a swappable content area holding the
## Game, Scoring System, and How to Play views.

var game_view: GameView
var scoring_view: InfoView
var howto_view: InfoView
var content_area: Control
var _nav_buttons: Dictionary = {}


func _ready() -> void:
	_build_ui()
	_show_view("game")


func _build_ui() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	root.add_child(_build_sidebar())

	content_area = Control.new()
	content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content_area)

	game_view = GameView.new()
	game_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_area.add_child(game_view)

	scoring_view = InfoView.new()
	scoring_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_area.add_child(scoring_view)
	scoring_view.set_content(GameText.SCORING_SYSTEM_BBCODE)

	howto_view = InfoView.new()
	howto_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_area.add_child(howto_view)
	howto_view.set_content(GameText.HOW_TO_PLAY_BBCODE)


func _build_sidebar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.12, 0.15)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Chromodulus"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "chromo-numerical strategy"
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	vbox.add_child(_section_label("GAME VERSIONS"))
	_nav_buttons["game"] = _add_nav_button(vbox, "Classic (Solo Play)", func(): _show_view("game"))
	for label in ["Duo Play (2-player)", "Club Play (4-player)", "Tournament Mode"]:
		var btn := _add_nav_button(vbox, label, func(): pass)
		btn.disabled = true
		btn.tooltip_text = "Coming soon"

	vbox.add_child(HSeparator.new())

	vbox.add_child(_section_label("INFO"))
	_nav_buttons["scoring"] = _add_nav_button(vbox, "Scoring System", func(): _show_view("scoring"))
	_nav_buttons["howto"] = _add_nav_button(vbox, "How to Play", func(): _show_view("howto"))

	return panel


func _section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.57, 0.63))
	return lbl


func _add_nav_button(parent: Control, label: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(0, 36)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.toggle_mode = true
	b.pressed.connect(on_pressed)
	parent.add_child(b)
	return b


func _show_view(which: String) -> void:
	game_view.visible = which == "game"
	scoring_view.visible = which == "scoring"
	howto_view.visible = which == "howto"
	for key in _nav_buttons.keys():
		var btn: Button = _nav_buttons[key]
		if not btn.disabled:
			btn.button_pressed = key == which
