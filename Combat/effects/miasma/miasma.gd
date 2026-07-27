extends RefCounted
class_name MiasmaEffect

const DamagePacketScript: GDScript = preload("res://Combat/damage/damage_packet.gd")
const FIRE_BURN_DEBUFF_ID: String = "fire_burn_debuff"
const POISON_DEBUFF_ID: String = "poison_debuff"
const POISON_COLOR: Color = Color(0.2, 1.0, 0.2, 1.0)
const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/miasma.tres")

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


func on_status_applied(enemy: Node2D, status_id: StringName, _stacks: int, _packet: DamagePacket = null) -> void:
	var sid: String = String(status_id)
	if sid != FIRE_BURN_DEBUFF_ID and sid != POISON_DEBUFF_ID:
		return
	if enemy == null or not enemy.has_method("has_buff") or not enemy.has_method("remove_buff"):
		return
	if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
		return
	if not bool(enemy.call("has_buff", FIRE_BURN_DEBUFF_ID)):
		return
	if not bool(enemy.call("has_buff", POISON_DEBUFF_ID)):
		return
	_detonate(enemy)


func _detonate(center: Node2D) -> void:
	center.call("remove_buff", POISON_DEBUFF_ID)
	var damage: int = _config.get_value(_level)
	if _awakened:
		damage += int(_config.extra.get("awakened_bonus", 0))
	var radius: float = float(_config.extra.get("radius", 60.0))
	for candidate: Node in center.get_tree().get_nodes_in_group("enemies"):
		if not candidate is Node2D or not is_instance_valid(candidate):
			continue
		var target: Node2D = candidate as Node2D
		if target.global_position.distance_to(center.global_position) > radius:
			continue
		if target.has_method("is_alive") and not bool(target.call("is_alive")):
			continue
		if target.has_method("apply_damage_packet"):
			var packet: DamagePacket = DamagePacketScript.new(&"relic_miasma", float(damage), &"poison")
			packet.is_relic = true
			packet.flash_color = POISON_COLOR
			packet.target = target
			target.call("apply_damage_packet", packet)
		elif target.has_method("take_damage"):
			target.call("take_damage", damage, POISON_COLOR, &"miasma")
