extends BuffDef
class_name PoisonDebuff

## Poison debuff applied by GreenMarble.
##
## The debuff owns poison timing, damage, and visual color. Hosts only need to
## expose generic `take_damage()` and `flash_hit_mask()` methods.

const POISON_COLOR: Color = Color(0.2, 1.0, 0.2, 1.0)
const DAMAGE_PER_SECOND: int = 2
const TICK_SECONDS: float = 1.0
const STAT_ENTITY_MARBLE_CHAIN: String = "marble_chain"
const STAT_POISON_DAMAGE_PER_TICK: String = "poison_damage_per_tick"
const STAT_POISON_TICK_SECONDS: String = "poison_tick_seconds"


func _init() -> void:
	id = "poison_debuff"
	display_name = "Poison"
	description = "Takes 2 damage per second for 10 seconds."
	duration = 10.0
	stackable = false
	max_stacks = 1
	source = BuffSource.CHAIN_MECHANIC
	params = {
		"damage_per_tick": DAMAGE_PER_SECOND,
		"flash_color": POISON_COLOR,
	}


func on_apply(host: Node, state: Dictionary) -> void:
	state["tick_accumulator"] = 0.0
	state["hit_flash_color"] = POISON_COLOR
	_flash_host(host)


func on_process(host: Node, state: Dictionary, delta: float) -> void:
	var tick_accumulator: float = float(state.get("tick_accumulator", 0.0)) + delta
	var tick_seconds: float = _get_poison_tick_seconds()

	while tick_accumulator >= tick_seconds:
		tick_accumulator -= tick_seconds
		if host.has_method("take_damage"):
			host.call("take_damage", _get_poison_damage_per_tick(), _get_flash_color())

	state["tick_accumulator"] = tick_accumulator


func _flash_host(host: Node) -> void:
	if host.has_method("flash_hit_mask"):
		host.call("flash_hit_mask", _get_flash_color())


func _get_flash_color() -> Color:
	var color: Variant = params.get("flash_color", POISON_COLOR)
	return color if color is Color else POISON_COLOR


func _get_poison_damage_per_tick() -> int:
	var stat_system: Node = _get_stat_system()
	if stat_system != null and stat_system.has_method("get_stat"):
		return int(stat_system.call("get_stat", STAT_POISON_DAMAGE_PER_TICK, STAT_ENTITY_MARBLE_CHAIN))
	return int(params.get("damage_per_tick", DAMAGE_PER_SECOND))


func _get_poison_tick_seconds() -> float:
	var stat_system: Node = _get_stat_system()
	if stat_system != null and stat_system.has_method("get_stat"):
		return maxf(0.01, float(stat_system.call("get_stat", STAT_POISON_TICK_SECONDS, STAT_ENTITY_MARBLE_CHAIN)))
	return TICK_SECONDS


func _get_stat_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("StatSystem")
