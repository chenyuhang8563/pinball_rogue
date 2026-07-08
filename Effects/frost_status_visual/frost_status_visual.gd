extends Node2D
class_name FrostStatusVisual

const ICE_ALPHA: float = 0.58

@onready var ice_overlay: Sprite2D = $IceOverlay


func set_frost_state(_stacks: int, _max_stacks: int, is_frozen: bool) -> void:
	if ice_overlay == null:
		return
	ice_overlay.visible = is_frozen
	ice_overlay.modulate = Color(0.88, 0.96, 1.0, ICE_ALPHA)
