extends Control
## App shell: left navigation sidebar + the game content area. Scoring
## System and How to Play open as a modal popup confined to the content
## area (never covering the sidebar) rather than replacing the game view.

var classic_view: GameView
var plus_view: GameView
var one_liner_view: GameView
var one_liner_plus_view: GameView
var puzzle_selector: Control
var puzzle_3_view: GameView
var puzzle_4_view: GameView
var puzzle_5_view: GameView
var info_dialog: InfoDialog
var content_area: Control
var _nav_buttons: Dictionary = {}
var _current_view: String = "classic"


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

	one_liner_view = GameView.new()
	one_liner_view.ruleset = "ONE_LINER"
	one_liner_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_area.add_child(one_liner_view)

	one_liner_plus_view = GameView.new()
	one_liner_plus_view.ruleset = "ONE_LINER_PLUS"
	one_liner_plus_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_area.add_child(one_liner_plus_view)

	puzzle_selector = _build_puzzle_selector()
	puzzle_selector.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_area.add_child(puzzle_selector)

	puzzle_3_view = _build_puzzle_view(3)
	content_area.add_child(puzzle_3_view)

	puzzle_4_view = _build_puzzle_view(4)
	content_area.add_child(puzzle_4_view)

	puzzle_5_view = _build_puzzle_view(5)
	content_area.add_child(puzzle_5_view)

	info_dialog = InfoDialog.new()
	content_area.add_child(info_dialog)


func _build_puzzle_view(size: int) -> GameView:
	var view := GameView.new()
	view.ruleset = "PUZZLE"
	view.puzzle_size = size
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	return view


## Shown when "Puzzle" is picked from the sidebar - one button per grid size,
## each switching to that size's own GameView instance.
func _build_puzzle_selector() -> Control:
	var root := Control.new()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	root.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Chromodulus Puzzle"
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choose a grid size to play."
	subtitle.add_theme_font_size_override("font_size", 16)
	vbox.add_child(subtitle)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	vbox.add_child(row)

	row.add_child(_puzzle_size_button("3 x 3", func(): _show_view("puzzle_3")))
	row.add_child(_puzzle_size_button("4 x 4", func(): _show_view("puzzle_4")))
	row.add_child(_puzzle_size_button("5 x 5", func(): _show_view("puzzle_5")))

	return root


func _puzzle_size_button(label: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(140, 70)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(on_pressed)
	return b


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
	_nav_buttons["one_liner"] = _add_nav_button(vbox, "One-Liner (Solo Play)", func(): _show_view("one_liner"))
	_nav_buttons["one_liner_plus"] = _add_nav_button(vbox, "One-Liner Plus (Solo Play)", func(): _show_view("one_liner_plus"))
	_nav_buttons["puzzle"] = _add_nav_button(vbox, "Puzzle (Solo Play)", func(): _show_view("puzzle"))
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
	match _current_view:
		"plus":
			info_dialog.open_with(GameText.PLUS_SCORING_SYSTEM_BBCODE)
		"one_liner":
			info_dialog.open_with(GameText.ONE_LINER_SCORING_SYSTEM_BBCODE)
		"one_liner_plus":
			info_dialog.open_with(GameText.ONE_LINER_PLUS_SCORING_SYSTEM_BBCODE)
		_:
			info_dialog.open_with(GameText.CLASSIC_SCORING_SYSTEM_BBCODE)


func _on_how_to_play_pressed() -> void:
	match _current_view:
		"plus":
			info_dialog.open_with(GameText.PLUS_HOW_TO_PLAY_BBCODE)
		"one_liner":
			info_dialog.open_with(GameText.ONE_LINER_HOW_TO_PLAY_BBCODE)
		"one_liner_plus":
			info_dialog.open_with(GameText.ONE_LINER_PLUS_HOW_TO_PLAY_BBCODE)
		_:
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
	_current_view = which
	classic_view.visible = which == "classic"
	plus_view.visible = which == "plus"
	one_liner_view.visible = which == "one_liner"
	one_liner_plus_view.visible = which == "one_liner_plus"
	puzzle_selector.visible = which == "puzzle"
	puzzle_3_view.visible = which == "puzzle_3"
	puzzle_4_view.visible = which == "puzzle_4"
	puzzle_5_view.visible = which == "puzzle_5"
	for key in _nav_buttons.keys():
		var btn: Button = _nav_buttons[key]
		if not btn.disabled:
			# The sidebar has a single "Puzzle" entry covering the size
			# picker and all three sizes, so it highlights for any of them.
			btn.button_pressed = which.begins_with("puzzle") if key == "puzzle" else key == which
