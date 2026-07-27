extends BuffDef
class_name PoisonDebuff

const DamagePacketScript: GDScript = preload("res://Combat/damage/damage_packet.gd")

## Poison debuff applied by GreenMarble.
##
## The debuff owns poison timing, damage, and visual color. Hosts only need to
## expose generic `take_damage()` and `flash_hit_mask()` methods.

const POISON_COLOR: Color = Color(0.2, 1.0, 0.2, 1.0)
const DAMAGE_PER_LAYER: int = 1
const TICK_SECONDS: float = 1.0
const STAT_ENTITY_MARBLE_CHAIN: String = "marble_chain"
const STAT_POISON_DAMAGE_PER_LAYER: String = "poison_damage_per_layer"
const STAT_POISON_MAX_STACKS: String = "poison_max_stacks"
const STAT_POISON_TICK_SECONDS: String = "poison_tick_seconds"
## Base poison cap before any marble upgrades; the stat-driven value grows this
## to 15/20. Also the degraded fallback when the stat system is unavailable.
const BASE_POISON_CAP: int = 10
## Hard ceiling for the stat-driven poison cap. Green Marble upgrades grow it to
## 20; the Witch Hat relic can then extend that ceiling to 30.
const MAX_POISON_STACKS: int = 30


func _init() -> void:
	id = "poison_debuff"
	display_name = "Poison"
	description = "Deals 1 damage per layer each second; each application refreshes a shared 5 second timer."
	duration = 5.0
	stackable = true
	max_stacks = _get_poison_max_stacks()
	source = BuffSource.CHAIN_MECHANIC
	params = {
		"damage_per_layer": DAMAGE_PER_LAYER,
		"flash_color": POISON_COLOR,
	}


func on_apply(host: Node, state: Dictionary) -> void:
	state["tick_accumulator"] = 0.0
	state["hit_flash_color"] = POISON_COLOR
	_flash_host(host)
	_try_infect(host, state)


## Once poison stacks reach the infection threshold the host becomes permanently
## infected. Infection never reverts even if the poison DoT later decays, so this
## is a one-way gate checked on every apply/refresh.
func _try_infect(host: Node, state: Dictionary) -> void:
	if int(state.get("stacks", 0)) < InfectionDebuff.INFECTION_THRESHOLD:
		return
	if not host.has_method("add_buff") or not host.has_method("has_buff"):
		return
	if bool(host.call("has_buff", InfectionDebuff.INFECTION_ID)):
		return
	var infection: BuffDef = make_buff(InfectionDebuff.INFECTION_ID)
	if infection != null:
		host.call("add_buff", infection, 1)


func on_process(host: Node, state: Dictionary, delta: float) -> void:
	var tick_accumulator: float = float(state.get("tick_accumulator", 0.0)) + delta
	var tick_seconds: float = _get_poison_tick_seconds()

	while tick_accumulator >= tick_seconds:
		tick_accumulator -= tick_seconds
		_deal_tick_damage(host, state)
		if host.has_method("notify_buff_ticked"):
			host.call("notify_buff_ticked", id)

	state["tick_accumulator"] = tick_accumulator


func _flash_host(host: Node) -> void:
	if host.has_method("flash_hit_mask"):
		host.call("flash_hit_mask", _get_flash_color())


func _deal_tick_damage(host: Node, state: Dictionary) -> void:
	var layers: int = clampi(int(state.get("stacks", 1)), 1, max_stacks)
	var damage: int = maxi(0, roundi(float(layers) * _get_poison_damage_per_layer()))
	if host.has_method("apply_damage_packet"):
		var packet: DamagePacket = DamagePacketScript.new(&"dot_poison", float(damage), &"poison")
		packet.is_dot = true
		packet.flash_color = _get_flash_color()
		if host is Node2D:
			packet.target = host as Node2D
		host.call("apply_damage_packet", packet)
	elif host.has_method("take_damage"):
		host.call("take_damage", damage, _get_flash_color())


func _get_flash_color() -> Color:
	var color: Variant = params.get("flash_color", POISON_COLOR)
	return color if color is Color else POISON_COLOR


func _get_poison_damage_per_layer() -> float:
	var stat_system: Node = _get_stat_system()
	if stat_system != null and stat_system.has_method("get_stat") \
			and (not stat_system.has_method("has_stat") or bool(stat_system.call("has_stat", STAT_POISON_DAMAGE_PER_LAYER))):
		return maxf(0.0, float(stat_system.call("get_stat", STAT_POISON_DAMAGE_PER_LAYER, STAT_ENTITY_MARBLE_CHAIN)))
	return float(params.get("damage_per_layer", DAMAGE_PER_LAYER))


func _get_poison_max_stacks() -> int:
	var stat_system: Node = _get_stat_system()
	if stat_system != null and stat_system.has_method("get_stat") \
			and (not stat_system.has_method("has_stat") or bool(stat_system.call("has_stat", STAT_POISON_MAX_STACKS))):
		return clampi(int(stat_system.call("get_stat", STAT_POISON_MAX_STACKS, STAT_ENTITY_MARBLE_CHAIN)), 1, MAX_POISON_STACKS)
	return BASE_POISON_CAP


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
