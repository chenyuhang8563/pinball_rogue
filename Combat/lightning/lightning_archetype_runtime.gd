extends RefCounted
class_name LightningArchetypeRuntime

const DamagePacketScript: GDScript = preload("res://Combat/damage/damage_packet.gd")
const LightningEffectScene: PackedScene = preload("res://Combat/effects/lightning_effect/lightning_effect.tscn")
const ARC_ID: String = "arc_debuff"
const STAT_ENTITY_MARBLE_CHAIN: String = "marble_chain"
const STAT_DISCHARGE_DAMAGE: String = "lightning_discharge_damage_per_stack"
const STAT_REPEAT_ARC_STACKS: String = "lightning_repeat_arc_stacks"
const BASE_ARC_CAP: int = 3
const MAX_SECONDARY_GENERATION: int = 4

var _effect_provider: Callable = Callable()
var _direct_discharge_count: int = 0
var _thunderstorm_triggered: bool = false
var _visuals_enabled: bool = true


func configure(effect_provider: Callable) -> void:
	_effect_provider = effect_provider
	reset_shot()


func reset_shot() -> void:
	_direct_discharge_count = 0
	_thunderstorm_triggered = false


func get_direct_discharge_count() -> int:
	return _direct_discharge_count


func has_triggered_thunderstorm() -> bool:
	return _thunderstorm_triggered


func set_visuals_enabled(enabled: bool) -> void:
	_visuals_enabled = enabled


## Resolves the complete ordered lightning transaction after the physical marble
## hit. Chain branches settle synchronously before thunderstorm target snapshot.
func on_enemy_hit_resolved(enemy: Node2D, packet: DamagePacket) -> void:
	if enemy == null or packet == null or not _is_alive(enemy):
		return
	if not bool(packet.metadata.get(LightningMarble.META_DIRECT_HIT, false)):
		return
	if packet.generation >= MAX_SECONDARY_GENERATION:
		return
	var stacks_before: int = maxi(0, int(packet.metadata.get(LightningMarble.META_ARC_STACKS_BEFORE, 0)))
	var origin_position: Vector2 = packet.metadata.get(
		LightningMarble.META_ORIGIN_POSITION, enemy.global_position
	) as Vector2
	var discharged: bool = stacks_before > 0
	var breakthrough: bool = discharged and _is_breakthrough(stacks_before)
	if discharged:
		_deal_discharge(enemy, stacks_before, breakthrough, packet)
	if _is_alive(enemy):
		if breakthrough:
			enemy.call("remove_buff", ARC_ID)
		var arc_gain: int = _repeat_arc_stacks() if discharged else 1
		_apply_arc(enemy, arc_gain, packet)
	if not discharged:
		return
	var chain: Variant = _effect(&"lightning")
	if chain != null:
		_trigger_chain(enemy, chain, packet)
	_direct_discharge_count += 1
	var thunderstorm: Variant = _effect(&"thunderstorm")
	if thunderstorm != null and not _thunderstorm_triggered \
			and _direct_discharge_count >= int(thunderstorm.call("get_threshold")):
		_thunderstorm_triggered = true
		_trigger_thunderstorm(thunderstorm, origin_position, packet)


## Death responses remain synchronous with the damage instance. Relay-created
## deaths are source-filtered so they cannot recursively clear the board.
func on_enemy_defeated(enemy: Node2D, packet: DamagePacket) -> void:
	if enemy == null or packet == null or packet.source == &"relic_arc_relay":
		return
	if packet.generation >= MAX_SECONDARY_GENERATION:
		return
	var stacks: int = _arc_stacks(enemy)
	if stacks <= 0:
		return
	var relay: Variant = _effect(&"arc_relay")
	if relay == null:
		return
	var candidates: Array[Node2D] = _ranked_candidates(
		enemy,
		enemy.global_position,
		float(relay.call("get_range")),
		false
	)
	var target_count: int = mini(int(relay.call("get_target_count")), candidates.size())
	var transfer_limit: int = int(relay.call("get_transfer_limit"))
	var transfer_stacks: int = stacks if transfer_limit < 0 else mini(stacks, transfer_limit)
	for index: int in range(target_count):
		var target: Node2D = candidates[index]
		var relay_packet: DamagePacket = _secondary_packet(
			&"relic_arc_relay", int(relay.call("get_damage")), packet, true
		)
		_apply_damage(target, relay_packet)
		if _is_alive(target):
			_apply_arc(target, transfer_stacks, relay_packet)
		_spawn_link(enemy.global_position, target.global_position, Color(0.52, 0.74, 1.0, 0.75))


