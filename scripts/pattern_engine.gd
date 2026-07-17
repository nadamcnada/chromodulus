class_name PatternEngine
extends RefCounted
##
## PatternEngine: pure, stateless scoring of a finished (or in-progress) grid,
## implementing the Chromodulus Classic scoring system.
##
## Every scoring pattern is chromo-numerical: a Run or a Cluster of the exact
## same color. There are no separate numeric-only / chromatic-only patterns,
## no combination bonuses, and no 2D pattern multipliers - Classic is
## intentionally simpler than the original Base ruleset.
##
## Design notes, consistent with the Base engine this replaced:
## - Lines scanned: 7 rows, 7 columns, and all diagonals/anti-diagonals of
##   length >= 4 (off-center diagonals included), for 28 lines total.
## - Per line, only the single longest qualifying window is scored (shorter
##   sub-windows of the same line are never additionally scored).
## - Nexus bonuses count, per cell, how many *different lines'* scored
##   patterns cover that cell.

const RUN_EXTENDED_SEQUENCE: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0]

const SCORE_TABLE: Dictionary = {4: 2, 5: 5, 6: 10, 7: 20}


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------

static func score_grid(grid: Array) -> Dictionary:
	var lines: Array = _generate_lines()
	var line_data: Array = []

	for line in lines:
		var pts: Array = line["points"]
		var numbers: Array = []
		var colors: Array = []
		for p in pts:
			var cell: Dictionary = grid[p.x][p.y]
			numbers.append(cell["number"])
			colors.append(cell["color"])
		line_data.append({
			"orientation": line["orientation"],
			"index": line["index"],
			"points": pts,
			"pattern": _find_best_pattern(numbers, colors),
		})

	var total: int = 0
	var details: Array = []
	var cell_lines: Dictionary = {}

	for li in range(line_data.size()):
		var ld: Dictionary = line_data[li]
		var pattern: Dictionary = ld["pattern"]
		if pattern.is_empty():
			continue
		total += pattern["score"]
		details.append({
			"orientation": ld["orientation"],
			"line_index": ld["index"],
			"type": pattern["type"],
			"length": pattern["length"],
			"score": pattern["score"],
		})
		for i in range(pattern["start"], pattern["start"] + pattern["length"]):
			var p: Vector2i = ld["points"][i]
			var key: String = "%d,%d" % [p.x, p.y]
			if not cell_lines.has(key):
				cell_lines[key] = []
			(cell_lines[key] as Array).append(li)

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


# ---------------------------------------------------------------------------
# Pattern predicates
# ---------------------------------------------------------------------------

static func _matches_extended(seq: Array) -> bool:
	var e: Array = RUN_EXTENDED_SEQUENCE
	var m: int = seq.size()
	for i in range(0, e.size() - m + 1):
		if e.slice(i, i + m) == seq:
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
