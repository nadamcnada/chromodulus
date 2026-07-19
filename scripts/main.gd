extends Control
## App shell: left navigation sidebar + the game content area. Scoring
## System and How to Play open as a modal popup confined to the content
## area (never covering the sidebar) rather than replacing the game view.

var classic_view: GameView
var plus_view: GameView
var info_dialog: InfoDialog
var content_area: Control
var _nav_buttons: Dictionary = {}


func _ready() -> void:
	_build_ui()
	_show_view("classic")


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

	classic_view = GameView.new()
	classic_view.ruleset = "CLASSIC"
	classic_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_area.add_child(classic_view)

	plus_view = GameView.new()
	plus_view.ruleset = "PLUS"
	plus_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_area.add_child(plus_view)

	info_dialog = InfoDialog.new()
	content_area.add_child(info_dialog)


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
	_nav_buttons["classic"] = _add_nav_button(vbox, "Classic (Solo Play)", func(): _show_view("classic"))
	_nav_buttons["plus"] = _add_nav_button(vbox, "Plus (Solo Play)", func(): _show_view("plus"))
	for label in ["Duo Play (2-player)", "Club Play (4-player)", "Tournament Mode"]:
		var btn := _add_nav_button(vbox, label, func(): pass)
		btn.disabled = true
		btn.tooltip_text = "Coming soon"

	vbox.add_child(HSeparator.new())

	vbox.add_child(_section_label("INFO"))
	# These open a popup over whatever's currently on screen rather than
	# navigating to a new page, so they aren't part of the page-toggle group.
	_add_nav_button(vbox, "Scoring System", _on_scoring_pressed, false)
	_add_nav_button(vbox, "How to Play", _on_how_to_play_pressed, false)

	return panel


func _on_scoring_pressed() -> void:
	info_dialog.open_with(GameText.CLASSIC_SCORING_SYSTEM_BBCODE)


func _on_how_to_play_pressed() -> void:
	info_dialog.open_with(GameText.CLASSIC_HOW_TO_PLAY_BBCODE)


func _section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.57, 0.63))
	return lbl


func _add_nav_button(parent: Control, label: String, on_pressed: Callable, toggles: bool = true) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(0, 36)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.toggle_mode = toggles
	b.pressed.connect(on_pressed)
	parent.add_child(b)
	return b


func _show_view(which: String) -> void:
	classic_view.visible = which == "classic"
	plus_view.visible = which == "plus"
	for key in _nav_buttons.keys():
		var btn: Button = _nav_buttons[key]
		if not btn.disabled:
			btn.button_pressed = key == which
