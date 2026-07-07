extends RefCounted
class_name ItemLevelBadge

const UI_LABEL_SETTINGS: LabelSettings = preload("res://Themes/new_label_settings.tres")
const BADGE_NAME: String = "LevelBadge"
const ROMAN_LEVELS: Dictionary = {
	1: "I",
	2: "II",
	3: "III",
}


static func update_badge(parent: Control, level: int) -> void:
	if parent == null:
		return

	var badge: Label = parent.get_node_or_null(BADGE_NAME) as Label
	if level <= 0:
		if badge != null:
			parent.remove_child(badge)
			badge.free()
		return

	if badge == null:
		badge = Label.new()
		badge.name = BADGE_NAME
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		badge.offset_left = -28.0
		badge.offset_top = -16.0
		badge.offset_right = -1.0
		badge.offset_bottom = -1.0
		badge.z_index = 10
		parent.add_child(badge)

	badge.text = String(ROMAN_LEVELS.get(level, str(level)))
	badge.label_settings = _make_label_settings()


static func _make_label_settings() -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = UI_LABEL_SETTINGS.font
	settings.font_size = max(6, UI_LABEL_SETTINGS.font_size - 3)
	settings.font_color = Color(1.0, 0.95, 0.65, 1.0)
	settings.outline_color = Color(0.05, 0.04, 0.02, 1.0)
	settings.outline_size = 3
	return settings
