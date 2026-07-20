class_name PatternEngine
extends RefCounted
##
## PatternEngine: pure, stateless scoring of a finished (or in-progress) grid.
## Takes a [param ruleset] ("CLASSIC", "PLUS", "ONE_LINER" or "ONE_LINER_PLUS")
## so the same engine can serve every game version.
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
## Design notes, consistent since the original Base engine:
## - Classic/Plus: 7 rows, 7 columns, and all diagonals/anti-diagonals of
##   length >= 4 (off-center diagonals included), for 28 lines total. Per
##   line, only the single longest qualifying window is scored (shorter
##   sub-windows of the same line are never additionally scored).
## - Nexus bonuses count, per cell, how many independently scored patterns
##   (whether from different lines, or - for the One-Liner rulesets - from
##   the same line) cover that cell.

const RUN_EXTENDED_SEQUENCE: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0]

const SCORE_TABLE: Dictionary = {4: 2, 5: 5, 6: 10, 7: 20}
const ONE_LINER_SCORE_TABLE: Dictionary = {4: 2, 5: 5, 6: 10, 7: 20, 8: 30, 9: 40, 10: 50}

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
		var pattern: Dictionary = (
			_find_best_pattern_plus(numbers, colors) if ruleset == "PLUS"
			else _find_best_pattern(numbers, colors)
		)
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
