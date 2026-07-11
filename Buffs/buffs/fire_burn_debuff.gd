extends BuffDef
class_name FireBurnDebuff

const FIRE_COLOR: Color = Color(1.0, 0.2, 0.15, 1.0)
const BURN_ID: String = "fire_burn_debuff"
const STAT_ENTITY_MARBLE_CHAIN: String = "marble_chain"
const STAT_FIRE_BURN_DURATION: String = "fire_burn_duration"
const STAT_FIRE_EMBER_SPREAD_ENABLED: String = "fire_ember_spread_enabled"
const MAX_PENDING_TICKS: int = 10


func _init() -> void:
	id = BURN_ID
	display_name = "Burn"
	description = "Deals decreasing fire damage once per second."
	duration = 3.0
	stackable = false
	max_stacks = 1
	source = BuffSource.CHAIN_MECHANIC
	reapply_policy = ReapplyPolicy.IGNORE


func on_apply(host: Node, state: Dictionary) -> void:
	var pending_ticks: int = clampi(int(params.get("pending_ticks", _get_burn_duration_ticks())), 1, MAX_PENDING_TICKS)
	state["pending_ticks"] = pending_ticks
	state["tick_accumulator"] = 0.0
	state["hit_flash_color"] = FIRE_COLOR
	if host.has_method("set_fire_status_visual"):
		host.call("set_fire_status_visual")


func on_process(host: Node, state: Dictionary, delta: float) -> void:
	var tick_accumulator: float = float(state.get("tick_accumulator", 0.0)) + delta
	var pending_ticks: int = int(state.get("pending_ticks", 0))
	while tick_accumulator >= 1.0 and pending_ticks > 0:
		tick_accumulator -= 1.0
		if host.has_method("take_damage"):
			host.call("take_damage", pending_ticks, FIRE_COLOR, &"burn")
		pending_ticks -= 1
	state["pending_ticks"] = pending_ticks
	state["tick_accumulator"] = tick_accumulator


func on_duration_appended(_host: Node, state: Dictionary, duration_to_append: float) -> void:
	var pending_ticks: int = int(state.get("pending_ticks", 0))
	state["pending_ticks"] = mini(MAX_PENDING_TICKS, pending_ticks + roundi(duration_to_append))


func on_remove(host: Node, _state: Dictionary) -> void:
	if host.has_method("clear_fire_status_visual"):
		host.call("clear_fire_status_visual")


func on_host_death(host: Node, state: Dictionary) -> void:
	var pending_ticks: int = int(state.get("pending_ticks", 0))
	if pending_ticks <= 0 or not _is_ember_spread_enabled():
		return
	var target: Node2D = _find_nearest_alive_enemy(host)
	if target == null:
		return
	if target.has_method("has_buff") and bool(target.call("has_buff", BURN_ID)):
		if target.has_method("append_buff_duration"):
			target.call("append_buff_duration", BURN_ID, float(pending_ticks), float(MAX_PENDING_TICKS))
		return
	if target.has_method("add_buff"):
		var spread_burn: BuffDef = get_script().new() as BuffDef
		spread_burn.params["pending_ticks"] = pending_ticks
		target.call("add_buff", spread_burn)


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


func _get_burn_duration_ticks() -> int:
	var stat_system: Node = _get_stat_system()
	if stat_system != null and stat_system.has_method("get_stat"):
		return clampi(roundi(float(stat_system.call("get_stat", STAT_FIRE_BURN_DURATION, STAT_ENTITY_MARBLE_CHAIN))), 1, MAX_PENDING_TICKS)
	return 3


func _is_ember_spread_enabled() -> bool:
	if bool(params.get("ember_spread_enabled", false)):
		return true
	var stat_system: Node = _get_stat_system()
	return stat_system != null and stat_system.has_method("get_stat") and float(stat_system.call("get_stat", STAT_FIRE_EMBER_SPREAD_ENABLED, STAT_ENTITY_MARBLE_CHAIN)) > 0.0


func _get_stat_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("StatSystem") if tree != null else null
