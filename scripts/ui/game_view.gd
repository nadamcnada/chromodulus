class_name GameView
extends Control
## The playable Chromodulus board: 7x7 grid, hand row, and turn controls.

const GRID_SIZE := 7

var cells: Array = []  # flat array of 49 CellView, row-major
var square_views: Array = []
var selected_square_id: int = -1

var wildcard_dialog: WildcardDialog

var status_label: Label
var hint_label: Label
var hand_row: HBoxContainer
var grid_container: GridContainer
var next_draw_btn: Button
var undo_btn: Button
var end_game_btn: Button
var new_game_btn: Button
var invert_btn: Button
var score_label: RichTextLabel
var board_area: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	GameState.state_changed.connect(_on_state_changed)
	GameState.message.connect(_on_message)
	_refresh()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 18)
	root.add_child(status_label)

	hint_label = Label.new()
	hint_label.add_theme_color_override("font_color", Color(0.75, 0.2, 0.2))
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint_label)

	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 24)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(mid)

	board_area = Control.new()
	board_area.custom_minimum_size = Vector2(7 * 62 + 8, 7 * 62 + 8)
	mid.add_child(board_area)

	var board_panel := PanelContainer.new()
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color.WHITE
	panel_sb.border_color = Color.BLACK
	panel_sb.border_width_left = 2
	panel_sb.border_width_right = 2
	panel_sb.border_width_top = 2
	panel_sb.border_width_bottom = 2
	board_panel.add_theme_stylebox_override("panel", panel_sb)
	board_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	board_area.add_child(board_panel)

	grid_container = GridContainer.new()
	grid_container.columns = GRID_SIZE
	grid_container.add_theme_constant_override("h_separation", 0)
	grid_container.add_theme_constant_override("v_separation", 0)
	board_panel.add_child(grid_container)

	cells.clear()
	for r in range(GRID_SIZE):
		for c in range(GRID_SIZE):
			var cell := CellView.new()
			cell.setup(r, c)
			cell.pressed.connect(_on_cell_pressed.bind(r, c))
			grid_container.add_child(cell)
			cells.append(cell)

	var legend := _build_legend()
	mid.add_child(legend)

	var score_panel := _build_score_panel()
	mid.add_child(score_panel)

	var hand_panel := VBoxContainer.new()
	hand_panel.add_theme_constant_override("separation", 8)
	root.add_child(hand_panel)

	var hand_title := Label.new()
	hand_title.text = "Your Hand"
	hand_title.add_theme_font_size_override("font_size", 16)
	hand_panel.add_child(hand_title)

	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size = Vector2(0, 100)
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_panel.add_child(hand_scroll)

	hand_row = HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 8)
	hand_scroll.add_child(hand_row)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	root.add_child(controls)

	next_draw_btn = Button.new()
	next_draw_btn.text = "Next Draw"
	next_draw_btn.pressed.connect(_on_next_draw_pressed)
	controls.add_child(next_draw_btn)

	invert_btn = Button.new()
	invert_btn.text = "Cancel Invert"
	invert_btn.visible = false
	invert_btn.pressed.connect(func(): GameState.cancel_invert())
	controls.add_child(invert_btn)

	undo_btn = Button.new()
	undo_btn.text = "Undo"
	undo_btn.pressed.connect(func(): GameState.undo())
	controls.add_child(undo_btn)

	end_game_btn = Button.new()
	end_game_btn.text = "End Game"
	end_game_btn.pressed.connect(func(): GameState.end_game())
	controls.add_child(end_game_btn)

	new_game_btn = Button.new()
	new_game_btn.text = "New Game"
	new_game_btn.pressed.connect(_on_new_game_pressed)
	controls.add_child(new_game_btn)


