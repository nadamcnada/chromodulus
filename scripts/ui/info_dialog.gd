class_name InfoDialog
extends Control
## A modal info popup (Scoring System / How to Play) confined to and
## centered within whatever Control it's added to - e.g. the game content
## area, so it never covers the left navigation sidebar. Built as plain
## Controls (not a Window) so "centered" is just anchoring within its
## parent's own rect, not screen-space math.

var _rtl: RichTextLabel
var _backdrop: ColorRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0.45)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.gui_input.connect(_on_backdrop_gui_input)
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 640)
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color.WHITE
	panel_sb.border_color = Color.BLACK
	panel_sb.border_width_left = 2
	panel_sb.border_width_right = 2
	panel_sb.border_width_top = 2
	panel_sb.border_width_bottom = 2
	panel_sb.content_margin_left = 24
	panel_sb.content_margin_right = 24
	panel_sb.content_margin_top = 20
	panel_sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", panel_sb)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_rtl = RichTextLabel.new()
	_rtl.bbcode_enabled = true
	_rtl.fit_content = true
	_rtl.custom_minimum_size = Vector2(760, 0)
	_rtl.add_theme_color_override("default_color", Color.BLACK)
	scroll.add_child(_rtl)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(hide)
	vbox.add_child(close_btn)


func open_with(bbcode: String) -> void:
	_rtl.text = bbcode
	visible = true


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide()
