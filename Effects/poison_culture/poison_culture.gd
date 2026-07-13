extends RefCounted
class_name PoisonCultureEffect

const PoisonDebuffScript: GDScript = preload("res://Buffs/buffs/poison_debuff.gd")
const MAX_LEVEL: int = 3
const REQUIRED_TICKS: int = 3
const TARGET_COUNTS: Array[int] = [1, 2, 3]

var _level: int = 1
var _awakened: bool = false
var _tick_counts: Dictionary = {}


func set_level(level: int) -> void:
	_level = clampi(level, 1, MAX_LEVEL)


func get_level() -> int:
	return _level


func set_awakened(awakened: bool) -> void:
	_awakened = awakened


func is_awakened() -> bool:
	return _awakened


func on_poison_tick(enemy: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	_prune_tick_counts()
	var enemy_id: int = enemy.get_instance_id()
	var entry: Dictionary = _tick_counts.get(enemy_id, {"enemy": weakref(enemy), "count": 0})
	entry["count"] = int(entry.get("count", 0)) + 1
	if int(entry["count"]) < REQUIRED_TICKS:
		_tick_counts[enemy_id] = entry
		return
	_tick_counts.erase(enemy_id)
	_spread_poison(enemy)


func _spread_poison(source: Node2D) -> void:
	var candidates: Array[Node2D] = []
	for candidate: Node in source.get_tree().get_nodes_in_group("enemies"):
		if candidate == source or not candidate is Node2D or not is_instance_valid(candidate):
			continue
		if candidate.has_method("is_alive") and not bool(candidate.call("is_alive")):
			continue
		if not _awakened and candidate.has_method("has_buff") and bool(candidate.call("has_buff", "poison_debuff")):
			continue
		candidates.append(candidate as Node2D)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var a_distance: float = source.global_position.distance_squared_to(a.global_position)
		var b_distance: float = source.global_position.distance_squared_to(b.global_position)
		if is_equal_approx(a_distance, b_distance):
			return a.get_instance_id() < b.get_instance_id()
		return a_distance < b_distance
	)
	for index: int in range(mini(TARGET_COUNTS[_level - 1], candidates.size())):
		var target: Node2D = candidates[index]
		if target.has_method("add_buff"):
			target.call("add_buff", PoisonDebuffScript.new())


func _prune_tick_counts() -> void:
	for enemy_id: int in _tick_counts.keys():
		var entry: Dictionary = _tick_counts[enemy_id]
		var enemy_ref: WeakRef = entry.get("enemy") as WeakRef
		if enemy_ref == null or enemy_ref.get_ref() == null:
			_tick_counts.erase(enemy_id)
