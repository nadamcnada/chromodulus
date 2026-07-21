class_name GameView
extends Control
## The playable Chromodulus board (7x7 grid, or a single 10-cell row for the
## One-Liner rulesets), hand row, and turn controls. Each GameView owns its
## own GameState instance - Classic, Plus, One-Liner and One-Liner Plus are
## separate, independent games, not shared sessions.

## Set this before adding the view to the tree
## ("CLASSIC", "PLUS", "ONE_LINER" or "ONE_LINER_PLUS").
var ruleset: String = "CLASSIC"
var game_state: GameState

## Board dimensions, derived from game_state (which derives them from
## ruleset) once _ready() constructs it.
var grid_rows: int = 7
var grid_cols: int = 7

var cells: Array = []  # flat array of grid_rows * grid_cols CellView, row-major
var square_views: Array = []
var selected_square_id: int = -1

var wildcard_dialog: WildcardDialog
var confirm_dialog: ConfirmDialog
var _confirm_action: Callable

var status_label: Label
var hint_label: Label
var hand_title: Label
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
	game_state = GameState.new(ruleset)
	grid_rows = game_state.grid_rows
	grid_cols = game_state.grid_cols
	_build_ui()
	game_state.state_changed.connect(_on_state_changed)
	game_state.message.connect(_on_message)
	_refresh()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root_hbox := HBoxContainer.new()
	root_hbox.add_theme_constant_override("separation", 24)
	margin.add_child(root_hbox)

	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 12)
	root_hbox.add_child(left_col)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 18)
	left_col.add_child(status_label)

	hint_label = Label.new()
	hint_label.add_theme_color_override("font_color", Color(0.75, 0.2, 0.2))
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_col.add_child(hint_label)

	if ruleset == "PLUS":
		var plus_banner := Label.new()
		plus_banner.text = "Plus Version: Alternating Number & Color Patterns allowed"
		plus_banner.add_theme_font_size_override("font_size", 16)
		left_col.add_child(plus_banner)

	board_area = Control.new()
	board_area.custom_minimum_size = Vector2(grid_cols * 62 + 8, grid_rows * 62 + 8)
	left_col.add_child(board_area)

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
	grid_container.columns = grid_cols
	grid_container.add_theme_constant_override("h_separation", 0)
	grid_container.add_theme_constant_override("v_separation", 0)
	board_panel.add_child(grid_container)

	cells.clear()
	for r in range(grid_rows):
		for c in range(grid_cols):
			var cell := CellView.new()
			cell.setup(r, c)
			cell.pressed.connect(_on_cell_pressed.bind(r, c))
			grid_container.add_child(cell)
			cells.append(cell)

	var hand_panel := VBoxContainer.new()
	hand_panel.add_theme_constant_override("separation", 8)
	left_col.add_child(hand_panel)

	hand_title = Label.new()
	hand_title.add_theme_font_size_override("font_size", 16)
	hand_panel.add_child(hand_title)

	var hand_scroll := ScrollContainer.new()
	# Wide enough for a full 10-square hand, so the hand's own width (not
	# just the board's) drives how far right the reference panel starts.
	hand_scroll.custom_minimum_size = Vector2(740, 100)
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_panel.add_child(hand_scroll)

	hand_row = HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 8)
	hand_scroll.add_child(hand_row)

	var score_panel := _build_score_panel()
	left_col.add_child(score_panel)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	left_col.add_child(controls)

	next_draw_btn = Button.new()
	next_draw_btn.text = "Next Draw"
	next_draw_btn.pressed.connect(_on_next_draw_pressed)
	controls.add_child(next_draw_btn)

	invert_btn = Button.new()
	invert_btn.text = "Cancel Invert"
	invert_btn.visible = false
	invert_btn.pressed.connect(func(): game_state.cancel_invert())
	controls.add_child(invert_btn)

	undo_btn = Button.new()
	undo_btn.text = "Undo"
	undo_btn.pressed.connect(func(): game_state.undo())
	controls.add_child(undo_btn)

	end_game_btn = Button.new()
	end_game_btn.text = "End Game"
	end_game_btn.pressed.connect(_on_end_game_pressed)
	controls.add_child(end_game_btn)

	new_game_btn = Button.new()
	new_game_btn.text = "New Game"
	new_game_btn.pressed.connect(_on_new_game_pressed)
	controls.add_child(new_game_btn)

	var reference_panel := _build_reference_panel()
	root_hbox.add_child(reference_panel)


