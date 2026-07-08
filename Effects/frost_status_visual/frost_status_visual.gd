extends Node2D
class_name FrostStatusVisual

const ICE_ALPHA: float = 0.58

@onready var ice_overlay: Sprite2D = $IceOverlay

var _is_frozen: bool = false


func _ready() -> void:
	_sync_ice_overlay()


func set_frost_state(_stacks: int, _max_stacks: int, is_frozen: bool) -> void:
	_is_frozen = is_frozen
	_sync_ice_overlay()


func _sync_ice_overlay() -> void:
	if ice_overlay == null:
		ice_overlay = get_node_or_null("IceOverlay") as Sprite2D
	if ice_overlay == null:
		return
	ice_overlay.visible = _is_frozen
	ice_overlay.modulate = Color(0.88, 0.96, 1.0, ICE_ALPHA)
