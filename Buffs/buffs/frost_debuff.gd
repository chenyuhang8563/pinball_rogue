extends BuffDef
class_name FrostDebuff

const FROZEN_DEBUFF_SCRIPT: GDScript = preload("res://Buffs/buffs/frozen_debuff.gd")
const FROST_COLOR: Color = Color(0.55, 0.85, 1.0, 1.0)
const DEFAULT_DURATION: float = 5.0
const MAX_FROST_STACKS: int = 6
const META_FROST_TO_FROZEN_TRANSITION: StringName = &"frost_to_frozen_transition"
const STAT_ENTITY_MARBLE_CHAIN: String = "marble_chain"
const STAT_BLUE_FROST_DURATION: String = "blue_frost_duration"


func _init() -> void:
	id = "frost_debuff"
	display_name = "Frost"
	description = "Adds frost on hit. Full frost freezes enemies."
	duration = _get_frost_duration()
	stackable = true
	max_stacks = MAX_FROST_STACKS
	source = BuffSource.CHAIN_MECHANIC
	params = {
		"flash_color": FROST_COLOR,
	}


func on_apply(host: Node, state: Dictionary) -> void:
	var stacks: int = clampi(int(state.get("stacks", 1)), 1, max_stacks)
	state["hit_flash_color"] = FROST_COLOR
	_flash_host(host)
	if stacks >= max_stacks:
		_convert_to_frozen(host)
		return
	_apply_visual(host, stacks)


func on_remove(host: Node, _state: Dictionary) -> void:
	if host.has_method("clear_frost_visual"):
		host.call("clear_frost_visual")


func _apply_visual(host: Node, stacks: int) -> void:
	if host.has_method("set_frost_visual"):
		host.call("set_frost_visual", stacks, max_stacks, false)


func _flash_host(host: Node) -> void:
	if host.has_method("flash_hit_mask"):
		host.call("flash_hit_mask", FROST_COLOR)


func _convert_to_frozen(host: Node) -> void:
	if host.has_method("remove_buff"):
		host.set_meta(META_FROST_TO_FROZEN_TRANSITION, true)
		host.call("remove_buff", id)
		host.set_meta(META_FROST_TO_FROZEN_TRANSITION, false)
	if host.has_method("add_buff"):
		host.call("add_buff", FROZEN_DEBUFF_SCRIPT.new())


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
