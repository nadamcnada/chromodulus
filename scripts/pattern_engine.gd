class_name PatternEngine
extends RefCounted
##
## PatternEngine: pure, stateless scoring of a finished (or in-progress) grid.
##
## Design notes (the source design document is ambiguous or self-contradictory
## in a few corners; these are the concrete, internally-consistent choices
## made here, verified against every worked numeric example in the doc):
##
## - Lines scanned: 7 rows, 7 columns, and all diagonals/anti-diagonals of
##   length >= 4 (off-center diagonals included), for 28 lines total.
## - Per line, per category (numeric / chromatic), only the single longest
##   qualifying window is scored ("Pattern Overlap" rule) - shorter
##   sub-windows of the same category are never additionally scored.
## - If multiple pattern *types* match the exact same window, only the
##   highest-scoring type is awarded ("only the highest scoring ... pattern
##   is awarded").
## - Numeric+chromatic combination bonus (double/quadruple) applies only when
##   the numeric and chromatic windows on a line are the exact same range,
##   AND that line is not already part of a 2D block. When a line is part of
##   a 2D block, its numeric and chromatic scores are boosted independently
##   by the block multiplier and simply summed (this reproduces the design
##   doc's 40 / 44 / 56-point worked 2D examples exactly).
## - The 2D block multiplier is computed independently for rows and columns
##   (never diagonals), and independently for the numeric vs. chromatic
##   category, based on adjacent lines sharing an identical value sequence.
## - Nexus bonuses count, per cell, how many *different lines'* scored
##   patterns cover that cell (a line's own numeric+chromatic pair is one
##   footprint, not two, so a plain combo doesn't also trigger a nexus).

const SPECTRUM_PATTERNS: Array[String] = [
	"RYGABPR", "RPBAGYR", "GABPRYG", "GYRPBAG", "BPRYGAB", "BAGYRPB"
]

const RUN_EXTENDED_SEQUENCE: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0]

const BLOCK_MULT: Dictionary = {2: 4, 3: 8, 4: 16, 5: 20, 6: 24, 7: 28}

const SCORE_RUN: Dictionary = {4: 5, 5: 10, 6: 20, 7: 40}
const SCORE_CLUSTER: Dictionary = {4: 5, 5: 10, 6: 20, 7: 40}
const SCORE_ALT_RUN: Dictionary = {4: 2, 5: 5, 6: 10, 7: 20}
const SCORE_PYRAMID: Dictionary = {5: 5, 7: 20}
const SCORE_MONO: Dictionary = {4: 2, 5: 5, 6: 10, 7: 20}
const SCORE_ALT_COLOR: Dictionary = {4: 2, 5: 5, 6: 10, 7: 20}
const SCORE_COLOR_PYRAMID: Dictionary = {5: 5, 7: 20}
const SCORE_SPECTRUM: Dictionary = {7: 40}
const SCORE_ONE_OF_EACH: Dictionary = {7: 40}


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
			"numbers": numbers,
			"colors": colors,
			"numeric": _find_best_numeric(numbers),
			"chromatic": _find_best_chromatic(colors),
			"numeric_block": 1,
			"chromatic_block": 1,
		})

	var row_lines: Dictionary = {}
	var col_lines: Dictionary = {}
	for ld in line_data:
		if ld["orientation"] == "ROW":
			row_lines[ld["index"]] = ld
		elif ld["orientation"] == "COL":
			col_lines[ld["index"]] = ld

	_compute_blocks(row_lines, 7)
	_compute_blocks(col_lines, 7)

	var total: int = 0
	var details: Array = []
	var cell_lines: Dictionary = {}

	for li in range(line_data.size()):
		var ld: Dictionary = line_data[li]
		var contribution: Dictionary = _score_line(ld)
		total += contribution["score"]
		if contribution["detail"] != null:
			details.append(contribution["detail"])
		for p in contribution["footprint"]:
			var key: String = "%d,%d" % [p.x, p.y]
			if not cell_lines.has(key):
				cell_lines[key] = []
			(cell_lines[key] as Array).append(li)

	var nexus_total: int = 0
	var nexus_cells: Array = []
	for key in cell_lines.keys():
		var n: int = (cell_lines[key] as Array).size()
		if n >= 2:
			var parts: PackedStringArray = key.split(",")
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

