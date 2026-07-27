extends RefCounted
class_name CremationEffect

const DamagePacketScript: GDScript = preload("res://Combat/damage/damage_packet.gd")
const FIRE_BURN_DEBUFF_ID: String = "fire_burn_debuff"
const FIRE_COLOR: Color = Color(1.0, 0.2, 0.15, 1.0)
const SHOCKWAVE_SCENE: PackedScene = preload("res://Combat/effects/cremation/cremation_shockwave.tscn")
const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/cremation.tres")

var _config: RelicLevelConfig = DEFAULT_CONFIG
var _level: int = 1
var _awakened: bool = false
## 防止同一帧内连锁引爆
var _detonating: bool = false


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


func on_enemy_hit_resolved(enemy: Node2D, _was_burning: bool, _was_frozen: bool, _packet: DamagePacket = null) -> void:
	if _detonating:
		return
	if enemy == null or not enemy.has_method("get_buff_stacks") or not enemy.has_method("consume_buff_stacks"):
		return
	if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
		return
	var fuel: int = int(enemy.call("get_buff_stacks", FIRE_BURN_DEBUFF_ID))
	var threshold: int = int(_config.extra.get("threshold", 6))
	if fuel < threshold:
		return
	_detonating = true
	# 消耗全部燃料
	enemy.call("consume_buff_stacks", FIRE_BURN_DEBUFF_ID, fuel)
	var radius: float = float(_config.extra.get("radius", 80.0))
	if _awakened:
		radius = float(_config.extra.get("awakened_radius", radius))
	_spawn_shockwave(enemy, radius)
	_deal_shockwave_damage(enemy, fuel, radius)
	_detonating = false


func _spawn_shockwave(center: Node2D, radius: float) -> void:
	var scene: Node = center.get_tree().current_scene
	if scene == null:
		return
	var wave: Node2D = SHOCKWAVE_SCENE.instantiate() as Node2D
	if wave == null:
		return
	wave.global_position = center.global_position
	if wave.has_method("setup"):
		wave.call("setup", radius)
	scene.add_child(wave)


func _deal_shockwave_damage(center: Node2D, fuel: int, radius: float) -> void:
	var per_layer: int = _config.get_value(_level)
	var total_damage: int = fuel * per_layer
	for candidate: Node in center.get_tree().get_nodes_in_group("enemies"):
		if not candidate is Node2D or not is_instance_valid(candidate):
			continue
		var target: Node2D = candidate as Node2D
		if target.global_position.distance_to(center.global_position) > radius:
			continue
		if target.has_method("is_alive") and not bool(target.call("is_alive")):
			continue
		if target.has_method("apply_damage_packet"):
			var packet: DamagePacket = DamagePacketScript.new(&"relic_cremation", float(total_damage), &"fire")
			packet.is_relic = true
			packet.flash_color = FIRE_COLOR
			packet.target = target
			target.call("apply_damage_packet", packet)
		elif target.has_method("take_damage"):
			target.call("take_damage", total_damage, FIRE_COLOR, &"cremation")
