class_name WildcardDialog
extends Window
## Popup used to configure a Color / Number / Chromodulus Wildcard when the
## player selects it from their hand.

signal color_chosen(square_id: int, color: String)
signal number_chosen(square_id: int, number: int)
signal chromodulus_chosen(square_id: int, color: String, number: int)
signal cancelled

var square_id: int = -1
var wtype: String = ""
var _picked_color: String = ""
var _picked_number: int = -1


func _ready() -> void:
	title = "Choose"
	size = Vector2i(380, 320)
	unresizable = true
	exclusive = true
	close_requested.connect(_on_cancel_pressed)


func open_for(sq: Dictionary) -> void:
	square_id = sq["id"]
	wtype = sq["wtype"]
	_picked_color = ""
	_picked_number = -1
	_build_ui()
	popup_centered()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	match wtype:
		"COLOR":
			title = "Color Wildcard"
		"NUMBER":
			title = "Number Wildcard"
		"CHROMODULUS":
			title = "Chromodulus Wildcard"

	if wtype == "COLOR" or wtype == "CHROMODULUS":
		var lbl := Label.new()
		lbl.text = "Choose a color:"
		vbox.add_child(lbl)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		vbox.add_child(row)
		for color in ColorRules.PLAYABLE_ADDED_COLORS:
			var b := Button.new()
			b.text = ColorRules.color_name(color)
			b.custom_minimum_size = Vector2(90, 44)
			b.pressed.connect(_on_color_pressed.bind(color))
			row.add_child(b)

	if wtype == "NUMBER" or wtype == "CHROMODULUS":
		var lbl2 := Label.new()
		lbl2.text = "Choose a number:"
		vbox.add_child(lbl2)
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		vbox.add_child(grid)
		for n in range(10):
			var b := Button.new()
			b.text = str(n)
			b.custom_minimum_size = Vector2(52, 44)
			b.pressed.connect(_on_number_pressed.bind(n))
			grid.add_child(b)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_on_cancel_pressed)
	vbox.add_child(cancel_btn)


func _on_color_pressed(color: String) -> void:
	if wtype == "COLOR":
		color_chosen.emit(square_id, color)
		hide()
		return
	_picked_color = color
	_try_finish_chromodulus()


func _on_number_pressed(n: int) -> void:
	if wtype == "NUMBER":
		number_chosen.emit(square_id, n)
		hide()
		return
	_picked_number = n
	_try_finish_chromodulus()


func _try_finish_chromodulus() -> void:
	if wtype == "CHROMODULUS" and _picked_color != "" and _picked_number >= 0:
		chromodulus_chosen.emit(square_id, _picked_color, _picked_number)
		hide()


func _on_cancel_pressed() -> void:
	cancelled.emit()
	hide()