static func _find_best_numeric(numbers: Array) -> Dictionary:
	var n: int = numbers.size()
	for length in range(n, 3, -1):
		for start in range(0, n - length + 1):
			var window: Array = numbers.slice(start, start + length)
			var candidates: Array = []
			if _is_run(window):
				candidates.append({"type": "RUN", "score": SCORE_RUN[length]})
			if _is_cluster(window):
				candidates.append({"type": "CLUSTER", "score": SCORE_CLUSTER[length]})
			if _is_alternating(window):
				candidates.append({"type": "ALT_RUN", "score": SCORE_ALT_RUN[length]})
			if (length == 5 or length == 7) and _is_palindrome_no_consecutive(window):
				candidates.append({"type": "PYRAMID", "score": SCORE_PYRAMID[length]})
			if candidates.size() > 0:
				candidates.sort_custom(func(a, b): return a["score"] > b["score"])
				var best: Dictionary = candidates[0]
				return {"type": best["type"], "start": start, "length": length, "score": best["score"]}
	return {}


static func _find_best_chromatic(colors: Array) -> Dictionary:
	var n: int = colors.size()
	for length in range(n, 3, -1):
		for start in range(0, n - length + 1):
			var window: Array = colors.slice(start, start + length)
			var candidates: Array = []
			if _is_cluster(window):
				candidates.append({"type": "MONOCHROME", "score": SCORE_MONO[length]})
			if _is_alternating(window):
				candidates.append({"type": "ALT_COLOR", "score": SCORE_ALT_COLOR[length]})
			if (length == 5 or length == 7) and _is_palindrome_no_consecutive(window):
				candidates.append({"type": "COLOR_PYRAMID", "score": SCORE_COLOR_PYRAMID[length]})
			if length == 7 and _is_spectrum(window):
				candidates.append({"type": "SPECTRUM", "score": SCORE_SPECTRUM[7]})
			if length == 7 and _is_one_of_each(window):
				candidates.append({"type": "ONE_OF_EACH", "score": SCORE_ONE_OF_EACH[7]})
			if candidates.size() > 0:
				candidates.sort_custom(func(a, b): return a["score"] > b["score"])
				var best: Dictionary = candidates[0]
				return {"type": best["type"], "start": start, "length": length, "score": best["score"]}
	return {}


# ---------------------------------------------------------------------------
# Pattern predicates (generic ones work for both numbers and color codes)
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


static func _is_cluster(window: Array) -> bool:
	for v in window:
		if v != window[0]:
			return false
	return true


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


static func _is_palindrome_no_consecutive(window: Array) -> bool:
	var n: int = window.size()
	for i in range(n):
		if window[i] != window[n - 1 - i]:
			return false
	for i in range(n - 1):
		if window[i] == window[i + 1]:
			return false
	return true


static func _is_spectrum(window: Array) -> bool:
	var s: String = ""
	for c in window:
		s += String(c)
	return SPECTRUM_PATTERNS.has(s)


static func _is_one_of_each(window: Array) -> bool:
	if window.size() != 7:
		return false
	var seen: Dictionary = {}
	for c in window:
		if seen.has(c):
			return false
		seen[c] = true
	return seen.size() == 7


static func _partitions_match(numbers_window: Array, colors_window: Array) -> bool:
	var n: int = numbers_window.size()
	for i in range(n):
		for j in range(i + 1, n):
			var same_num: bool = numbers_window[i] == numbers_window[j]
			var same_col: bool = colors_window[i] == colors_window[j]
			if same_num != same_col:
				return false
	return true


static func _is_quadruple(numeric: Dictionary, chromatic: Dictionary, numbers_window: Array, colors_window: Array, length: int) -> bool:
	var nt: String = numeric["type"]
	var ct: String = chromatic["type"]
	if nt == "PYRAMID" and ct == "COLOR_PYRAMID" and _partitions_match(numbers_window, colors_window):
		return true
	if nt == "ALT_RUN" and ct == "ALT_COLOR" and _partitions_match(numbers_window, colors_window):
		return true
	if nt == "RUN" and ct == "ONE_OF_EACH" and length == 7:
		return true
	if nt == "CLUSTER" and ct == "MONOCHROME" and length == 7:
		return true
	if nt == "RUN" and ct == "SPECTRUM" and length == 7:
		return true
	return false


# ---------------------------------------------------------------------------
# 2D block detection (rows and columns only, never diagonals)
# ---------------------------------------------------------------------------

