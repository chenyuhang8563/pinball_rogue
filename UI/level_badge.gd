extends RefCounted
class_name LevelBadge

const UI_LABEL_SETTINGS: LabelSettings = preload("res://Themes/new_label_settings.tres")
const LocaleFontSettingsScript: GDScript = preload("res://UI/locale_font_settings.gd")
const LevelBadgeScene: PackedScene = preload("res://UI/level_badge.tscn")
const BADGE_NAME: String = "LevelBadge"
const ROMAN_LEVELS: Dictionary = {
	1: "I",
	2: "II",
	3: "III",
	4: "IV",
}


static func update_badge(parent: Control, level: int) -> void:
	if parent == null:
		return
	if level <= 0:
		clear_badge(parent)
		return

	var badge: Label = parent.get_node_or_null(BADGE_NAME) as Label
	if badge == null:
		badge = LevelBadgeScene.instantiate() as Label
		badge.name = BADGE_NAME
		parent.add_child(badge)

	badge.text = to_roman(level)
	apply_to_label(badge, level)


static func clear_badge(parent: Control) -> void:
	if parent == null:
		return
	var badge: Label = parent.get_node_or_null(BADGE_NAME) as Label
	if badge != null:
		parent.remove_child(badge)
		badge.free()


static func to_roman(level: int) -> String:
	return String(ROMAN_LEVELS.get(level, str(level)))


static func apply_to_label(label: Label, level: int) -> void:
	if label == null:
		return
	label.text = to_roman(level)
	label.label_settings = _make_label_settings()


static func _make_label_settings() -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = LocaleFontSettingsScript.font_for_size(UI_LABEL_SETTINGS.font_size)
	settings.font_size = UI_LABEL_SETTINGS.font_size
	settings.font_color = Color(1.0, 0.95, 0.65, 1.0)
	settings.outline_color = Color(0.05, 0.04, 0.02, 1.0)
	settings.outline_size = 3
	return settings
