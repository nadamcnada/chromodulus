class_name ConfirmDialog
extends Window
## A small OK/Cancel confirmation popup with deliberately large text, used for
## New Game and End Game. Built from scratch (rather than Godot's built-in
## AcceptDialog) so the message text's font size is fully under our control.

signal confirmed
signal cancelled

const SIZE := Vector2i(560, 260)
const FONT_SIZE := 32

var ok_btn: Button
var cancel_btn: Button
var message_label: Label


func _ready() -> void:
	visible = false
	exclusive = true
	unresizable = true
	size = SIZE
	close_requested.connect(_on_cancel_pressed)
	_build_ui()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)

	message_label = Label.new()
	message_label.add_theme_font_size_override("font_size", FONT_SIZE)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(message_label)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 20)
	vbox.add_child(button_row)

	ok_btn = Button.new()
	ok_btn.text = "OK"
	ok_btn.custom_minimum_size = Vector2(140, 60)
	ok_btn.add_theme_font_size_override("font_size", FONT_SIZE)
	ok_btn.pressed.connect(_on_ok_pressed)
	button_row.add_child(ok_btn)

	cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(140, 60)
	cancel_btn.add_theme_font_size_override("font_size", FONT_SIZE)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	button_row.add_child(cancel_btn)


## Shows the dialog with the given message. OK grabs focus so it's
## highlighted and pressing Enter activates it (standard focused-button
## behavior); Cancel (or closing the window) just hides it.
func open_with(message: String) -> void:
	message_label.text = message
	popup_centered(SIZE)
	ok_btn.grab_focus()


func _on_ok_pressed() -> void:
	hide()
	confirmed.emit()


func _on_cancel_pressed() -> void:
	hide()
	cancelled.emit()
