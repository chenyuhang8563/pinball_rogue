extends Resource
class_name BuffDef

## Data definition for a buff.
##
## BuffManager owns runtime state such as remaining time and stacks. This
## resource stays read-only and describes how a buff should be applied.

enum BuffSource {
	SHOP,
	COMBAT_DROP,
	CHAIN_MECHANIC,
	RELIC,
}

enum ReapplyPolicy {
	REFRESH,
	IGNORE,
}

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var duration: float = -1.0
@export var stackable: bool = false
@export var max_stacks: int = 1
@export var source: BuffSource = BuffSource.SHOP
@export var params: Dictionary = {}
@export var effect_script: GDScript
@export var reapply_policy: ReapplyPolicy = ReapplyPolicy.REFRESH


func is_permanent() -> bool:
	return duration < 0.0


func on_apply(_host: Node, _state: Dictionary) -> void:
	pass


func on_process(_host: Node, _state: Dictionary, _delta: float) -> void:
	pass


func on_remove(_host: Node, _state: Dictionary) -> void:
	pass


func on_duration_appended(_host: Node, _state: Dictionary, _duration: float) -> void:
	pass


func on_host_death(_host: Node, _state: Dictionary) -> void:
	pass
