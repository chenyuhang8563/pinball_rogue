extends BuffDef
class_name FrostDebuff

const FROST_COLOR: Color = Color(0.55, 0.85, 1.0, 1.0)
const DEFAULT_DURATION: float = 2.0
const MAX_FROST_STACKS: int = 3
const STAT_ENTITY_MARBLE_CHAIN: String = "marble_chain"
const STAT_BLUE_FROST_DURATION: String = "blue_frost_duration"
const STAT_BLUE_FROST_FREEZE_ENABLED: String = "blue_frost_freeze_enabled"


func _init() -> void:
	id = "frost_debuff"
	display_name = "Frost"
	description = "Adds frost on hit. Awakened frost freezes at full stacks."
	duration = _get_frost_duration()
	stackable = true
	max_stacks = MAX_FROST_STACKS
	source = BuffSource.CHAIN_MECHANIC
	params = {
		"flash_color": FROST_COLOR,
	}


func on_apply(host: Node, state: Dictionary) -> void:
	var stacks: int = clampi(int(state.get("stacks", 1)), 1, max_stacks)
	var is_frozen: bool = _is_awakened(state) and stacks >= max_stacks
	state["hit_flash_color"] = FROST_COLOR
	state["is_frozen"] = is_frozen
	_apply_visual(host, stacks, is_frozen)
	_flash_host(host)


func on_remove(host: Node, _state: Dictionary) -> void:
	if host.has_method("clear_frost_visual"):
		host.call("clear_frost_visual")


func _apply_visual(host: Node, stacks: int, is_frozen: bool) -> void:
	if host.has_method("set_frost_visual"):
		host.call("set_frost_visual", stacks, max_stacks, is_frozen)


func _flash_host(host: Node) -> void:
	if host.has_method("flash_hit_mask"):
		host.call("flash_hit_mask", FROST_COLOR)


func _is_awakened(state: Dictionary) -> bool:
	if bool(state.get("awakened", false)):
		return true
	var stat_system: Node = _get_stat_system()
	if stat_system != null and stat_system.has_method("get_stat"):
		return int(stat_system.call("get_stat", STAT_BLUE_FROST_FREEZE_ENABLED, STAT_ENTITY_MARBLE_CHAIN)) > 0
	return false


func _get_frost_duration() -> float:
	var stat_system: Node = _get_stat_system()
	if stat_system != null and stat_system.has_method("get_stat"):
		return maxf(DEFAULT_DURATION, float(stat_system.call("get_stat", STAT_BLUE_FROST_DURATION, STAT_ENTITY_MARBLE_CHAIN)))
	return DEFAULT_DURATION


func _get_stat_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("StatSystem")
