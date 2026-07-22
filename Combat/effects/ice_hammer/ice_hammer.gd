extends RefCounted
class_name IceHammerEffect

const DamagePacketScript: GDScript = preload("res://Combat/damage/damage_packet.gd")

const FROST_DEBUFF_ID: String = "frost_debuff"
const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/ice_hammer.tres")

var _config: RelicLevelConfig = DEFAULT_CONFIG
var _level: int = 1
var _awakened: bool = false


func set_config(config: RelicLevelConfig) -> void:
	_config = config


func set_level(level: int) -> void:
	_level = clampi(level, 1, _config.max_level)


func get_level() -> int:
	return _level


func set_awakened(awakened: bool) -> void:
	_awakened = awakened


func is_awakened() -> bool:
	return _awakened


func on_enemy_hit_resolved(enemy: Node2D, _was_burning: bool, was_frozen: bool, _packet: DamagePacket = null) -> void:
	if enemy == null or not was_frozen:
		return
	if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
		return
	# 永冻共存规则：目标是永冻冰球（ice_ball 标记）时照常执行局部 AOE，
	# 但不解除 Frozen——否则玩家无法把自己做出的冰球击推出去。
	# 普通冻结目标保持现有"命中即碎冰"行为。
	if not bool(enemy.get_meta(&"ice_ball", false)) and enemy.has_method("remove_buff"):
		enemy.call("remove_buff", "frozen_debuff")
	_shatter(enemy)


func _shatter(center_enemy: Node2D) -> void:
	var frost_stacks: int = int(_config.extra.get("awakened_frost_stacks", 3)) if _awakened else 1
	for candidate: Node in center_enemy.get_tree().get_nodes_in_group("enemies"):
		if not candidate is Node2D or not is_instance_valid(candidate):
			continue
		var target: Node2D = candidate as Node2D
		if target.global_position.distance_to(center_enemy.global_position) > float(_config.extra.get("radius", 100.0)):
			continue
		if target.has_method("is_alive") and not bool(target.call("is_alive")):
			continue
		if target.has_method("apply_damage_packet"):
			var packet: DamagePacket = DamagePacketScript.new(&"relic_ice", float(_config.get_value(_level)), &"frost")
			packet.is_relic = true
			packet.target = target
			target.call("apply_damage_packet", packet)
		elif target.has_method("take_damage"):
			target.call("take_damage", _config.get_value(_level))
		if target.has_method("is_alive") and not bool(target.call("is_alive")):
			continue
		if target.has_method("add_buff"):
			var frost: BuffDef = _make_buff(FROST_DEBUFF_ID)
			if frost != null:
				target.call("add_buff", frost, frost_stacks)


func _make_buff(buff_id: String) -> BuffDef:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var registry: Node = tree.root.get_node_or_null("BuffRegistry")
	if registry == null or not registry.has_method("get_buff_def"):
		return null
	return registry.call("get_buff_def", buff_id) as BuffDef
