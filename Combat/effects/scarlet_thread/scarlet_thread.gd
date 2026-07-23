extends RefCounted
class_name ScarletThreadEffect

const DamagePacketScript: GDScript = preload("res://Combat/damage/damage_packet.gd")
const ScarletThreadScene: PackedScene = preload("res://Combat/effects/scarlet_thread/scarlet_thread_effect.tscn")
const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/scarlet_thread.tres")

var _config: RelicLevelConfig = DEFAULT_CONFIG
var _level: int = 1
var _awakened: bool = false


func set_level(level: int) -> void:
	_level = clampi(level, 1, _config.max_level)


func get_level() -> int:
	return _level


func set_awakened(awakened: bool) -> void:
	_awakened = awakened


func is_awakened() -> bool:
	return _awakened


func on_damage_dealt(enemy: Node2D, packet: DamagePacket) -> void:
	if enemy == null or packet == null or not packet.is_crit or packet.generation != 0 or packet.base <= 0.0:
		return
	var targets: Array[Node2D] = _nearest_targets(enemy, 2 if _awakened else 1)
	var primary_percentage: float = float(_config.get_value(_level)) / 100.0
	var awakened_secondary_percentage: float = float(_config.extra.get("awakened_secondary_percentage", 150)) / 100.0
	for index: int in targets.size():
		var target: Node2D = targets[index]
		var percentage: float = awakened_secondary_percentage if _awakened and index == 1 else primary_percentage
		var secondary: DamagePacket = DamagePacketScript.new(&"relic_scarlet_thread", packet.base * percentage, &"physical")
		secondary.is_relic = true
		secondary.generation = packet.generation + 1
		secondary.target = target
		target.call("apply_damage_packet", secondary)
		_spawn_effect(enemy.global_position, target.global_position)


func _nearest_targets(origin: Node2D, count: int) -> Array[Node2D]:
	var candidates: Array[Node2D] = []
	for node: Node in origin.get_tree().get_nodes_in_group("enemies"):
		if node == origin or not is_instance_valid(node) or node is not Node2D:
			continue
		var candidate: Node2D = node as Node2D
		if candidate.has_method("is_alive") and not bool(candidate.call("is_alive")):
			continue
		candidates.append(candidate)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool: return origin.global_position.distance_squared_to(a.global_position) < origin.global_position.distance_squared_to(b.global_position))
	return candidates.slice(0, mini(count, candidates.size()))


func _spawn_effect(from_position: Vector2, to_position: Vector2) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var effect: Node2D = ScarletThreadScene.instantiate() as Node2D
	if effect == null:
		return
	tree.current_scene.add_child(effect)
	if effect.has_method("configure"):
		effect.call("configure", from_position, to_position)
