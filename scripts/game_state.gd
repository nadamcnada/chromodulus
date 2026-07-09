extends Node
##
## GameState: the authoritative Chromodulus "Base" game engine.
##
## Owns the 7x7 grid, the current hand, Turn-10 Mode bookkeeping, wildcard
## interactions and a 10-step undo history. UI code should only mutate the
## game through the public methods here so that undo snapshots stay correct.

signal state_changed
signal message(text: String)
signal game_over(result: Dictionary)

const GRID_SIZE := 7
const MAX_PLAYS_PER_DRAW := 7
const MAX_DISCARDS_PER_DRAW := 5
const MIN_DISCARDS_PER_DRAW := 3
const MAX_UNDO_STEPS := 10

var grid: Array = []            # grid[row][col] = {"color":String,"number":int}
var hand: Array[Dictionary] = []
var draw_number: int = 1        # 1..5
var played_this_draw: int = 0
var discards_this_draw: int = 0
var total_discards_first_four: int = 0
var final_draw_size: int = 0
var phase: String = "DRAWING"   # DRAWING | FINAL_DRAW | GAME_OVER
var pending_invert_id: int = -1
var last_result: Dictionary = {}

var _history: Array[Dictionary] = []


func _ready() -> void:
	new_game()


func new_game() -> void:
	grid = []
	for r in range(GRID_SIZE):
		var row: Array = []
		for c in range(GRID_SIZE):
			row.append(_random_cell())
		grid.append(row)
	_history.clear()
	draw_number = 1
	played_this_draw = 0
	discards_this_draw = 0
	total_discards_first_four = 0
	final_draw_size = 0
	phase = "DRAWING"
	pending_invert_id = -1
	last_result = {}
	hand = Deck.draw_many(10)
	state_changed.emit()


func _random_cell() -> Dictionary:
	var color: String = ColorRules.STARTING_COLORS[randi() % ColorRules.STARTING_COLORS.size()]
	var number: int = randi() % 10
	return {"color": color, "number": number}


# ---------------------------------------------------------------------------
# Undo
# ---------------------------------------------------------------------------

func _snapshot() -> Dictionary:
	return {
		"grid": grid.duplicate(true),
		"hand": hand.duplicate(true),
		"draw_number": draw_number,
		"played_this_draw": played_this_draw,
		"discards_this_draw": discards_this_draw,
		"total_discards_first_four": total_discards_first_four,
		"final_draw_size": final_draw_size,
		"phase": phase,
		"pending_invert_id": pending_invert_id,
		"last_result": last_result.duplicate(true),
	}


func _push_undo() -> void:
	_history.append(_snapshot())
	if _history.size() > MAX_UNDO_STEPS:
		_history.pop_front()


func can_undo() -> bool:
	return not _history.is_empty()


func undo() -> bool:
	if _history.is_empty():
		message.emit("Nothing to undo.")
		return false
	var snap: Dictionary = _history.pop_back()
	grid = snap["grid"].duplicate(true)
	hand = snap["hand"].duplicate(true)
	draw_number = snap["draw_number"]
	played_this_draw = snap["played_this_draw"]
	discards_this_draw = snap["discards_this_draw"]
	total_discards_first_four = snap["total_discards_first_four"]
	final_draw_size = snap["final_draw_size"]
	phase = snap["phase"]
	pending_invert_id = snap["pending_invert_id"]
	last_result = snap["last_result"].duplicate(true)
	state_changed.emit()
	return true


# ---------------------------------------------------------------------------
# Hand helpers
# ---------------------------------------------------------------------------

func find_hand_index(square_id: int) -> int:
	for i in range(hand.size()):
		if hand[i]["id"] == square_id:
			return i
	return -1


func can_play_more() -> bool:
	if phase == "FINAL_DRAW":
		return true
	return played_this_draw < MAX_PLAYS_PER_DRAW


func can_discard_more() -> bool:
	if phase == "FINAL_DRAW":
		return true
	return discards_this_draw < MAX_DISCARDS_PER_DRAW


func is_wildcard_configured(square: Dictionary) -> bool:
	match square["wtype"]:
		"NONE", "INVERT":
			return true
		"COLOR":
			return square["color"] != ""
		"NUMBER":
			return square["number"] >= 0
		"CHROMODULUS":
			return square["color"] != "" and square["number"] >= 0
		_:
			return true


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

## Plays a hand square onto grid[row][col]. Returns {"ok":bool, "error":String}.
func play_square(square_id: int, row: int, col: int) -> Dictionary:
	if phase == "GAME_OVER":
		return _fail("The game is over.")
	if row < 0 or row >= GRID_SIZE or col < 0 or col >= GRID_SIZE:
		return _fail("Invalid cell.")
	var idx: int = find_hand_index(square_id)
	if idx == -1:
		return _fail("That square is not in your hand.")
	var square: Dictionary = hand[idx]
	if square["wtype"] == "INVERT":
		return _fail("The Invert Wildcard can't be placed directly. Select it, then choose a square in your hand to invert.")
	if not is_wildcard_configured(square):
		return _fail("Choose a color/number for this wildcard before playing it.")
	if not can_play_more():
		return _fail("You've played the maximum of 7 squares this draw. Discard the rest.")

	var existing: Dictionary = grid[row][col]
	var new_color: String = ColorRules.transform(existing["color"], square["color"])
	if new_color == "":
		return _fail("%s can't be played onto a %s cell (Not Allowed)." % [
			ColorRules.color_name(square["color"]), ColorRules.color_name(existing["color"])
		])

	var new_number: int
	if square["inverted"]:
		new_number = abs(existing["number"] - square["number"])
	else:
		new_number = (existing["number"] + square["number"]) % 10

	_push_undo()
	grid[row][col] = {"color": new_color, "number": new_number}
	hand.remove_at(idx)
	played_this_draw += 1
	_advance_if_hand_empty()
	state_changed.emit()
	return {"ok": true, "error": ""}


