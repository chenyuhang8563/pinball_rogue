extends BuffDef
class_name FireBurnDebuff

const DamagePacketScript: GDScript = preload("res://Combat/damage/damage_packet.gd")

const FIRE_COLOR: Color = Color(1.0, 0.2, 0.15, 1.0)
const BURN_ID: String = "fire_burn_debuff"
const STAT_ENTITY_MARBLE_CHAIN: String = "marble_chain"
const STAT_FIRE_BURN_DURATION: String = "fire_burn_duration"
const STAT_FIRE_BURN_DAMAGE_PER_LAYER: String = "fire_burn_damage_per_layer"
const STAT_FIRE_EMBER_SPREAD_ENABLED: String = "fire_ember_spread_enabled"
const MAX_BURN_LAYERS: int = 10


func _init() -> void:
	id = BURN_ID
	display_name = "Burn"
	description = "Deals fire damage per fuel layer once per second."
	duration = _get_burn_duration()
	stackable = true
	max_stacks = MAX_BURN_LAYERS
	source = BuffSource.CHAIN_MECHANIC
	reapply_policy = ReapplyPolicy.REFRESH


func on_apply(host: Node, state: Dictionary) -> void:
	# Reapplication changes the shared stack and refreshes the complete duration;
	# ticks remain elapsed-time based rather than a consumable pending-tick pool.
	state["tick_accumulator"] = 0.0
	state["hit_flash_color"] = FIRE_COLOR
	if host.has_method("set_fire_status_visual"):
		host.call("set_fire_status_visual")


func on_process(host: Node, state: Dictionary, delta: float) -> void:
	var tick_accumulator: float = float(state.get("tick_accumulator", 0.0)) + delta
	while tick_accumulator >= 1.0:
		tick_accumulator -= 1.0
		_deal_tick_damage(host, int(state.get("stacks", 1)))
	state["tick_accumulator"] = tick_accumulator


func on_remove(host: Node, _state: Dictionary) -> void:
	if host.has_method("clear_fire_status_visual"):
		host.call("clear_fire_status_visual")


func on_host_death(host: Node, state: Dictionary) -> void:
	var layers: int = clampi(int(state.get("stacks", 0)), 0, MAX_BURN_LAYERS)
	if layers <= 0 or not _is_ember_spread_enabled():
		return
	var target: Node2D = _find_nearest_alive_enemy(host)
	if target == null:
		return
	if target.has_method("add_buff"):
		var spread_burn: BuffDef = make_buff(BURN_ID)
		if spread_burn == null:
			return
		var spread_layers: int = maxi(1, ceili(float(layers) * 0.5))
		target.call("add_buff", spread_burn, spread_layers)


func _find_nearest_alive_enemy(host: Node) -> Node2D:
	if not host is Node2D:
		return null
	var origin: Node2D = host as Node2D
	var best: Node2D = null
	var best_distance_squared: float = INF
	for candidate: Node in origin.get_tree().get_nodes_in_group("enemies"):
		if candidate == host or not candidate is Node2D or not is_instance_valid(candidate):
			continue
		if candidate.has_method("is_alive") and not bool(candidate.call("is_alive")):
			continue
		var candidate_node: Node2D = candidate as Node2D
		var distance_squared: float = origin.global_position.distance_squared_to(candidate_node.global_position)
		if best == null or distance_squared < best_distance_squared or (is_equal_approx(distance_squared, best_distance_squared) and candidate.get_instance_id() < best.get_instance_id()):
			best = candidate_node
			best_distance_squared = distance_squared
	return best


## Deals one burn tick to the host. Fuel layers remain stable for the refreshed
## duration, and each layer contributes the configured per-layer damage.
func _deal_tick_damage(host: Node, layers: int) -> void:
	if layers <= 0:
		return
	var damage: int = maxi(0, roundi(float(layers) * _get_burn_damage_per_layer()))
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


func _get_burn_duration() -> float:
	var stat_system: Node = _get_stat_system()
	if stat_system != null and stat_system.has_method("get_stat"):
		return maxf(0.1, float(stat_system.call("get_stat", STAT_FIRE_BURN_DURATION, STAT_ENTITY_MARBLE_CHAIN)))
	return 3.0


func _get_burn_damage_per_layer() -> float:
	var stat_system: Node = _get_stat_system()
	if stat_system != null and stat_system.has_method("get_stat"):
		return maxf(0.0, float(stat_system.call("get_stat", STAT_FIRE_BURN_DAMAGE_PER_LAYER, STAT_ENTITY_MARBLE_CHAIN)))
	return 1.0


func _is_ember_spread_enabled() -> bool:
	if bool(params.get("ember_spread_enabled", false)):
		return true
	var stat_system: Node = _get_stat_system()
	return stat_system != null and stat_system.has_method("get_stat") and float(stat_system.call("get_stat", STAT_FIRE_EMBER_SPREAD_ENABLED, STAT_ENTITY_MARBLE_CHAIN)) > 0.0


func _get_stat_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("StatSystem") if tree != null else null