func _deal_discharge(enemy: Node2D, stacks: int, breakthrough: bool, parent: DamagePacket) -> void:
	var damage: float = float(stacks * _discharge_damage_per_stack())
	var leyden: Variant = _effect(&"leyden_jar")
	if breakthrough and leyden != null:
		damage *= float(leyden.call("get_breakthrough_multiplier"))
	var discharge_packet: DamagePacket = _secondary_packet(
		&"lightning_discharge", roundi(damage), parent, false
	)
	_apply_damage(enemy, discharge_packet)


func _trigger_chain(source: Node2D, chain: Variant, parent: DamagePacket) -> void:
	var source_position: Vector2 = source.global_position
	var candidates: Array[Node2D] = _ranked_candidates(
		source,
		source_position,
		float(chain.call("get_branch_range")),
		false
	)
	var count: int = mini(int(chain.call("get_branch_count")), candidates.size())
	for index: int in range(count):
		var target: Node2D = candidates[index]
		var chain_packet: DamagePacket = _secondary_packet(
			&"relic_lightning", int(chain.call("get_branch_damage")), parent, true
		)
		_apply_damage(target, chain_packet)
		if _is_alive(target):
			_apply_arc(target, int(chain.call("get_arc_stacks")), chain_packet)
		_spawn_link(source_position, target.global_position, Color(0.68, 0.9, 1.0, 1.0))


func _trigger_thunderstorm(effect: Variant, origin: Vector2, parent: DamagePacket) -> void:
	var candidates: Array[Node2D] = _ranked_thunderstorm_candidates(origin)
	var count: int = mini(int(effect.call("get_target_count")), candidates.size())
	var targets: Array[Node2D] = []
	for index: int in range(count):
		targets.append(candidates[index])
	for target: Node2D in targets:
		if not _is_alive(target):
			continue
		var storm_packet: DamagePacket = _secondary_packet(
			&"relic_thunderstorm", int(effect.call("get_damage")), parent, true
		)
		_apply_damage(target, storm_packet)
	if not bool(effect.call("is_awakened")) or targets.is_empty():
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var timer := tree.create_timer(maxf(0.0, float(effect.call("get_second_round_delay"))))
	timer.timeout.connect(
		Callable(self, "_resolve_thunderstorm_second_round").bind(
			targets,
			int(effect.call("get_second_round_damage")),
			parent.generation
		),
		CONNECT_ONE_SHOT
	)


func _resolve_thunderstorm_second_round(targets: Array[Node2D], damage: int, parent_generation: int) -> void:
	for target: Node2D in targets:
		if not _is_alive(target):
			continue
		var packet: DamagePacket = DamagePacketScript.new(&"relic_thunderstorm", float(damage), &"lightning")
		packet.is_relic = true
		packet.generation = parent_generation + 1
		_apply_damage(target, packet)
		if _is_alive(target):
			_apply_arc(target, 1, packet)


func _apply_arc(enemy: Node2D, requested_stacks: int, packet: DamagePacket) -> void:
	if enemy == null or requested_stacks <= 0 or not _is_alive(enemy):
		return
	if not enemy.has_method("add_buff"):
		return
	var current: int = _arc_stacks(enemy)
	var room: int = maxi(0, _arc_cap() - current)
	var applied: int = mini(requested_stacks, room)
	if applied > 0:
		var arc: BuffDef = _make_arc_buff()
		if arc != null:
			enemy.call("add_buff", arc, applied, packet)
	elif current > 0 and enemy.has_method("refresh_buff"):
		enemy.call("refresh_buff", ARC_ID)


func _make_arc_buff() -> BuffDef:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return ArcDebuff.new()
	var registry: Node = tree.root.get_node_or_null("BuffRegistry")
	if registry != null and registry.has_method("get_buff_def"):
		var definition: BuffDef = registry.call("get_buff_def", ARC_ID) as BuffDef
		if definition != null:
			return definition
	return ArcDebuff.new()


func _arc_cap() -> int:
	var leyden: Variant = _effect(&"leyden_jar")
	return int(leyden.call("get_arc_cap")) if leyden != null else BASE_ARC_CAP