func _build_score_panel() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(320, 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "Scoring Breakdown"
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	score_label = RichTextLabel.new()
	score_label.bbcode_enabled = true
	score_label.fit_content = true
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(score_label)

	return box


func _build_legend() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(190, 0)
	box.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "Color Key"
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)

	for code in ["R", "G", "B", "W", "Y", "P", "A"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(18, 18)
		swatch.color = ColorRules.rgb(code)
		row.add_child(swatch)
		var lbl := Label.new()
		lbl.text = ColorRules.color_name(code)
		row.add_child(lbl)
		box.add_child(row)

	return box


# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------

func _on_square_pressed(square_id: int) -> void:
	if GameState.pending_invert_id != -1:
		if square_id == GameState.pending_invert_id:
			GameState.cancel_invert()
		else:
			GameState.apply_invert_to(square_id)
		return

	var idx: int = GameState.find_hand_index(square_id)
	if idx == -1:
		return
	var sq: Dictionary = GameState.hand[idx]

	if sq["wtype"] == "INVERT":
		GameState.select_invert(square_id)
		return

	if not GameState.is_wildcard_configured(sq):
		selected_square_id = square_id
		wildcard_dialog.open_for(sq)
		return

	if selected_square_id == square_id:
		selected_square_id = -1
	else:
		selected_square_id = square_id
	_refresh()


func _on_cell_pressed(row: int, col: int) -> void:
	if selected_square_id == -1:
		return
	var result: Dictionary = GameState.play_square(selected_square_id, row, col)
	if result["ok"]:
		selected_square_id = -1


func _on_next_draw_pressed() -> void:
	selected_square_id = -1
	GameState.next_draw()


func _on_new_game_pressed() -> void:
	selected_square_id = -1
	GameState.new_game()


func _on_wildcard_cancelled() -> void:
	selected_square_id = -1
	_refresh()


func _on_message(text: String) -> void:
	hint_label.text = text


func _on_state_changed() -> void:
	_refresh()


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

func _refresh() -> void:
	_ensure_wildcard_dialog()
	var live_result: Dictionary = PatternEngine.score_grid(GameState.grid)
	_refresh_grid(live_result)
	_refresh_hand()
	_refresh_status(live_result)
	_refresh_controls()
	_refresh_score_panel(live_result)


func _ensure_wildcard_dialog() -> void:
	if wildcard_dialog != null:
		return
	wildcard_dialog = WildcardDialog.new()
	add_child(wildcard_dialog)
	wildcard_dialog.color_chosen.connect(func(id, color): GameState.configure_wildcard(id, color, 0))
	wildcard_dialog.number_chosen.connect(func(id, number): GameState.configure_wildcard(id, "", number))
	wildcard_dialog.chromodulus_chosen.connect(func(id, color, number): GameState.configure_wildcard(id, color, number))
	wildcard_dialog.cancelled.connect(_on_wildcard_cancelled)


func _refresh_grid(live_result: Dictionary) -> void:
	var pattern_set: Dictionary = {}
	for pc in live_result["pattern_cells"]:
		pattern_set["%d,%d" % [pc["row"], pc["col"]]] = true

	for r in range(GRID_SIZE):
		for c in range(GRID_SIZE):
			var cell: CellView = cells[r * GRID_SIZE + c]
			var data: Dictionary = GameState.grid[r][c]
			var in_pattern: bool = pattern_set.has("%d,%d" % [r, c])
			cell.set_data(data["color"], data["number"], in_pattern)
			cell.disabled = GameState.phase == "GAME_OVER"


func _refresh_hand() -> void:
	for child in hand_row.get_children():
		child.queue_free()
	square_views.clear()
	for sq in GameState.hand:
		var sv := SquareView.new()
		var is_selected: bool = sq["id"] == selected_square_id or sq["id"] == GameState.pending_invert_id
		sv.set_data(sq, is_selected)
		sv.pressed.connect(_on_square_pressed.bind(sq["id"]))
		sv.disabled = GameState.phase == "GAME_OVER"
		hand_row.add_child(sv)
		square_views.append(sv)


func _refresh_status(live_result: Dictionary) -> void:
	match GameState.phase:
		"DRAWING":
			status_label.text = "Draw %d of 4 — Played %d/7 — Current Score: %d. Press Next Draw when you're ready to move on." % [
				GameState.draw_number, GameState.played_this_draw, live_result["total"]
			]
		"FINAL_DRAW":
			status_label.text = "Final Draw — %d squares left to play — Current Score: %d. Press End Game when you're finished." % [
				GameState.hand.size(), live_result["total"]
			]
		"GAME_OVER":
			status_label.text = "Game Over — Final Score: %d" % GameState.last_result.get("total", 0)

	if GameState.pending_invert_id != -1:
		hint_label.text = "Invert Wildcard selected — click another square in your hand to apply it (subtract instead of add)."


func _refresh_controls() -> void:
	next_draw_btn.visible = GameState.phase == "DRAWING"
	undo_btn.disabled = not GameState.can_undo()
	end_game_btn.visible = GameState.phase == "FINAL_DRAW"
	invert_btn.visible = GameState.pending_invert_id != -1


func _refresh_score_panel(live_result: Dictionary) -> void:
	var is_final: bool = GameState.phase == "GAME_OVER"
	var result: Dictionary = GameState.last_result if is_final else live_result
	score_label.text = _format_result(result, is_final)


func _format_result(result: Dictionary, is_final: bool) -> String:
	var heading: String = "FINAL SCORE" if is_final else "Current Score"
	var s := "[b][font_size=22]%s: %d[/font_size][/b]\n\n" % [heading, result["total"]]
	var patterns: Array = result["patterns"]
	if patterns.is_empty():
		s += "No scoring patterns on the grid yet.\n"
	else:
		s += "[b]Patterns:[/b]\n"
		for p in patterns:
			s += "• %s — %s (%d cells) = %d pts\n" % [_describe_line(p), _type_name(p["type"]), p["length"], p["score"]]
	if result["nexus_total"] > 0:
		s += "\n[b]Nexus bonuses:[/b] +%d\n" % result["nexus_total"]
		for nc in result["nexus_cells"]:
			s += "• Cell (row %d, col %d) links %d patterns — +%d\n" % [nc["row"] + 1, nc["col"] + 1, nc["links"], nc["bonus"]]
	return s


func _describe_line(p: Dictionary) -> String:
	match p["orientation"]:
		"ROW":
			return "Row %d" % (p["line_index"] + 1)
		"COL":
			return "Column %d" % (p["line_index"] + 1)
		"DIAG":
			return "Diagonal (offset %d)" % p["line_index"]
		"ADIAG":
			return "Anti-diagonal (offset %d)" % p["line_index"]
		_:
			return "Line"


func _type_name(t: String) -> String:
	match t:
		"RUN": return "Run (same color)"
		"CLUSTER": return "Cluster (same color)"
		_: return t
