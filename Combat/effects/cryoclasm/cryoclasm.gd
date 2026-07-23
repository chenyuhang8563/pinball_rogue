extends RefCounted
class_name CryoclasmEffect

## 冰爆遗物：冻结敌人碰到弹珠、墙或另一敌人时碎裂——解除冻结、清空 Frost
## （觉醒保留固定层数）、目标仍存活且不扣血，沿运动方向扇区射出 N 枚冰碎片
## （N = 等级值 3/4/6）。扇区内敌人优先、扇区外补位，各碎片追踪一个互异目标；
## 目标不足则剩余碎片为无目标视觉飞行物（到期自毁）。
## 分工：本 Effect 不响应 on_enemy_hit_resolved（那是碎冰锤链路）。
## 与永冻共存：双方都据同一事件快照独立结算；冰爆不读实时冻结态，永冻仅延长
## 当前冻结持续时间，故无论分发先后都能正常碎裂。

const DamagePacketScript: GDScript = preload("res://Combat/damage/damage_packet.gd")
const IceShardScene: PackedScene = preload("res://Combat/effects/cryoclasm/cryoclasm_ice_shard.tscn")

const FROZEN_DEBUFF_ID: String = "frozen_debuff"
const FROST_DEBUFF_ID: String = "frost_debuff"
const DEFAULT_CONFIG: RelicLevelConfig = preload("res://Content/data/relic_configs/cryoclasm.tres")
## 每敌碎裂冷却（秒）：防止同帧多接触重复碎裂；在生成任何碎片之前写入。
const SHATTER_COOLDOWN_SECONDS: float = 0.25

var _config: RelicLevelConfig = DEFAULT_CONFIG
var _level: int = 1
var _awakened: bool = false
## 本遗物生成的存活碎片登记（instance_id），供 on_ball_lost 发末清理。
var _live_shards: Array[int] = []
## 碎裂冷却表：enemy instance_id -> 上次碎裂 usec。
var _shatter_cooldown: Dictionary = {}


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


## 冻结体碰撞事件。事件本身只由冻结体产生（Enemy 侧已保证），这里不再读实时 buff，
## 只校验：敌人有效存活、kind 合法（marble/enemy/world）、未在碎裂冷却。
func on_frozen_body_impact(enemy: Node2D, _hit_body: Node2D, velocity: Vector2, kind: StringName) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if kind != &"marble" and kind != &"enemy" and kind != &"world":
		return
	if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
		return
	var enemy_id: int = enemy.get_instance_id()
	var now_usec: int = Time.get_ticks_usec()
	if _shatter_cooldown.has(enemy_id) \
			and now_usec - int(_shatter_cooldown[enemy_id]) < int(SHATTER_COOLDOWN_SECONDS * 1000000.0):
		return
	# 先写入冷却，再生成任何碎片：防止同帧重复事件。
	_shatter_cooldown[enemy_id] = now_usec
	_shatter(enemy, velocity)


func _shatter(enemy: Node2D, velocity: Vector2) -> void:
	# 移除 Frozen 前先捕获碎裂点与运动方向，作为碎片生成点与扇区基准。
	var shatter_pos: Vector2 = enemy.global_position
	var base_dir: Vector2 = velocity.normalized()
	if base_dir.is_zero_approx():
		base_dir = Vector2.RIGHT

	# 碎裂：解除冻结 + 清空 Frost；
	# 目标仍存活、不扣其 HP。觉醒时保留固定层数 Frost。
	if enemy.has_method("remove_buff"):
		enemy.call("remove_buff", FROZEN_DEBUFF_ID)
		enemy.call("remove_buff", FROST_DEBUFF_ID)
	if _awakened and enemy.has_method("is_alive") and bool(enemy.call("is_alive")) \
			and enemy.has_method("add_buff"):
		var retain: int = int(_config.extra.get("awakened_retain_frost", 2))
		if retain > 0:
			var frost: BuffDef = _make_buff(FROST_DEBUFF_ID)
			if frost != null:
				enemy.call("add_buff", frost, retain)

	_spawn_shards(enemy, shatter_pos, base_dir)


func _spawn_shards(enemy: Node2D, shatter_pos: Vector2, base_dir: Vector2) -> void:
	var count: int = _config.get_value(_level)
	if count <= 0:
		return
	# 碎片挂到源敌人的父节点（同一战斗容器），绝不挂到源敌人自身或 /root。
	var parent: Node = enemy.get_parent()
	if parent == null:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		parent = tree.current_scene if tree != null else null
	if parent == null:
		return

	var targets: Array = _select_targets(enemy, base_dir, count)
	var half_angle: float = deg_to_rad(float(_config.extra.get("fan_half_angle_deg", 60.0)))
	var damage: int = _shard_damage()
	var speed: float = float(_config.extra.get("shard_speed", 260.0))
	var lifetime: float = float(_config.extra.get("shard_lifetime", 3.0))
	var turn_rate: float = float(_config.extra.get("shard_turn_rate", 8.0))
	var applies_frost: int = int(_config.extra.get("awakened_shard_frost", 1)) if _awakened else 0

	for i: int in range(count):
		var shard: CryoclasmIceShard = IceShardScene.instantiate() as CryoclasmIceShard
		if shard == null:
			continue
		# 所有 N 枚先获得扇区均匀初向；有目标者随后逐帧转向，无目标者沿初向直线飞行。
		var direction: Vector2 = base_dir.rotated(_fan_offset(i, count, half_angle))
		var target: Node2D = targets[i] if i < targets.size() else null
		_live_shards.append(shard.get_instance_id())
		# Enemy.body_entered 正在刷新物理查询时不能注册新刚体或改碰撞例外。
		# 目标、撞击点与发射参数在本帧快照，仅物理激活延后。
		call_deferred(
			"_activate_shard", parent, shard, shatter_pos, target, direction, damage, speed, lifetime,
			turn_rate, applies_frost, enemy
		)


