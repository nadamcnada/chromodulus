extends Node
##
## ColorRules: color identities, RGB values, and the chromatic transform table.
##
## Colors are represented as short string codes:
##   R = Red, G = Green, B = Blue, W = White, Y = Yellow, P = Purple, A = Aqua
##
## Only R, G, B are ever "added" colors (squares drawn from the deck, or chosen
## for wildcards, are always Red, Green or Blue). W/Y/P/A only ever occur as
## existing cell colors (starting grid fill or the result of a transform).

const ALL_CELL_COLORS: Array[String] = ["R", "G", "B", "W", "Y", "P", "A"]
const STARTING_COLORS: Array[String] = ["R", "G", "B", "W"]
const PLAYABLE_ADDED_COLORS: Array[String] = ["R", "G", "B"]

const NAMES: Dictionary = {
	"R": "Red",
	"G": "Green",
	"B": "Blue",
	"W": "White",
	"Y": "Yellow",
	"P": "Purple",
	"A": "Aqua",
}

# Normalized RGB per the design document.
const RGB: Dictionary = {
	"R": Color(0.82, 0.0, 0.0),
	"G": Color(0.0, 0.53, 0.22),
	"B": Color(0.0, 0.32, 0.73),
	"Y": Color(1.0, 0.78, 0.0),
	"P": Color(0.38, 0.04, 0.87),
	"A": Color(0.0, 0.78, 0.78),
	"W": Color(1.0, 1.0, 1.0),
}

# Color of the number glyph drawn on top of each cell color.
const TEXT_COLOR: Dictionary = {
	"R": Color.WHITE,
	"G": Color.WHITE,
	"B": Color.WHITE,
	"Y": Color.BLACK,
	"P": Color.WHITE,
	"A": Color.BLACK,
	"W": Color.BLACK,
}

# existing color -> added color -> new color ("" means Not Allowed)
const TRANSFORM: Dictionary = {
	"W": {"R": "R", "G": "G", "B": "B"},
	"R": {"G": "Y", "B": "P", "R": ""},
	"G": {"R": "Y", "B": "A", "G": ""},
	"B": {"R": "P", "G": "A", "B": ""},
	"Y": {"B": "W", "R": "", "G": ""},
	"P": {"G": "W", "R": "", "B": ""},
	"A": {"R": "W", "B": "", "G": ""},
}


## Returns the resulting cell color when [param added_color] is played onto
## a cell currently colored [param existing_color]. Returns "" if the
## combination is Not Allowed.
func transform(existing_color: String, added_color: String) -> String:
	if not TRANSFORM.has(existing_color):
		return ""
	var row: Dictionary = TRANSFORM[existing_color]
	if not row.has(added_color):
		return ""
	return row[added_color]


func is_allowed(existing_color: String, added_color: String) -> bool:
	return transform(existing_color, added_color) != ""


func color_name(code: String) -> String:
	return NAMES.get(code, code)


func rgb(code: String) -> Color:
	return RGB.get(code, Color.MAGENTA)


func text_color(code: String) -> Color:
	return TEXT_COLOR.get(code, Color.BLACK)
