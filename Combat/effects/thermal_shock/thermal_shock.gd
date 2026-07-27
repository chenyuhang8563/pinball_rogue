extends RefCounted
class_name ThermalShockEffect

const DamagePacketScript: GDScript = preload("res://Combat/damage/damage_packet.gd")
const FIRE_BURN_DEBUFF_ID: String = "fire_burn_debuff"
const FROZEN_DEBUFF_ID: String = "frozen_debuff"
const FIRE_COLOR: Color = Color(1.0, 0.2, 0.15, 1.0)
const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/thermal_shock.tres")

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
	if sid != FIRE_BURN_DEBUFF_ID and sid != FROZEN_DEBUFF_ID:
		return
	if enemy == null or not enemy.has_method("has_buff") or not enemy.has_method("remove_buff"):
		return
	if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
		return
	if not bool(enemy.call("has_buff", FIRE_BURN_DEBUFF_ID)):
		return
	if not bool(enemy.call("has_buff", FROZEN_DEBUFF_ID)):
		return
	_shatter(enemy)


func _shatter(enemy: Node2D) -> void:
	enemy.call("remove_buff", FIRE_BURN_DEBUFF_ID)
	enemy.call("remove_buff", FROZEN_DEBUFF_ID)
	var damage: int = _config.get_value(_level)
	if _awakened:
		damage += int(_config.extra.get("awakened_bonus", 0))
	if enemy.has_method("apply_damage_packet"):
		var packet: DamagePacket = DamagePacketScript.new(&"relic_thermal_shock", float(damage), &"fire")
		packet.is_relic = true
		packet.flash_color = FIRE_COLOR
		packet.target = enemy
		enemy.call("apply_damage_packet", packet)
	elif enemy.has_method("take_damage"):
		enemy.call("take_damage", damage, FIRE_COLOR, &"thermal_shock")
