class_name InfoView
extends Control
## A simple scrollable text panel, used for the Scoring System and
## How to Play pages.

var _rtl: RichTextLabel


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	_rtl = RichTextLabel.new()
	_rtl.bbcode_enabled = true
	_rtl.fit_content = true
	_rtl.custom_minimum_size = Vector2(700, 0)
	_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rtl)


func set_content(bbcode: String) -> void:
	if _rtl == null:
		await ready
	_rtl.text = bbcode
