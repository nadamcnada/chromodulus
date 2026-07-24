class_name PatternEngine
extends RefCounted
##
## PatternEngine: pure, stateless scoring of a finished (or in-progress) grid.
## Takes a [param ruleset] ("CLASSIC", "PLUS", "ONE_LINER", "ONE_LINER_PLUS"
## or "ULTIMATE") so the same engine can serve every game version.
##
## CLASSIC: every scoring pattern is chromo-numerical - a Run or a Cluster of
## the exact same color. There are no separate numeric-only / chromatic-only
## patterns, no combination bonuses, and no 2D pattern multipliers.
##
## PLUS: everything Classic allows, plus Alternating Numbers and Alternating
## Colors. Numeric shape (Run / Cluster / Alternating Numbers) and chromatic
## shape (Monochrome / Alternating Colors) are now checked independently; a
## window only scores if BOTH shapes qualify on the exact same cells. All six
## pairings (Run/Cluster/Alternating Numbers x Monochrome/Alternating Colors)
## share the exact same table below - Plus never scores an existing Classic
## pattern (Run/Cluster + Monochrome) any differently than Classic does.
##
## ONE_LINER / ONE_LINER_PLUS: played on a single 10-cell row rather than a
## 7x7 grid (ONE_LINER uses Classic's shapes, ONE_LINER_PLUS uses Plus's).
## Since there's only one line, "only the single longest window per line"
## would leave almost the whole row unscorable, so these two rulesets instead
## find every *maximal* qualifying window - one not entirely contained inside
## a longer qualifying window - and score all of them. Two maximal windows
## are still allowed to partially overlap (e.g. a 4-cell match at cells 1-4
## and another at cells 3-6): the shared cells become Nexus cells same as
## they would across two different lines elsewhere. Lengths 8-10 extend the
## score table (30/40/50pts).
##
## PUZZLE: a 3x3 grid, win/lose rather than scored - see check_puzzle_solved().
##
## ULTIMATE: a 7x7 grid like Classic/Plus (starting fill drawn from all seven
## colors rather than four - that's a GameState concern, not PatternEngine's),
## with everything Plus allows plus five more chromo-numerical pattern types:
## Doublet, Pyramid, Plateau, Staircase and Full Spectrum (see the predicates
## below each pattern's score table). Each of these five is its own fused
## chromatic+numerical shape (not an independent numeric x chromatic pairing
## like Plus's six), and each only qualifies at specific lengths. When more
## than one pattern type qualifies for the exact same window, the
## highest-scoring one wins (see _find_best_pattern_ultimate).
##
## Design notes, consistent since the original Base engine:
## - Classic/Plus/Ultimate: 7 rows, 7 columns, and all diagonals/anti-diagonals
##   of length >= 4 (off-center diagonals included), for 28 lines total. Per
##   line, only the single longest qualifying window is scored (shorter
##   sub-windows of the same line are never additionally scored).
## - Nexus bonuses count, per cell, how many independently scored patterns
##   (whether from different lines, or - for the One-Liner rulesets - from
##   the same line) cover that cell.

const RUN_EXTENDED_SEQUENCE: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0]
const ALL_SEVEN_COLORS: Array[String] = ["R", "G", "B", "W", "Y", "P", "A"]

const SCORE_TABLE: Dictionary = {4: 2, 5: 5, 6: 10, 7: 20}
const ONE_LINER_SCORE_TABLE: Dictionary = {4: 2, 5: 5, 6: 10, 7: 20, 8: 40, 9: 70, 10: 100}
const DOUBLET_SCORE_TABLE: Dictionary = {4: 2, 6: 10}
const PYRAMID_SCORE_TABLE: Dictionary = {5: 10, 7: 30}
const PLATEAU_SCORE_TABLE: Dictionary = {6: 20, 7: 30}
const STAIRCASE_SCORE: int = 20
const FULL_SPECTRUM_SCORE: int = 40

const ONE_LINER_RULESETS: Array[String] = ["ONE_LINER", "ONE_LINER_PLUS"]


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------

static func score_grid(grid: Array, ruleset: String = "CLASSIC") -> Dictionary:
	var instances: Array = (
		_score_one_liner(grid, ruleset) if ONE_LINER_RULESETS.has(ruleset)
		else _score_grid_lines(grid, ruleset)
	)
	return _aggregate(instances)