func _activate_shard(
	parent: Node,
	shard: CryoclasmIceShard,
	spawn_position: Vector2,
	target: Node2D,
	direction: Vector2,
	damage: int,
	speed: float,
	lifetime: float,
	turn_rate: float,
	applies_frost: int,
	ignored_source: Node2D
) -> void:
	if parent == null or not is_instance_valid(parent) \
			or shard == null or not is_instance_valid(shard) or shard.is_queued_for_deletion():
		if shard != null and is_instance_valid(shard) and not shard.is_queued_for_deletion():
			shard.queue_free()
		return
	parent.add_child(shard)
	shard.activate_from_spawn(
		spawn_position, target, direction, damage, speed, lifetime, turn_rate, 1, applies_frost,
		ignored_source as PhysicsBody2D
	)
## 碎片伤害按等级从 extra.shard_damage（[3,4,6]）取值，clamp 到数组范围；兼容标量配置。
func _shard_damage() -> int:
	var values: Variant = _config.extra.get("shard_damage", [4])
	if values is Array:
		var arr: Array = values as Array
		if arr.is_empty():
			return 0
		return int(arr[clampi(_level - 1, 0, arr.size() - 1)])
	return int(values)


## 扇区均匀发射偏移：N 枚在 [-half_angle, +half_angle] 上均匀分布（N==1 时为 0）。
func _fan_offset(index: int, count: int, half_angle: float) -> float:
	if count <= 1:
		return 0.0
	var t: float = float(index) / float(count - 1)
	return -half_angle + 2.0 * half_angle * t


## 稳定三元键选择互异追踪目标：扇区内优先、距离平方升序、instance_id 升序；
## 扇区内不足时由扇区外补位。返回至多 max_count 个互异敌人。
func _select_targets(source: Node2D, base_dir: Vector2, max_count: int) -> Array:
	var cos_half: float = cos(deg_to_rad(float(_config.extra.get("fan_half_angle_deg", 60.0))))
	var in_sector: Array = []
	var out_sector: Array = []
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return []
	for candidate: Node in tree.get_nodes_in_group("enemies"):
		if not candidate is Node2D or not is_instance_valid(candidate) or candidate == source:
			continue
		if candidate.has_method("is_alive") and not bool(candidate.call("is_alive")):
			continue
		var to: Vector2 = (candidate as Node2D).global_position - source.global_position
		var dist_sq: float = to.length_squared()
		var entry: Dictionary = {
			"node": candidate,
			"dist_sq": dist_sq,
			"id": candidate.get_instance_id(),
		}
		if dist_sq > 0.0001 and base_dir.dot(to.normalized()) >= cos_half:
			in_sector.append(entry)
		else:
			out_sector.append(entry)
	var cmp := func(a: Dictionary, b: Dictionary) -> bool:
		if a["dist_sq"] != b["dist_sq"]:
			return float(a["dist_sq"]) < float(b["dist_sq"])
		return int(a["id"]) < int(b["id"])
	in_sector.sort_custom(cmp)
	out_sector.sort_custom(cmp)
	var result: Array = []
	for entry: Dictionary in in_sector:
		if result.size() >= max_count:
			break
		result.append(entry["node"])
	for entry: Dictionary in out_sector:
		if result.size() >= max_count:
			break
		result.append(entry["node"])
	return result


## 本发边界：清场本遗物生成的存活碎片（碎片自身也有寿命兜底）。
func on_ball_lost() -> void:
	var shards: Array[int] = _live_shards.duplicate()
	_live_shards.clear()
	for instance_id: int in shards:
		var shard: Object = instance_from_id(instance_id)
		if shard != null and is_instance_valid(shard):
			(shard as Node).queue_free()
	_prune_cooldowns()


func on_enemy_defeated(enemy: Node2D, _packet: DamagePacket = null) -> void:
	if enemy != null:
		_shatter_cooldown.erase(enemy.get_instance_id())


## 当前登记的存活碎片数（GUT 与 UI 可用）。
func get_live_shard_count() -> int:
	_prune_dead_shards()
	return _live_shards.size()


func _prune_dead_shards() -> void:
	var alive_ids: Array[int] = []
	for instance_id: int in _live_shards:
		var shard: Object = instance_from_id(instance_id)
		if shard != null and is_instance_valid(shard):
			alive_ids.append(instance_id)
	_live_shards = alive_ids


func _prune_cooldowns() -> void:
	var alive: Dictionary = {}
	for id: int in _shatter_cooldown.keys():
		var obj: Object = instance_from_id(id)
		if obj != null and is_instance_valid(obj):
			alive[id] = _shatter_cooldown[id]
	_shatter_cooldown = alive


func _make_buff(buff_id: String) -> BuffDef:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var registry: Node = tree.root.get_node_or_null("BuffRegistry")
	if registry == null or not registry.has_method("get_buff_def"):
		return null
	return registry.call("get_buff_def", buff_id) as BuffDef
