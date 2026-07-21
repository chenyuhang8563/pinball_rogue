extends Control
class_name ItemIconView

const LevelBadgeScript: GDScript = preload("res://UI/shared/level_badge.gd")

var _icon: TextureRect
var _level_badge: Label
var _level: int = 0


func _ready() -> void:
	_bind_nodes()
	set_level(_level)


func set_texture(texture: Texture2D) -> void:
	_bind_nodes()
	if _icon == null:
		return
	_icon.texture = texture
	_icon.visible = texture != null


func get_texture() -> Texture2D:
	_bind_nodes()
	if _icon == null:
		return null
	return _icon.texture


func set_level(level: int) -> void:
	_bind_nodes()
	_level = level
	if _level_badge == null:
		return
	if level <= 0:
		_level_badge.text = ""
		_level_badge.hide()
		return
	LevelBadgeScript.apply_to_label(_level_badge, level)
	_level_badge.show()


func set_level_visible(enabled: bool) -> void:
	_bind_nodes()
	if _level_badge == null:
		return
	_level_badge.visible = enabled and _level > 0


func clear() -> void:
	set_texture(null)
	set_level(0)


func _bind_nodes() -> void:
	if _icon != null and _level_badge != null:
		return
	_icon = get_node_or_null("Icon") as TextureRect
	_level_badge = get_node_or_null("LevelBadge") as Label