## Classic/Plus: one 7x7 grid, up to one scored pattern per line (28 lines).
static func _score_grid_lines(grid: Array, ruleset: String) -> Array:
	var lines: Array = _generate_lines()
	var instances: Array = []

	for line in lines:
		var pts: Array = line["points"]
		var numbers: Array = []
		var colors: Array = []
		for p in pts:
			var cell: Dictionary = grid[p.x][p.y]
			numbers.append(cell["number"])
			colors.append(cell["color"])
		var pattern: Dictionary
		if ruleset == "PLUS":
			pattern = _find_best_pattern_plus(numbers, colors)
		elif ruleset == "ULTIMATE":
			pattern = _find_best_pattern_ultimate(numbers, colors)
		else:
			pattern = _find_best_pattern(numbers, colors)
		if pattern.is_empty():
			continue
		var cells: Array = []
		for i in range(pattern["start"], pattern["start"] + pattern["length"]):
			cells.append(pts[i])
		instances.append({
			"orientation": line["orientation"],
			"line_index": line["index"],
			"type": pattern["type"],
			"length": pattern["length"],
			"score": pattern["score"],
			"cells": cells,
		})

	return instances


## One-Liner/One-Liner Plus: a single 10-cell row. Every maximal qualifying
## window is scored (see class doc), so multiple, possibly overlapping,
## patterns can co-exist on the one line.
static func _score_one_liner(grid: Array, ruleset: String) -> Array:
	var row: Array = grid[0]
	var pts: Array = []
	var numbers: Array = []
	var colors: Array = []
	for c in range(row.size()):
		var cell: Dictionary = row[c]
		pts.append(Vector2i(0, c))
		numbers.append(cell["number"])
		colors.append(cell["color"])

	var use_plus: bool = ruleset == "ONE_LINER_PLUS"
	var candidates: Array = _find_all_maximal_patterns(numbers, colors, use_plus)
	var instances: Array = []
	for cand in candidates:
		var cells: Array = []
		for i in range(cand["start"], cand["start"] + cand["length"]):
			cells.append(pts[i])
		instances.append({
			"orientation": "ROW",
			"line_index": 0,
			"type": cand["type"],
			"length": cand["length"],
			"score": cand["score"],
			"cells": cells,
		})

	return instances


## Every qualifying window in [param numbers]/[param colors], excluding any
## window that's entirely contained inside a longer qualifying window (that
## longer match already "covers" it - see class doc). Windows that only
## partially overlap are both kept.
static func _find_all_maximal_patterns(numbers: Array, colors: Array, use_plus: bool) -> Array:
	var n: int = numbers.size()
	var candidates: Array = []
	for length in range(n, 3, -1):
		for start in range(0, n - length + 1):
			var num_window: Array = numbers.slice(start, start + length)
			var col_window: Array = colors.slice(start, start + length)
			var type: String = ""
			if use_plus:
				var numeric_type: String = _numeric_shape(num_window)
				var chromatic_type: String = _chromatic_shape(col_window)
				if numeric_type != "" and chromatic_type != "":
					type = "%s_%s" % [numeric_type, chromatic_type]
			elif _is_same(col_window):
				if _is_cluster(num_window):
					type = "CLUSTER"
				elif _is_run(num_window):
					type = "RUN"
			if type != "":
				candidates.append({
					"start": start, "length": length, "type": type,
					"score": ONE_LINER_SCORE_TABLE[length],
				})

	var maximal: Array = []
	for i in range(candidates.size()):
		var cand: Dictionary = candidates[i]
		var contained: bool = false
		for j in range(candidates.size()):
			if i == j:
				continue
			var other: Dictionary = candidates[j]
			var other_end: int = other["start"] + other["length"]
			var cand_end: int = cand["start"] + cand["length"]
			if other["length"] > cand["length"] and other["start"] <= cand["start"] and other_end >= cand_end:
				contained = true
				break
		if not contained:
			maximal.append(cand)
	return maximal


