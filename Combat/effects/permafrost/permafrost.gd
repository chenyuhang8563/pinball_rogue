extends RefCounted
class_name PermafrostEffect

## 永冻遗物：每次施加 Frozen 后按等级额外延长 1/2/3 秒。
## 觉醒时，冻结敌人每次有效碰撞再延长 2.5 秒；不改变敌人外观、大小或物理语义。

const FROZEN_DEBUFF_ID: String = "frozen_debuff"
const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/permafrost.tres")

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


func on_status_applied(
	enemy: Node2D, status_id: StringName, _stacks: int, _packet: DamagePacket = null
) -> void:
	if status_id != FROZEN_DEBUFF_ID or enemy == null or not is_instance_valid(enemy):
		return
	if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
		return
	if enemy.has_method("append_buff_duration"):
		enemy.call("append_buff_duration", FROZEN_DEBUFF_ID, float(_config.get_value(_level)))


func on_frozen_body_impact(
	enemy: Node2D, _hit_body: Node2D, _velocity: Vector2, _kind: StringName
) -> void:
	if not _awakened or enemy == null or not is_instance_valid(enemy):
		return
	if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
		return
	if enemy.has_method("append_buff_duration"):
		enemy.call(
			"append_buff_duration", FROZEN_DEBUFF_ID, float(_config.extra.get("awakened_impact_duration", 2.5))
		)