func discard_square(square_id: int) -> Dictionary:
	if phase == "GAME_OVER":
		return _fail("The game is over.")
	var idx: int = find_hand_index(square_id)
	if idx == -1:
		return _fail("That square is not in your hand.")
	if not can_discard_more():
		return _fail("You've already discarded the maximum of 5 squares this draw.")

	_push_undo()
	if square_id == pending_invert_id:
		pending_invert_id = -1
	hand.remove_at(idx)
	if phase == "DRAWING":
		discards_this_draw += 1
	_advance_if_hand_empty()
	state_changed.emit()
	return {"ok": true, "error": ""}


func configure_wildcard(square_id: int, color: String, number: int) -> Dictionary:
	var idx: int = find_hand_index(square_id)
	if idx == -1:
		return _fail("That square is not in your hand.")
	var square: Dictionary = hand[idx]
	if not ["COLOR", "NUMBER", "CHROMODULUS"].has(square["wtype"]):
		return _fail("That square doesn't need configuring.")
	if square["wtype"] in ["COLOR", "CHROMODULUS"]:
		if not ColorRules.PLAYABLE_ADDED_COLORS.has(color):
			return _fail("Choose Red, Green or Blue.")
	if square["wtype"] in ["NUMBER", "CHROMODULUS"]:
		if number < 0 or number > 9:
			return _fail("Choose a number from 0-9.")

	_push_undo()
	if square["wtype"] == "COLOR":
		hand[idx]["color"] = color
	elif square["wtype"] == "NUMBER":
		hand[idx]["number"] = number
	elif square["wtype"] == "CHROMODULUS":
		hand[idx]["color"] = color
		hand[idx]["number"] = number
	state_changed.emit()
	return {"ok": true, "error": ""}


## Step 1 of playing an Invert Wildcard: select it from hand.
func select_invert(square_id: int) -> Dictionary:
	var idx: int = find_hand_index(square_id)
	if idx == -1:
		return _fail("That square is not in your hand.")
	if hand[idx]["wtype"] != "INVERT":
		return _fail("That isn't an Invert Wildcard.")
	pending_invert_id = square_id
	state_changed.emit()
	return {"ok": true, "error": ""}


func cancel_invert() -> void:
	pending_invert_id = -1
	state_changed.emit()


## Step 2: apply the selected Invert Wildcard to another hand square.
func apply_invert_to(target_id: int) -> Dictionary:
	if pending_invert_id == -1:
		return _fail("Select the Invert Wildcard first.")
	if target_id == pending_invert_id:
		return _fail("Choose a different square to invert.")
	var tidx: int = find_hand_index(target_id)
	if tidx == -1:
		return _fail("That square is not in your hand.")
	if hand[tidx]["wtype"] == "INVERT":
		return _fail("You can't invert another Invert Wildcard.")
	var iidx: int = find_hand_index(pending_invert_id)
	if iidx == -1:
		pending_invert_id = -1
		return _fail("The Invert Wildcard is no longer in your hand.")
	if not can_play_more():
		return _fail("You've played the maximum of 7 squares this draw. Discard the rest.")

	_push_undo()
	hand[tidx]["inverted"] = true
	hand.remove_at(iidx)
	pending_invert_id = -1
	played_this_draw += 1
	_advance_if_hand_empty()
	state_changed.emit()
	return {"ok": true, "error": ""}


func end_game() -> Dictionary:
	if phase != "FINAL_DRAW":
		return _fail("You can only end the game after the final draw.")
	_push_undo()
	var result: Dictionary = PatternEngine.score_grid(grid)
	last_result = result
	phase = "GAME_OVER"
	state_changed.emit()
	game_over.emit(result)
	return {"ok": true, "error": ""}


func _advance_if_hand_empty() -> void:
	if not hand.is_empty():
		return
	if phase != "DRAWING":
		return
	total_discards_first_four += discards_this_draw
	if draw_number < 4:
		draw_number += 1
		played_this_draw = 0
		discards_this_draw = 0
		hand = Deck.draw_many(10)
	else:
		final_draw_size = (total_discards_first_four + 1) / 2
		draw_number = 5
		played_this_draw = 0
		discards_this_draw = 0
		phase = "FINAL_DRAW"
		hand = Deck.draw_many(final_draw_size)


func _fail(text: String) -> Dictionary:
	message.emit(text)
	return {"ok": false, "error": text}