## Shared by both scoring paths: sums pattern scores, then computes Nexus
## bonuses from how many pattern instances (regardless of which line/window
## they came from) cover each cell.
static func _aggregate(instances: Array) -> Dictionary:
	var total: int = 0
	var details: Array = []
	var cell_lines: Dictionary = {}

	for idx in range(instances.size()):
		var inst: Dictionary = instances[idx]
		total += inst["score"]
		details.append({
			"orientation": inst["orientation"],
			"line_index": inst["line_index"],
			"type": inst["type"],
			"length": inst["length"],
			"score": inst["score"],
		})
		for p in inst["cells"]:
			var key: String = "%d,%d" % [p.x, p.y]
			if not cell_lines.has(key):
				cell_lines[key] = []
			(cell_lines[key] as Array).append(idx)

	var nexus_total: int = 0
	var nexus_cells: Array = []
	var pattern_cells: Array = []
	for key in cell_lines.keys():
		var parts: PackedStringArray = key.split(",")
		pattern_cells.append({"row": int(parts[0]), "col": int(parts[1])})
		var n: int = (cell_lines[key] as Array).size()
		if n >= 2:
			var bonus: int = 80
			if n == 2:
				bonus = 20
			elif n == 3:
				bonus = 40
			nexus_total += bonus
			nexus_cells.append({"row": int(parts[0]), "col": int(parts[1]), "links": n, "bonus": bonus})

	total += nexus_total

	return {
		"total": total,
		"patterns": details,
		"nexus_cells": nexus_cells,
		"nexus_total": nexus_total,
		"pattern_cells": pattern_cells,
	}


# ---------------------------------------------------------------------------
# Line generation
# ---------------------------------------------------------------------------

static func _generate_lines() -> Array:
	var lines: Array = []
	for r in range(7):
		var pts: Array = []
		for c in range(7):
			pts.append(Vector2i(r, c))
		lines.append({"orientation": "ROW", "index": r, "points": pts})

	for c in range(7):
		var pts: Array = []
		for r in range(7):
			pts.append(Vector2i(r, c))
		lines.append({"orientation": "COL", "index": c, "points": pts})

	# "\" diagonals: col - row = d, off-center allowed, length >= 4 => |d| <= 3
	for d in range(-3, 4):
		var pts: Array = []
		for r in range(7):
			var c: int = r + d
			if c >= 0 and c < 7:
				pts.append(Vector2i(r, c))
		lines.append({"orientation": "DIAG", "index": d, "points": pts})

	# "/" diagonals: row + col = s, length >= 4 => 3 <= s <= 9
	for s in range(3, 10):
		var pts: Array = []
		for r in range(7):
			var c: int = s - r
			if c >= 0 and c < 7:
				pts.append(Vector2i(r, c))
		lines.append({"orientation": "ADIAG", "index": s, "points": pts})

	return lines


# ---------------------------------------------------------------------------
# Best-window search
# ---------------------------------------------------------------------------

## Finds the longest window (>= 4 cells) that is entirely one color AND is
## either a Run or a Cluster of numbers. Returns {} if nothing qualifies.
static func _find_best_pattern(numbers: Array, colors: Array) -> Dictionary:
	var n: int = numbers.size()
	for length in range(n, 3, -1):
		for start in range(0, n - length + 1):
			var color_window: Array = colors.slice(start, start + length)
			if not _is_same(color_window):
				continue
			var num_window: Array = numbers.slice(start, start + length)
			if _is_cluster(num_window):
				return {"type": "CLUSTER", "start": start, "length": length, "score": SCORE_TABLE[length]}
			if _is_run(num_window):
				return {"type": "RUN", "start": start, "length": length, "score": SCORE_TABLE[length]}
	return {}


## Plus: numeric shape and chromatic shape are found independently; a window
## only scores if both qualify on the same cells. Every qualifying pairing
## uses the same SCORE_TABLE - there's no combo multiplier.
static func _find_best_pattern_plus(numbers: Array, colors: Array) -> Dictionary:
	var n: int = numbers.size()
	for length in range(n, 3, -1):
		for start in range(0, n - length + 1):
			var num_window: Array = numbers.slice(start, start + length)
			var col_window: Array = colors.slice(start, start + length)
			var numeric_type: String = _numeric_shape(num_window)
			var chromatic_type: String = _chromatic_shape(col_window)
			if numeric_type == "" or chromatic_type == "":
				continue
			return {
				"type": "%s_%s" % [numeric_type, chromatic_type],
				"start": start,
				"length": length,
				"score": SCORE_TABLE[length],
			}
	return {}