func _is_breakthrough(stacks_before: int) -> bool:
	var leyden: Variant = _effect(&"leyden_jar")
	return leyden != null and bool(leyden.call("is_awakened")) \
		and stacks_before >= int(leyden.call("get_arc_cap"))


func _repeat_arc_stacks() -> int:
	return maxi(1, roundi(_get_stat_float(STAT_REPEAT_ARC_STACKS, 1.0)))


func _discharge_damage_per_stack() -> int:
	return maxi(0, roundi(_get_stat_float(STAT_DISCHARGE_DAMAGE, 2.0)))


func _get_stat_float(stat_id: String, fallback: float) -> float:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return fallback
	var stats: Node = tree.root.get_node_or_null("StatSystem")
	if stats == null or not stats.has_method("get_stat"):
		return fallback
	if stats.has_method("has_stat") and not bool(stats.call("has_stat", stat_id)):
		return fallback
	return float(stats.call("get_stat", stat_id, STAT_ENTITY_MARBLE_CHAIN))


func _effect(effect_id: StringName) -> Variant:
	return _effect_provider.call(effect_id) if _effect_provider.is_valid() else null


func _arc_stacks(enemy: Node) -> int:
	if enemy != null and enemy.has_method("get_buff_stacks"):
		return maxi(0, int(enemy.call("get_buff_stacks", ARC_ID)))
	return 0


func _ranked_candidates(
	source: Node2D,
	origin: Vector2,
	radius: float,
	highest_stacks_first: bool
) -> Array[Node2D]:
	var result: Array[Node2D] = []
	if source == null or not source.is_inside_tree():
		return result
	for value: Node in source.get_tree().get_nodes_in_group("enemies"):
		if value == source or not value is Node2D:
			continue
		var enemy: Node2D = value as Node2D
		if not _is_alive(enemy) or origin.distance_to(enemy.global_position) > radius:
			continue
		result.append(enemy)
	result.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var a_stacks: int = _arc_stacks(a)
		var b_stacks: int = _arc_stacks(b)
		if a_stacks != b_stacks:
			return a_stacks > b_stacks if highest_stacks_first else a_stacks < b_stacks
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	return result


func _ranked_thunderstorm_candidates(origin: Vector2) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return result
	for value: Node in tree.get_nodes_in_group("enemies"):
		if not value is Node2D:
			continue
		var enemy: Node2D = value as Node2D
		if _is_alive(enemy) and _arc_stacks(enemy) > 0:
			result.append(enemy)
	result.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var a_stacks: int = _arc_stacks(a)
		var b_stacks: int = _arc_stacks(b)
		if a_stacks != b_stacks:
			return a_stacks > b_stacks
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	return result


func _secondary_packet(
	source: StringName,
	damage: int,
	parent: DamagePacket,
	is_relic: bool
) -> DamagePacket:
	var packet: DamagePacket = DamagePacketScript.new(source, float(maxi(0, damage)), &"lightning")
	packet.is_relic = is_relic
	packet.generation = parent.generation + 1
	packet.event_id = parent.event_id
	packet.is_event_main = false
	return packet


func _apply_damage(target: Node2D, packet: DamagePacket) -> void:
	if target == null or packet == null or not _is_alive(target):
		return
	packet.target = target
	if target.has_method("apply_damage_packet"):
		target.call("apply_damage_packet", packet)
	elif target.has_method("take_damage"):
		target.call("take_damage", roundi(packet.base))


func _is_alive(node: Node) -> bool:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return false
	return bool(node.call("is_alive")) if node.has_method("is_alive") else true


func _spawn_link(from_position: Vector2, to_position: Vector2, tint: Color) -> void:
	if not _visuals_enabled:
		return
	var direction: Vector2 = to_position - from_position
	if direction == Vector2.ZERO:
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var parent: Node = tree.current_scene if tree != null else null
	if parent == null:
		return
	# [DEBUG-arc] temporary instrumentation to capture every link's endpoints.
	print("[LNK-arc] from=%s to=%s midpoint=%s parent=%s" % [
		from_position, to_position, (from_position + to_position) * 0.5,
		parent.name if parent != null else "null"
	])
	var effect: AnimatedSprite2D = LightningEffectScene.instantiate() as AnimatedSprite2D
	if effect == null:
		return
	parent.add_child(effect)
	effect.global_position = (from_position + to_position) * 0.5
	effect.rotation = direction.angle()
	effect.modulate = tint
