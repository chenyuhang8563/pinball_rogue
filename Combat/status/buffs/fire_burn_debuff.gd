extends BuffDef
class_name FireBurnDebuff

const DamagePacketScript: GDScript = preload("res://Combat/damage/damage_packet.gd")

const FIRE_COLOR: Color = Color(1.0, 0.2, 0.15, 1.0)
const BURN_ID: String = "fire_burn_debuff"
const STAT_ENTITY_MARBLE_CHAIN: String = "marble_chain"
const STAT_FIRE_BURN_MAX_STACKS: String = "fire_burn_max_stacks"
const STAT_FIRE_BURN_DAMAGE_PER_LAYER: String = "fire_burn_damage_per_layer"
const STAT_FIRE_BURN_TICK_SECONDS: String = "fire_burn_tick_seconds"
## Hard ceiling for the stat-driven fuel cap (base 10, grows to 15 via upgrades).
const MAX_BURN_FUEL: int = 99


func _init() -> void:
	id = BURN_ID
	display_name = "STATUS_BURN_NAME"
	description = "STATUS_BURN_DESC"
	# Burn is a consumable fuel, not a timed debuff: it is permanent until its
	# fuel is spent and it removes itself.
	duration = -1.0
	stackable = true
	max_stacks = _get_fire_max_stacks()
	source = BuffSource.CHAIN_MECHANIC
	reapply_policy = ReapplyPolicy.REFRESH


func on_apply(host: Node, state: Dictionary) -> void:
	# Reapplication adds fuel (clamped to the cap by BuffHost) without delaying
	# the already-scheduled burn tick.
	if not state.has("tick_accumulator"):
		state["tick_accumulator"] = 0.0
	state["hit_flash_color"] = FIRE_COLOR
	if host.has_method("set_fire_status_visual"):
		host.call("set_fire_status_visual")


func on_process(host: Node, state: Dictionary, delta: float) -> void:
	var tick_accumulator: float = float(state.get("tick_accumulator", 0.0)) + delta
	var tick_seconds: float = _get_fire_burn_tick_seconds()
	while tick_accumulator >= tick_seconds:
		tick_accumulator -= tick_seconds
		var fuel: int = int(state.get("stacks", 1))
		if fuel <= 0:
			break
		# Settle damage from the pre-consumption fuel count, then consume one fuel.
		_deal_tick_damage(host, fuel)
		_consume_one_fuel(host, state, fuel)
		if int(state.get("stacks", 0)) <= 0:
			break
	state["tick_accumulator"] = tick_accumulator


func on_remove(host: Node, _state: Dictionary) -> void:
	if host.has_method("clear_fire_status_visual"):
		host.call("clear_fire_status_visual")


## Deals one burn tick scaled by the current fuel and the configured per-fuel
## damage.
func _deal_tick_damage(host: Node, fuel: int) -> void:
	if fuel <= 0:
		return
	var damage: int = maxi(0, roundi(float(fuel) * _get_burn_damage_per_layer()))
	if damage <= 0:
		return
	if host.has_method("apply_damage_packet"):
		var packet: DamagePacket = DamagePacketScript.new(&"dot_burn", float(damage), &"fire")
		packet.is_dot = true
		packet.flash_color = FIRE_COLOR
		packet.floating_style = &"burn"
		if host is Node2D:
			packet.target = host as Node2D
		host.call("apply_damage_packet", packet)
	elif host.has_method("take_damage"):
		host.call("take_damage", damage, FIRE_COLOR, &"burn")
	if host.has_method("notify_buff_ticked"):
		host.call("notify_buff_ticked", BURN_ID)


## Consumes one fuel. When the burn is hosted, BuffHost owns the stack count and
## removes the buff at zero fuel; otherwise (bare unit tests that drive
## on_process directly) decrement the local state.
func _consume_one_fuel(host: Node, state: Dictionary, fuel: int) -> void:
	if host.has_method("has_buff") and bool(host.call("has_buff", BURN_ID)) \
			and host.has_method("consume_buff_stacks"):
		host.call("consume_buff_stacks", BURN_ID, 1)
		return
	state["stacks"] = fuel - 1


func _get_fire_max_stacks() -> int:
	var stat_system: Node = _get_stat_system()
	if stat_system != null and stat_system.has_method("get_stat") \
			and (not stat_system.has_method("has_stat") or bool(stat_system.call("has_stat", STAT_FIRE_BURN_MAX_STACKS))):
		return clampi(int(stat_system.call("get_stat", STAT_FIRE_BURN_MAX_STACKS, STAT_ENTITY_MARBLE_CHAIN)), 1, MAX_BURN_FUEL)
	return 10


func _get_burn_damage_per_layer() -> float:
	var stat_system: Node = _get_stat_system()
	if stat_system != null and stat_system.has_method("get_stat"):
		return maxf(0.0, float(stat_system.call("get_stat", STAT_FIRE_BURN_DAMAGE_PER_LAYER, STAT_ENTITY_MARBLE_CHAIN)))
	return 1.0


func _get_fire_burn_tick_seconds() -> float:
	var stat_system: Node = _get_stat_system()
	if stat_system != null and stat_system.has_method("get_stat") \
			and (not stat_system.has_method("has_stat") or bool(stat_system.call("has_stat", STAT_FIRE_BURN_TICK_SECONDS))):
		return maxf(0.01, float(stat_system.call("get_stat", STAT_FIRE_BURN_TICK_SECONDS, STAT_ENTITY_MARBLE_CHAIN)))
	return 1.0


func _get_stat_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("StatSystem") if tree != null else null