static func _numeric_shape(window: Array) -> String:
	if _is_cluster(window):
		return "CLUSTER"
	if _is_run(window):
		return "RUN"
	if _is_alternating(window):
		return "ALT_NUM"
	return ""


static func _chromatic_shape(window: Array) -> String:
	if _is_same(window):
		return "MONOCHROME"
	if _is_alternating(window):
		return "ALT_COLOR"
	return ""


## Ultimate: everything Plus checks (Run/Cluster/Alternating Numbers crossed
## with Monochrome/Alternating Color, sharing SCORE_TABLE) plus Doublet,
## Pyramid, Plateau, Staircase and Full Spectrum, each its own fused
## chromatic+numerical shape valid only at specific lengths. If more than one
## pattern type qualifies for the same exact window, the highest-scoring one
## is returned (per the Scoring System's tie-break rule).
static func _find_best_pattern_ultimate(numbers: Array, colors: Array) -> Dictionary:
	var n: int = numbers.size()
	for length in range(n, 3, -1):
		for start in range(0, n - length + 1):
			var num_window: Array = numbers.slice(start, start + length)
			var col_window: Array = colors.slice(start, start + length)
			var best_type: String = ""
			var best_score: int = -1

			var numeric_type: String = _numeric_shape(num_window)
			var chromatic_type: String = _chromatic_shape_ultimate(col_window)
			if numeric_type != "" and chromatic_type != "":
				var score: int = (
					FULL_SPECTRUM_SCORE if chromatic_type == "FULL_SPECTRUM"
					else SCORE_TABLE[length]
				)
				if score > best_score:
					best_score = score
					best_type = "%s_%s" % [numeric_type, chromatic_type]

			if DOUBLET_SCORE_TABLE.has(length) and _is_doublet(num_window, col_window):
				var score: int = DOUBLET_SCORE_TABLE[length]
				if score > best_score:
					best_score = score
					best_type = "DOUBLET"

			if PYRAMID_SCORE_TABLE.has(length) and _is_pyramid(num_window, col_window):
				var score: int = PYRAMID_SCORE_TABLE[length]
				if score > best_score:
					best_score = score
					best_type = "PYRAMID"

			if PLATEAU_SCORE_TABLE.has(length) and _is_plateau(num_window, col_window):
				var score: int = PLATEAU_SCORE_TABLE[length]
				if score > best_score:
					best_score = score
					best_type = "PLATEAU"

			if length == 6 and _is_staircase(num_window, col_window):
				if STAIRCASE_SCORE > best_score:
					best_score = STAIRCASE_SCORE
					best_type = "STAIRCASE"

			if best_type != "":
				return {"type": best_type, "start": start, "length": length, "score": best_score}
	return {}


## Same as _chromatic_shape, plus Full Spectrum: all seven colors present,
## each exactly once (only possible at length 7).
static func _chromatic_shape_ultimate(window: Array) -> String:
	if _is_same(window):
		return "MONOCHROME"
	if _is_alternating(window):
		return "ALT_COLOR"
	if _is_full_spectrum(window):
		return "FULL_SPECTRUM"
	return ""


static func _is_full_spectrum(window: Array) -> bool:
	if window.size() != 7:
		return false
	var seen: Dictionary = {}
	for c in window:
		if seen.has(c):
			return false
		seen[c] = true
	return true


## Shared by Doublet/Pyramid/Plateau/Staircase: wherever a number reappears
## within the window, it must keep the same color throughout.
static func _colors_consistent_with_numbers(numbers: Array, colors: Array) -> bool:
	var color_for_number: Dictionary = {}
	for i in range(numbers.size()):
		var num = numbers[i]
		var col = colors[i]
		if color_for_number.has(num):
			if color_for_number[num] != col:
				return false
		else:
			color_for_number[num] = col
	return true


## Pairs of equal numbers (AABB or AABBCC); adjacent pairs must differ, but a
## number can reappear in a non-adjacent pair (e.g. AABBAA). Length is 4 or 6.
static func _is_doublet(numbers: Array, colors: Array) -> bool:
	var pair_count: int = numbers.size() / 2
	var pair_values: Array = []
	for p in range(pair_count):
		var a = numbers[p * 2]
		var b = numbers[p * 2 + 1]
		if a != b:
			return false
		pair_values.append(a)
	for p in range(pair_count - 1):
		if pair_values[p] == pair_values[p + 1]:
			return false
	return _colors_consistent_with_numbers(numbers, colors)


