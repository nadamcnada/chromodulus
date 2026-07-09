extends Node
##
## Deck: the virtual, inexhaustible stock deck.
##
## 30 unique chromo-numerical squares (Red/Green/Blue x 0-9), each drawn with
## weight 5, plus 15 unique wildcards each drawn with weight 1. Total pool
## weight = 30*5 + 15*1 = 165, giving each chromo-numerical square a 5/165
## (~3%, "1 in 33") chance and each wildcard a 1/165 (~0.2%) chance, matching
## the design document exactly.

const WT_NORMAL := 5
const WT_WILD := 1

var _tickets: Array[Dictionary] = []
var _next_id: int = 1

func _ready() -> void:
	_build_pool()


func _build_pool() -> void:
	_tickets.clear()
	for color in ColorRules.PLAYABLE_ADDED_COLORS:
		for number in range(0, 10):
			var tmpl := {
				"kind": "NORMAL",
				"wtype": "NONE",
				"color": color,
				"number": number,
			}
			for i in range(WT_NORMAL):
				_tickets.append(tmpl)

	# 10 x Color Wildcard (preset number 0-9, color chosen at play time)
	for number in range(0, 10):
		var tmpl := {
			"kind": "WILD",
			"wtype": "COLOR",
			"color": "",
			"number": number,
		}
		for i in range(WT_WILD):
			_tickets.append(tmpl)

	# 3 x Number Wildcard (preset color, number chosen at play time)
	for color in ColorRules.PLAYABLE_ADDED_COLORS:
		var tmpl := {
			"kind": "WILD",
			"wtype": "NUMBER",
			"color": color,
			"number": -1,
		}
		for i in range(WT_WILD):
			_tickets.append(tmpl)

	# 1 x Chromodulus Wildcard (both color and number chosen at play time)
	var chromodulus_tmpl := {
		"kind": "WILD",
		"wtype": "CHROMODULUS",
		"color": "",
		"number": -1,
	}
	for i in range(WT_WILD):
		_tickets.append(chromodulus_tmpl)

	# 1 x Invert Wildcard (applied to another hand square, never placed itself)
	var invert_tmpl := {
		"kind": "WILD",
		"wtype": "INVERT",
		"color": "",
		"number": -1,
	}
	for i in range(WT_WILD):
		_tickets.append(invert_tmpl)


## Draws one square from the deck. Every call is an independent, uniformly
## weighted draw (the deck is inexhaustible).
func draw_one() -> Dictionary:
	var tmpl: Dictionary = _tickets[randi() % _tickets.size()]
	var square := tmpl.duplicate(true)
	square["id"] = _next_id
	square["inverted"] = false
	_next_id += 1
	return square


func draw_many(count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(count):
		result.append(draw_one())
	return result
