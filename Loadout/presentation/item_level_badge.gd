extends RefCounted
class_name ItemLevelBadge

const LevelBadgeScript: GDScript = preload("res://UI/shared/level_badge.gd")


static func update_badge(parent: Control, level: int) -> void:
	LevelBadgeScript.update_badge(parent, level)


static func clear_badge(parent: Control) -> void:
	LevelBadgeScript.clear_badge(parent)


static func to_roman(level: int) -> String:
	return LevelBadgeScript.to_roman(level)