## Stricter than _colors_consistent_with_numbers: also requires different
## numbers to use different colors, so number<->color is a true one-to-one
## correspondence. Used by Staircase, which has no palindrome structure to
## check number-repetition separately (its three segments already can't
## overlap), so this single check covers both rules at once.
static func _colors_bijective_with_numbers(numbers: Array, colors: Array) -> bool:
	var color_for_number: Dictionary = {}
	var seen_colors: Dictionary = {}
	for i in range(numbers.size()):
		var num = numbers[i]
		var col = colors[i]
		if color_for_number.has(num):
			if color_for_number[num] != col:
				return false
		else:
			if seen_colors.has(col):
				return false
			color_for_number[num] = col
			seen_colors[col] = true
	return true


## A palindrome (numbers[i] == numbers[n-1-i]) where every "slot" - each
## mirrored pair, plus the unpaired center - uses its own number and its own
## color; no number or color may be reused by a different slot. Length is
## 5 or 7.
static func _is_pyramid(numbers: Array, colors: Array) -> bool:
	var n: int = numbers.size()
	for i in range(n):
		if numbers[i] != numbers[n - 1 - i]:
			return false
	for i in range(n):
		if colors[i] != colors[n - 1 - i]:
			return false

	var slot_count: int = (n + 1) / 2
	var seen_numbers: Dictionary = {}
	var seen_colors: Dictionary = {}
	for i in range(slot_count):
		if seen_numbers.has(numbers[i]):
			return false
		seen_numbers[numbers[i]] = true
		if seen_colors.has(colors[i]):
			return false
		seen_colors[colors[i]] = true
	return true


## Same as Pyramid, except the true center is required to repeat with its
## neighbor(s) - for even length the two middle cells (already forced equal
## by the palindrome itself), for odd length the middle cell and its
## neighbor - and that repeated middle counts as a single slot (its number/
## color only needs to be distinct from the *other* slots, not from itself).
## Length is 6 or 7.
static func _is_plateau(numbers: Array, colors: Array) -> bool:
	var n: int = numbers.size()
	for i in range(n):
		if numbers[i] != numbers[n - 1 - i]:
			return false
	if n % 2 == 1:
		var c: int = (n - 1) / 2
		if numbers[c] != numbers[c - 1]:
			return false
	for i in range(n):
		if colors[i] != colors[n - 1 - i]:
			return false

	var slot_count: int = n / 2
	var seen_numbers: Dictionary = {}
	var seen_colors: Dictionary = {}
	for i in range(slot_count):
		if seen_numbers.has(numbers[i]):
			return false
		seen_numbers[numbers[i]] = true
		if seen_colors.has(colors[i]):
			return false
		seen_colors[colors[i]] = true
	return true


## Exactly 6 cells matching [a,b,b,c,c,c] (forward) or [c,c,c,b,b,a]
## (reverse), where a, b and c are all different from each other (a can no
## longer equal c).
static func _is_staircase(numbers: Array, colors: Array) -> bool:
	var forward_ok: bool = (
		numbers[1] == numbers[2] and numbers[3] == numbers[4] and numbers[4] == numbers[5]
		and numbers[0] != numbers[1] and numbers[1] != numbers[3] and numbers[0] != numbers[3]
	)
	var reverse_ok: bool = (
		numbers[0] == numbers[1] and numbers[1] == numbers[2] and numbers[3] == numbers[4]
		and numbers[2] != numbers[3] and numbers[3] != numbers[5] and numbers[2] != numbers[5]
	)
	if not (forward_ok or reverse_ok):
		return false
	return _colors_bijective_with_numbers(numbers, colors)


# ---------------------------------------------------------------------------
# Pattern predicates
# ---------------------------------------------------------------------------

static func _matches_extended(seq: Array) -> bool:
	var e: Array = RUN_EXTENDED_SEQUENCE
	var m: int = seq.size()
	for i in range(0, e.size() - m + 1):
		var found: bool = true
		for j in range(m):
			if e[i + j] != seq[j]:
				found = false
				break
		if found:
			return true
	return false


static func _is_run(window: Array) -> bool:
	if _matches_extended(window):
		return true
	var rev: Array = window.duplicate()
	rev.reverse()
	return _matches_extended(rev)


