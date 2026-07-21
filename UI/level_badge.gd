extends RefCounted
class_name LevelBadge

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
