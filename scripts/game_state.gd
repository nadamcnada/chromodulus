class_name GameState
extends RefCounted
##
## GameState: the authoritative Chromodulus game engine, shared by every
## game version (Classic, Plus, One-Liner, One-Liner Plus, Puzzle, Ultimate,
## ...). Each GameView owns its own instance - these are separate,
## independent games, not one shared session - and the [member ruleset]
## tells PatternEngine which scoring rules to apply.
##
## Classic/Plus/Ultimate own a 7x7 grid and a five-draw sequence: four
## 10-card draws (play up to 7, then advance with Next Draw) followed by a
## fifth and final 10-card draw (play any/all, then End Game). Ultimate's
## grid starts pre-filled from all seven colors instead of four (see
## _random_cell()) - hand squares and wildcards are unaffected, still
## Red/Green/Blue only. One-Liner/One-Liner Plus own a single 1x10 row, and
## Puzzle an NxN grid (3x3, 4x4 or 5x5, per [member puzzle_size]), each with
## a three-draw sequence instead (two 10-card draws, play up to 7 each, then
## a third and final draw playing any/all). Undo steps back one played
## square at a time but never crosses into a previous draw - it can only go
## as far back as the current draw's freshly dealt hand.
##
## Puzzle is win/lose rather than scored: end_game() checks
## PatternEngine.check_puzzle_solved() instead of score_grid(). It also ends
## automatically - every play_square() checks the win condition, and the
## moment it's met the game jumps straight to GAME_OVER and emits
## [signal puzzle_solved], without waiting for the final draw or an explicit
## End Game press.

signal state_changed
signal message(text: String)
signal puzzle_solved

const MAX_PLAYS_PER_DRAW := 7
const DRAW_SIZE := 10

var ruleset: String = "CLASSIC"  # "CLASSIC" | "PLUS" | "ONE_LINER" | "ONE_LINER_PLUS" | "PUZZLE" | "ULTIMATE"
var puzzle_size: int = 3        # 3, 4 or 5 - only meaningful when ruleset == "PUZZLE"

var grid_rows: int = 7
var grid_cols: int = 7
var total_draws: int = 5        # the last draw_number is always FINAL_DRAW

var grid: Array = []            # grid[row][col] = {"color":String,"number":int}
var hand: Array[Dictionary] = []
var draw_number: int = 1        # 1..total_draws
var played_this_draw: int = 0
var phase: String = "DRAWING"   # DRAWING | FINAL_DRAW | GAME_OVER
var pending_invert_id: int = -1
var last_result: Dictionary = {}

var _history: Array[Dictionary] = []


func _init(p_ruleset: String = "CLASSIC", p_puzzle_size: int = 3) -> void:
	ruleset = p_ruleset
	puzzle_size = p_puzzle_size
	if ruleset in ["ONE_LINER", "ONE_LINER_PLUS"]:
		grid_rows = 1
		grid_cols = 10
		total_draws = 3
	elif ruleset == "PUZZLE":
		grid_rows = puzzle_size
		grid_cols = puzzle_size
		# 3x3: 2 regular draws + a final. 4x4: one more regular draw (3)
		# before the final. 5x5: one more again (4), since there's
		# progressively more board to fill.
		if puzzle_size == 3:
			total_draws = 3
		elif puzzle_size == 4:
			total_draws = 4
		else:
			total_draws = 5
	else:
		grid_rows = 7
		grid_cols = 7
		total_draws = 5
	new_game()


func new_game() -> void:
	grid = []
	for r in range(grid_rows):
		var row: Array = []
		for c in range(grid_cols):
			row.append(_random_cell())
		grid.append(row)
	pending_invert_id = -1
	last_result = {}
	_deal_draw(1, "DRAWING")
	state_changed.emit()


func _random_cell() -> Dictionary:
	# Ultimate pre-fills from all seven colors instead of the usual four -
	# hand squares/wildcards are unaffected, still Red/Green/Blue only.
	var pool: Array = ColorRules.ALL_CELL_COLORS if ruleset == "ULTIMATE" else ColorRules.STARTING_COLORS
	var color: String = pool[randi() % pool.size()]
	var number: int = randi() % 10
	return {"color": color, "number": number}