static func _is_same(window: Array) -> bool:
	for v in window:
		if v != window[0]:
			return false
	return true


static func _is_cluster(window: Array) -> bool:
	return _is_same(window)


## True if window is a repeating block of 2+ distinct values, repeated at
## least twice (the block may trail off partway on its last repeat, e.g.
## 12121 is period-2 repeated 2.5 times). Used for both Alternating Numbers
## and Alternating Colors - generic over whatever element type is passed in.
static func _is_alternating(window: Array) -> bool:
	var n: int = window.size()
	var distinct: Dictionary = {}
	for v in window:
		distinct[v] = true
	if distinct.size() < 2:
		return false
	var max_p: int = n / 2
	for p in range(2, max_p + 1):
		if n < 2 * p:
			continue
		var ok: bool = true
		for i in range(p, n):
			if window[i] != window[i - p]:
				ok = false
				break
		if ok:
			return true
	return false


# ---------------------------------------------------------------------------
# Puzzle (NxN - 3x3, 4x4 or 5x5 - win/lose)
# ---------------------------------------------------------------------------

## A Puzzle grid (any NxN size) is solved when BOTH hold:
## 1. Every one of its 2N + 2 lines (N rows, N columns, 2 main diagonals) is,
##    on its own, a numeric Cluster or Run (colors aren't considered per
##    line here).
## 2. The grid's colors as a whole form one of two allowed arrangements: a
##    2-color checkerboard, or N rows (or N columns) each solid a single
##    color - the rows/columns don't need distinct colors from each other
##    (all one color, or some sharing a color with others different, both
##    count), they just each need to be internally uniform.
static func check_puzzle_solved(grid: Array) -> bool:
	return _puzzle_numeric_lines_ok(grid) and _puzzle_color_pattern_ok(grid)


## Grid size is inferred from the grid itself (grid.size() rows), so this
## works unchanged for any NxN Puzzle size.
static func _puzzle_lines(n: int) -> Array:
	var lines: Array = []
	for r in range(n):
		var row_line: Array = []
		for c in range(n):
			row_line.append(Vector2i(r, c))
		lines.append(row_line)
	for c in range(n):
		var col_line: Array = []
		for r in range(n):
			col_line.append(Vector2i(r, c))
		lines.append(col_line)
	var main_diag: Array = []
	var anti_diag: Array = []
	for i in range(n):
		main_diag.append(Vector2i(i, i))
		anti_diag.append(Vector2i(i, n - 1 - i))
	lines.append(main_diag)
	lines.append(anti_diag)
	return lines


static func _puzzle_numeric_lines_ok(grid: Array) -> bool:
	for line in _puzzle_lines(grid.size()):
		var numbers: Array = []
		for p in line:
			numbers.append(grid[p.x][p.y]["number"])
		if not (_is_cluster(numbers) or _is_run(numbers)):
			return false
	return true


static func _puzzle_color_pattern_ok(grid: Array) -> bool:
	var n: int = grid.size()
	var colors: Array = []
	for r in range(n):
		var row: Array = []
		for c in range(n):
			row.append(grid[r][c]["color"])
		colors.append(row)

	return (
		_puzzle_is_checkerboard(colors)
		or _puzzle_is_solid_rows(colors)
		or _puzzle_is_solid_rows(_transpose_square(colors))
	)


static func _transpose_square(colors: Array) -> Array:
	var n: int = colors.size()
	var t: Array = []
	for c in range(n):
		var row: Array = []
		for r in range(n):
			row.append(colors[r][c])
		t.append(row)
	return t


static func _puzzle_is_checkerboard(colors: Array) -> bool:
	var n: int = colors.size()
	var color_a: String = colors[0][0]
	var color_b: String = colors[0][1]
	if color_a == color_b:
		return false
	for r in range(n):
		for c in range(n):
			var expected: String = color_a if (r + c) % 2 == 0 else color_b
			if colors[r][c] != expected:
				return false
	return true


## True if every row is solid one color - the rows don't need distinct
## colors from each other. Called a second time on the transposed grid to
## also check solid columns.
static func _puzzle_is_solid_rows(colors: Array) -> bool:
	var n: int = colors.size()
	for r in range(n):
		var first: String = colors[r][0]
		for c in range(n):
			if colors[r][c] != first:
				return false
	return true