static func _lines_linked_numeric(a: Dictionary, b: Dictionary) -> bool:
	var an: Dictionary = a["numeric"]
	var bn: Dictionary = b["numeric"]
	if an.is_empty() or bn.is_empty():
		return false
	if an["start"] != bn["start"] or an["length"] != bn["length"]:
		return false
	var s: int = an["start"]
	var l: int = an["length"]
	return a["numbers"].slice(s, s + l) == b["numbers"].slice(s, s + l)


static func _lines_linked_chromatic(a: Dictionary, b: Dictionary) -> bool:
	var ac: Dictionary = a["chromatic"]
	var bc: Dictionary = b["chromatic"]
	if ac.is_empty() or bc.is_empty():
		return false
	if ac["start"] != bc["start"] or ac["length"] != bc["length"]:
		return false
	var s: int = ac["start"]
	var l: int = ac["length"]
	return a["colors"].slice(s, s + l) == b["colors"].slice(s, s + l)


static func _assign_blocks(lines_by_index: Dictionary, count: int, linked: Array, field: String) -> void:
	var i: int = 0
	while i < count:
		var j: int = i
		while j + 1 < count and linked[j]:
			j += 1
		var size: int = j - i + 1
		if size >= 2:
			for k in range(i, j + 1):
				(lines_by_index[k] as Dictionary)[field] = size
		i = j + 1


static func _compute_blocks(lines_by_index: Dictionary, count: int) -> void:
	var linked_numeric: Array = []
	var linked_chromatic: Array = []
	for i in range(count - 1):
		var a: Dictionary = lines_by_index[i]
		var b: Dictionary = lines_by_index[i + 1]
		linked_numeric.append(_lines_linked_numeric(a, b))
		linked_chromatic.append(_lines_linked_chromatic(a, b))
	_assign_blocks(lines_by_index, count, linked_numeric, "numeric_block")
	_assign_blocks(lines_by_index, count, linked_chromatic, "chromatic_block")


# ---------------------------------------------------------------------------
# Per-line scoring
# ---------------------------------------------------------------------------

static func _score_line(ld: Dictionary) -> Dictionary:
	var numeric: Dictionary = ld["numeric"]
	var chromatic: Dictionary = ld["chromatic"]
	var line_len: int = ld["numbers"].size()
	var nb: int = ld["numeric_block"]
	var cb: int = ld["chromatic_block"]

	var numeric_score: int = 0
	if not numeric.is_empty():
		numeric_score = numeric["score"]
		if nb >= 2:
			numeric_score *= BLOCK_MULT[min(nb, 7)]

	var chromatic_score: int = 0
	if not chromatic.is_empty():
		chromatic_score = chromatic["score"]
		if cb >= 2:
			chromatic_score *= BLOCK_MULT[min(cb, 7)]

	var both_present: bool = not numeric.is_empty() and not chromatic.is_empty()
	var same_range: bool = both_present and numeric["start"] == chromatic["start"] and numeric["length"] == chromatic["length"]
	var no_block: bool = nb < 2 and cb < 2

	var final_score: int = 0
	var combo_note: String = ""

	if both_present and same_range and no_block:
		var s: int = numeric["start"]
		var l: int = numeric["length"]
		var numbers_window: Array = ld["numbers"].slice(s, s + l)
		var colors_window: Array = ld["colors"].slice(s, s + l)
		var quad: bool = _is_quadruple(numeric, chromatic, numbers_window, colors_window, l)
		var is_full_line: bool = l == line_len
		if quad:
			final_score = (numeric_score + chromatic_score) * 4
			combo_note = "quadruple"
		elif is_full_line:
			final_score = (numeric_score + chromatic_score) * 2
			combo_note = "double"
		else:
			final_score = numeric_score + chromatic_score
	else:
		final_score = numeric_score + chromatic_score

	var covered: Dictionary = {}
	if not numeric.is_empty():
		for i in range(numeric["start"], numeric["start"] + numeric["length"]):
			covered[i] = true
	if not chromatic.is_empty():
		for i in range(chromatic["start"], chromatic["start"] + chromatic["length"]):
			covered[i] = true
	var footprint: Array = []
	for i in covered.keys():
		footprint.append(ld["points"][i])

	var detail = null
	if final_score > 0:
		detail = {
			"orientation": ld["orientation"],
			"line_index": ld["index"],
			"numeric": numeric,
			"chromatic": chromatic,
			"numeric_block": nb,
			"chromatic_block": cb,
			"combo": combo_note,
			"score": final_score,
		}

	return {"score": final_score, "detail": detail, "footprint": footprint}