## Deals a fresh hand for the given draw number/phase. This is the floor
## Undo cannot go past - starting a new draw always clears the undo history.
func _deal_draw(new_draw_number: int, new_phase: String) -> void:
	draw_number = new_draw_number
	phase = new_phase
	played_this_draw = 0
	pending_invert_id = -1
	hand = Deck.draw_many(DRAW_SIZE)
	_history.clear()


# ---------------------------------------------------------------------------
# Undo
# ---------------------------------------------------------------------------
#
# Each play/invert-apply pushes the state as it was immediately before that
# move. Undo pops the most recent one and restores it. The stack is cleared
# whenever a new draw is dealt, so Undo can only step back through moves made
# during the current draw - never into a previous draw.

func _snapshot() -> Dictionary:
	return {
		"grid": grid.duplicate(true),
		"hand": hand.duplicate(true),
		"draw_number": draw_number,
		"played_this_draw": played_this_draw,
		"phase": phase,
		"pending_invert_id": pending_invert_id,
	}


func _push_undo() -> void:
	_history.append(_snapshot())


func can_undo() -> bool:
	return not _history.is_empty()


func undo() -> bool:
	if not can_undo():
		message.emit("Nothing to undo.")
		return false
	var snap: Dictionary = _history.pop_back()
	grid = snap["grid"].duplicate(true)
	hand = snap["hand"].duplicate(true)
	draw_number = snap["draw_number"]
	played_this_draw = snap["played_this_draw"]
	phase = snap["phase"]
	pending_invert_id = snap["pending_invert_id"]
	last_result = {}
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
	if row < 0 or row >= grid_rows or col < 0 or col >= grid_cols:
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
		return _fail("You've played the maximum of 7 squares this draw. Press Next Draw to continue.")

	var existing: Dictionary = grid[row][col]
	var new_color: String = ColorRules.transform(existing["color"], square["color"])
	if new_color == "":
		return _fail("%s can't be played onto a %s cell (Not Allowed)." % [
			ColorRules.color_name(square["color"]), ColorRules.color_name(existing["color"])
		])

	var new_number: int
	if square["inverted"]:
		# Modular subtraction: wraps the same way addition does (e.g. 0 - 7
		# becomes 3, as if borrowing a 10), rather than a plain absolute
		# difference.
		new_number = ((existing["number"] - square["number"]) % 10 + 10) % 10
	else:
		new_number = (existing["number"] + square["number"]) % 10

	_push_undo()
	grid[row][col] = {"color": new_color, "number": new_number}
	hand.remove_at(idx)
	played_this_draw += 1

	if ruleset == "PUZZLE" and PatternEngine.check_puzzle_solved(grid):
		last_result = {"solved": true}
		phase = "GAME_OVER"
		puzzle_solved.emit()

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
		return _fail("You've played the maximum of 7 squares this draw. Press Next Draw to continue.")

	_push_undo()
	hand[tidx]["inverted"] = true
	hand.remove_at(iidx)
	pending_invert_id = -1
	played_this_draw += 1
	state_changed.emit()
	return {"ok": true, "error": ""}


## Clears whatever remains in hand and deals the next draw (or advances into
## the final draw once all but the last draw are done). Only valid before
## the final draw.
func next_draw() -> Dictionary:
	if phase != "DRAWING":
		return _fail("Next Draw is only available before the final draw.")
	if draw_number < total_draws - 1:
		_deal_draw(draw_number + 1, "DRAWING")
	else:
		_deal_draw(total_draws, "FINAL_DRAW")
	state_changed.emit()
	return {"ok": true, "error": ""}


func end_game() -> Dictionary:
	if phase != "FINAL_DRAW":
		return _fail("You can only end the game after the final draw.")
	if ruleset == "PUZZLE":
		last_result = {"solved": PatternEngine.check_puzzle_solved(grid)}
	else:
		last_result = PatternEngine.score_grid(grid, ruleset)
	phase = "GAME_OVER"
	state_changed.emit()
	return {"ok": true, "error": ""}


func _fail(text: String) -> Dictionary:
	message.emit(text)
	return {"ok": false, "error": text}