func _build_score_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "Scoring Breakdown"
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 180)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	score_label = RichTextLabel.new()
	score_label.bbcode_enabled = true
	score_label.fit_content = true
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(score_label)

	return box


# ---------------------------------------------------------------------------
# Reference panel (color transformations + scoring pattern examples)
# ---------------------------------------------------------------------------

func _build_reference_panel() -> Control:
	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.custom_minimum_size = Vector2(380, 0)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	content.add_child(_rich_title("Color Transformations"))
	var transforms: Array = [
		[["R"], ["G"], ["Y"]],
		[["R"], ["B"], ["P"]],
		[["G"], ["B"], ["A"]],
		[["Y"], ["B"], ["W"]],
		[["P"], ["G"], ["W"]],
		[["A"], ["R"], ["W"]],
		[["W"], ["R", "G", "B"], ["R", "G", "B"]],
	]
	for spec in transforms:
		content.add_child(_transform_row(spec[0], spec[1], spec[2]))

	content.add_child(HSeparator.new())
	content.add_child(_rich_title("Number Transformations"))
	content.add_child(_bullet("Numbers add together"))
	content.add_child(_bullet("Modular Arithmetic keeps numbers single digit (e.g. 8 + 5 = 3)"))

	content.add_child(HSeparator.new())
	content.add_child(_rich_title("Scoring Patterns"))
	if not ruleset in ["ONE_LINER", "ONE_LINER_PLUS"]:
		content.add_child(_bullet("Row, Column or Diagonal"))
	content.add_child(_bullet("4+ squares in length"))

	content.add_child(_rich_subtitle("Run — Same Color"))
	content.add_child(_example_row([
		{"color": "R", "number": 1}, {"color": "R", "number": 2},
		{"color": "R", "number": 3}, {"color": "R", "number": 4},
	]))
	content.add_child(_bullet("Numbers in sequential order"))
	content.add_child(_bullet("Forward or backward (e.g. 4321)"))
	content.add_child(_bullet("\"0\" can be high or low (e.g. 0123 or 7890)"))

	content.add_child(_rich_subtitle("Cluster — Same Number and Color"))
	content.add_child(_example_row([
		{"color": "G", "number": 5}, {"color": "G", "number": 5},
		{"color": "G", "number": 5}, {"color": "G", "number": 5},
	]))

	if ruleset in ["PLUS", "ONE_LINER_PLUS"]:
		content.add_child(_rich_subtitle("Run — Alternating Color"))
		content.add_child(_example_row([
			{"color": "B", "number": 1}, {"color": "W", "number": 2},
			{"color": "B", "number": 3}, {"color": "W", "number": 4},
		]))

		content.add_child(_rich_subtitle("Cluster — Alternating Color"))
		content.add_child(_example_row([
			{"color": "P", "number": 6}, {"color": "A", "number": 6},
			{"color": "P", "number": 6}, {"color": "A", "number": 6},
		]))

		content.add_child(_rich_subtitle("Alternating Run — Alternating Color"))
		content.add_child(_example_row([
			{"color": "G", "number": 1}, {"color": "Y", "number": 2},
			{"color": "G", "number": 1}, {"color": "Y", "number": 2},
		]))

		content.add_child(_rich_subtitle("Alternating Run — Same Color"))
		content.add_child(_example_row([
			{"color": "R", "number": 1}, {"color": "R", "number": 2},
			{"color": "R", "number": 1}, {"color": "R", "number": 2},
		]))

	content.add_child(_rich_subtitle("Nexus Cells"))
	content.add_child(_bullet("Added points for squares that are part of 2+ patterns"))
	match ruleset:
		"ONE_LINER":
			content.add_child(_build_one_row_nexus_example(
				["Y", "Y", "Y", "Y", "Y", "Y", "Y", "Y", "Y", "Y"],
				[6, 6, 6, 6, 5, 4, 3, 2, 1, 0],
				[3],
			))
		"ONE_LINER_PLUS":
			content.add_child(_build_one_row_nexus_example(
				["R", "Y", "R", "Y", "R", "Y", "R", "Y", "R", "Y"],
				[1, 2, 1, 2, 3, 4, 3, 4, 5, 6],
				[2, 3, 4, 5, 6, 7],
			))
		_:
			content.add_child(_build_nexus_example())

	return outer


