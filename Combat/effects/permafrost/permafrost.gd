extends RefCounted
class_name PermafrostEffect

## 永冻遗物：冻结敌人 → 更大、本发内不解冻、可推动的冰球障碍；冰球撞敌人造成
## 方向性碰撞伤害；同场上限（基础 2 / 觉醒 3）超出时淘汰最早一个；本发结束
## （on_ball_lost）全部还原。与冰爆分工：本 Effect 只读 was_ice_ball 快照造成伤害，
## 绝不移除 frozen（碎裂清场是冰爆的职责）。

const DamagePacketScript: GDScript = preload("res://Combat/damage/damage_packet.gd")

const FROZEN_DEBUFF_ID: String = "frozen_debuff"
const FROST_DEBUFF_ID: String = "frost_debuff"
const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/permafrost.tres")
## 同场冰球基础上限（觉醒加成见 extra.awakened_cap_bonus）。
const ICE_BALL_CAP: int = 2
## "本发内不解冻"的追加时长（秒），同时作为时长上限；远长于任何一发，
## 实际由 on_ball_lost 在本发结束时主动到期。
const FROZEN_EXTEND_DURATION: float = 3600.0

var _config: RelicLevelConfig = DEFAULT_CONFIG
var _level: int = 1
var _awakened: bool = false
## 冰球登记表：按转为冰球的先后顺序保存 instance_id，用于上限淘汰；
## 惰性清理失效对象 + on_enemy_defeated 显式剔除。
var _ice_balls: Array[int] = []


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


## 冻结敌人 → 冰球：放大、追加时长撑到本发末、登记；超上限淘汰最早一个
## （移除其 frozen_debuff，Enemy.end_frozen_physics 自动还原 scale/物理）。
func on_status_applied(
	enemy: Node2D, status_id: StringName, _stacks: int, _packet: DamagePacket = null
) -> void:
	if status_id != &"frozen_debuff":
		return
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
		return
	if enemy.has_method("set_ice_ball"):
		enemy.call("set_ice_ball", true, float(_config.extra.get("ice_ball_scale", 1.5)))
	if enemy.has_method("append_buff_duration"):
		enemy.call("append_buff_duration", FROZEN_DEBUFF_ID, FROZEN_EXTEND_DURATION, FROZEN_EXTEND_DURATION)
	var instance_id: int = enemy.get_instance_id()
	if not _ice_balls.has(instance_id):
		_ice_balls.append(instance_id)
	_enforce_cap()


## 冰球撞敌人 → 等级碰撞伤害（只依据 was_ice_ball/kind 快照，不读现场状态）。
## 觉醒时额外给被撞敌人施加 Frost（extra.awakened_frost_on_impact 层）。
func on_frozen_body_impact(
	enemy: Node2D, hit_body: Node2D, _velocity: Vector2, kind: StringName, was_ice_ball: bool
) -> void:
	if not was_ice_ball or kind != &"enemy":
		return
	if enemy == null or not _ice_balls.has(enemy.get_instance_id()):
		return
	if hit_body == null or not is_instance_valid(hit_body) or hit_body == enemy:
		return
	if hit_body.has_method("is_alive") and not bool(hit_body.call("is_alive")):
		return
	if hit_body.has_method("apply_damage_packet"):
		var packet: DamagePacket = DamagePacketScript.new(
			&"relic_permafrost_impact", float(_config.get_value(_level)), &"frost"
		)
		packet.is_relic = true
		packet.target = hit_body
		hit_body.call("apply_damage_packet", packet)
	if _awakened and hit_body.has_method("is_alive") and bool(hit_body.call("is_alive")) \
			and hit_body.has_method("add_buff"):
		var frost: BuffDef = _make_buff(FROST_DEBUFF_ID)
		if frost != null:
			hit_body.call("add_buff", frost, int(_config.extra.get("awakened_frost_on_impact", 1)))


## 本发边界：还原所有存活冰球（移除 frozen_debuff 触发 Enemy.end_frozen_physics
## 自动还原 scale/物理/标记），并清空登记表。
func on_ball_lost() -> void:
	var ice_balls: Array[int] = _ice_balls.duplicate()
	_ice_balls.clear()
	for instance_id: int in ice_balls:
		var ball: Object = instance_from_id(instance_id)
		if ball == null or not is_instance_valid(ball):
			continue
		if ball.has_method("is_alive") and not bool(ball.call("is_alive")):
			continue
		if ball.has_method("remove_buff"):
			ball.call("remove_buff", FROZEN_DEBUFF_ID)


func on_enemy_defeated(enemy: Node2D, _packet: DamagePacket = null) -> void:
	if enemy != null:
		_ice_balls.erase(enemy.get_instance_id())


## 当前登记的存活冰球数（GUT 与 UI 可用）。
func get_ice_ball_count() -> int:
	_prune_dead_ice_balls()
	return _ice_balls.size()


func _enforce_cap() -> void:
	_prune_dead_ice_balls()
	var cap: int = ICE_BALL_CAP + (int(_config.extra.get("awakened_cap_bonus", 1)) if _awakened else 0)
	while _ice_balls.size() > cap:
		var oldest_id: int = _ice_balls.pop_front()
		var oldest: Object = instance_from_id(oldest_id)
		if oldest == null or not is_instance_valid(oldest):
			continue
		if oldest.has_method("is_alive") and not bool(oldest.call("is_alive")):
			continue
		if oldest.has_method("remove_buff"):
			oldest.call("remove_buff", FROZEN_DEBUFF_ID)


func _prune_dead_ice_balls() -> void:
	var alive_ids: Array[int] = []
	for instance_id: int in _ice_balls:
		var ball: Object = instance_from_id(instance_id)
		if ball != null and is_instance_valid(ball):
			alive_ids.append(instance_id)
	_ice_balls = alive_ids


func _make_buff(buff_id: String) -> BuffDef:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var registry: Node = tree.root.get_node_or_null("BuffRegistry")
	if registry == null or not registry.has_method("get_buff_def"):
		return null
	return registry.call("get_buff_def", buff_id) as BuffDef
