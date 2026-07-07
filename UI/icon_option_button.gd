extends Button
class_name IconOptionButton

const LevelBadgeScript: GDScript = preload("res://UI/level_badge.gd")
const UI_LABEL_SETTINGS: LabelSettings = preload("res://Themes/new_label_settings.tres")

var _icon_area: Control
var _icon_rect: TextureRect
var _title_label: Label
var _description_label: Label


func _init() -> void:
	_build_ui()


func set_option(texture: Texture2D, title: String, description: String, level: int) -> void:
	_build_ui()
	text = ""
	_icon_rect.texture = texture
	_icon_rect.visible = texture != null
	_title_label.text = title
	_description_label.text = description
	LevelBadgeScript.update_badge(_icon_area, level)


func clear_option() -> void:
	_build_ui()
	text = ""
	_icon_rect.texture = null
	_icon_rect.hide()
	_title_label.text = ""
	_description_label.text = ""
	LevelBadgeScript.clear_badge(_icon_area)


func _build_ui() -> void:
	if _icon_rect != null:
		return
	text = ""
	clip_text = true
	focus_mode = Control.FOCUS_ALL

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "OptionContent"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 5)
	add_child(margin)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.name = "OptionLayout"
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 3)
	margin.add_child(layout)

	_icon_area = Control.new()
	_icon_area.name = "OptionIconArea"
	_icon_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_area.custom_minimum_size = Vector2(30, 28)
	_icon_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(_icon_area)

	_icon_rect = TextureRect.new()
	_icon_rect.name = "OptionIcon"
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon_area.add_child(_icon_rect)

	_title_label = Label.new()
	_title_label.name = "OptionTitle"
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.clip_text = true
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_label_settings(_title_label, -2)
	layout.add_child(_title_label)

	_description_label = Label.new()
	_description_label.name = "OptionDescription"
	_description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.clip_text = true
	_description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_label_settings(_description_label, -3)
	layout.add_child(_description_label)


func _apply_label_settings(label: Label, size_delta: int) -> void:
	var settings := LabelSettings.new()
	settings.font = UI_LABEL_SETTINGS.font
	settings.font_size = max(6, UI_LABEL_SETTINGS.font_size + size_delta)
	settings.font_color = UI_LABEL_SETTINGS.font_color
	settings.outline_color = UI_LABEL_SETTINGS.outline_color
	settings.outline_size = UI_LABEL_SETTINGS.outline_size
	label.label_settings = settings