func _rich_title(t: String) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.text = "[font_size=17][b]%s[/b][/font_size]" % t
	return l


func _rich_subtitle(t: String) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.text = "[font_size=14][b]%s[/b][/font_size]" % t
	return l


func _bullet(t: String) -> Label:
	var l := Label.new()
	l.text = "• %s" % t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _swatch(code: String) -> ColorRect:
	var r := ColorRect.new()
	r.custom_minimum_size = Vector2(18, 18)
	r.color = ColorRules.rgb(code)
	return r


func _swatch_group(codes: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	for i in range(codes.size()):
		if i > 0:
			var slash := Label.new()
			slash.text = "/"
			row.add_child(slash)
		row.add_child(_swatch(codes[i]))
	return row


func _transform_row(existing: Array, added: Array, result: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_swatch_group(existing))
	row.add_child(_op_label("+"))
	row.add_child(_swatch_group(added))
	row.add_child(_op_label("="))
	row.add_child(_swatch_group(result))
	return row


func _op_label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


## A row of small, non-interactive CellView tiles used to illustrate a pattern.
func _example_row(entries: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for e in entries:
		var cell := CellView.new()
		row.add_child(cell)
		cell.custom_minimum_size = Vector2(42, 42)
		cell.set_data(e["color"], e["number"])
		cell.disabled = true
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row


## A 4x4 mockup: a row and an intersecting column of Yellow 5/6/7/8, with the
## shared cell (6) outlined in orange as the Nexus.
func _build_nexus_example() -> Control:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)

	var sequence: Array = [5, 6, 7, 8]
	for r in range(4):
		for c in range(4):
			var cell := CellView.new()
			grid.add_child(cell)
			cell.custom_minimum_size = Vector2(36, 36)
			cell.disabled = true
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var in_row: bool = r == 1
			var in_col: bool = c == 1
			if in_row and in_col:
				cell.set_data("Y", sequence[1], true)
			elif in_row:
				cell.set_data("Y", sequence[c])
			elif in_col:
				cell.set_data("Y", sequence[r])
			else:
				cell.set_data("W", 0)
				cell.text = ""
	return grid


## A single 10-cell row illustrating two overlapping One-Liner patterns;
## cells at [param nexus_indices] are outlined orange as the shared Nexus
## cell(s).
func _build_one_row_nexus_example(colors: Array, numbers: Array, nexus_indices: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	for i in range(colors.size()):
		var cell := CellView.new()
		row.add_child(cell)
		cell.custom_minimum_size = Vector2(34, 34)
		cell.disabled = true
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.set_data(colors[i], numbers[i], nexus_indices.has(i))
	return row


# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------

func _on_square_pressed(square_id: int) -> void:
	if game_state.pending_invert_id != -1:
		if square_id == game_state.pending_invert_id:
			game_state.cancel_invert()
		else:
			game_state.apply_invert_to(square_id)
		return

	var idx: int = game_state.find_hand_index(square_id)
	if idx == -1:
		return
	var sq: Dictionary = game_state.hand[idx]

	if sq["wtype"] == "INVERT":
		game_state.select_invert(square_id)
		return

	if not game_state.is_wildcard_configured(sq):
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
	var result: Dictionary = game_state.play_square(selected_square_id, row, col)
	if result["ok"]:
		selected_square_id = -1


func _on_next_draw_pressed() -> void:
	selected_square_id = -1
	game_state.next_draw()


func _on_new_game_pressed() -> void:
	_open_confirm("Start a new game?", _confirm_new_game)


func _confirm_new_game() -> void:
	selected_square_id = -1
	game_state.new_game()


func _on_end_game_pressed() -> void:
	_open_confirm("End the game?", game_state.end_game)


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
	var live_result: Dictionary = PatternEngine.score_grid(game_state.grid, ruleset)
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
	wildcard_dialog.color_chosen.connect(func(id, color): game_state.configure_wildcard(id, color, 0))
	wildcard_dialog.number_chosen.connect(func(id, number): game_state.configure_wildcard(id, "", number))
	wildcard_dialog.chromodulus_chosen.connect(func(id, color, number): game_state.configure_wildcard(id, color, number))
	wildcard_dialog.cancelled.connect(_on_wildcard_cancelled)


func _ensure_confirm_dialog() -> void:
	if confirm_dialog != null:
		return
	confirm_dialog = ConfirmDialog.new()
	add_child(confirm_dialog)
	confirm_dialog.confirmed.connect(_on_confirm_dialog_confirmed)


## Shows a Yes/No-style confirmation. [param action] is only invoked if the
## player presses OK (or hits Enter, since OK holds focus by default).
func _open_confirm(message: String, action: Callable) -> void:
	_ensure_confirm_dialog()
	_confirm_action = action
	confirm_dialog.open_with(message)


func _on_confirm_dialog_confirmed() -> void:
	if _confirm_action.is_valid():
		_confirm_action.call()


func _refresh_grid(live_result: Dictionary) -> void:
	var pattern_set: Dictionary = {}
	for pc in live_result["pattern_cells"]:
		pattern_set["%d,%d" % [pc["row"], pc["col"]]] = true

	for r in range(grid_rows):
		for c in range(grid_cols):
			var cell: CellView = cells[r * grid_cols + c]
			var data: Dictionary = game_state.grid[r][c]
			var in_pattern: bool = pattern_set.has("%d,%d" % [r, c])
			cell.set_data(data["color"], data["number"], in_pattern)
			cell.disabled = game_state.phase == "GAME_OVER"


func _refresh_hand() -> void:
	match game_state.phase:
		"FINAL_DRAW":
			hand_title.text = "Your Hand - Play up to 10 squares on the grid"
		"GAME_OVER":
			hand_title.text = "Your Hand"
		_:
			hand_title.text = "Your Hand - Play up to 7 squares on the grid"

	for child in hand_row.get_children():
		child.queue_free()
	square_views.clear()
	for sq in game_state.hand:
		var sv := SquareView.new()
		var is_selected: bool = sq["id"] == selected_square_id or sq["id"] == game_state.pending_invert_id
		sv.set_data(sq, is_selected)
		sv.pressed.connect(_on_square_pressed.bind(sq["id"]))
		sv.disabled = game_state.phase == "GAME_OVER"
		hand_row.add_child(sv)
		square_views.append(sv)


func _refresh_status(live_result: Dictionary) -> void:
	match game_state.phase:
		"DRAWING":
			status_label.text = "Draw %d of %d — Played %d/%d — Current Score: %d. Press Next Draw when you're ready to move on." % [
				game_state.draw_number, game_state.total_draws - 1,
				game_state.played_this_draw, GameState.MAX_PLAYS_PER_DRAW, live_result["total"]
			]
		"FINAL_DRAW":
			status_label.text = "Final Draw — %d squares left to play — Current Score: %d. Press End Game when you're finished." % [
				game_state.hand.size(), live_result["total"]
			]
		"GAME_OVER":
			status_label.text = "Game Over — Final Score: %d" % game_state.last_result.get("total", 0)

	if game_state.pending_invert_id != -1:
		hint_label.text = "Invert Wildcard selected — click another square in your hand to apply it (subtract instead of add)."


func _refresh_controls() -> void:
	next_draw_btn.visible = game_state.phase == "DRAWING"
	undo_btn.disabled = not game_state.can_undo()
	end_game_btn.visible = game_state.phase == "FINAL_DRAW"
	invert_btn.visible = game_state.pending_invert_id != -1


func _refresh_score_panel(live_result: Dictionary) -> void:
	var is_final: bool = game_state.phase == "GAME_OVER"
	var result: Dictionary = game_state.last_result if is_final else live_result
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
		"RUN": return "Run — Same Color"
		"CLUSTER": return "Cluster — Same Color"
		"RUN_MONOCHROME": return "Run — Same Color"
		"CLUSTER_MONOCHROME": return "Cluster — Same Color"
		"RUN_ALT_COLOR": return "Run — Alternating Color"
		"CLUSTER_ALT_COLOR": return "Cluster — Alternating Color"
		"ALT_NUM_MONOCHROME": return "Alternating Numbers — Same Color"
		"ALT_NUM_ALT_COLOR": return "Alternating Numbers — Alternating Color"
		_: return t
