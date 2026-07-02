# MarbleChain —— 蛇形弹珠链管理器。
#
# 顶层架构：
#   MarbleChain (Node2D)
#     ├── Head (Marble / RigidBody2D)  ← 唯一参与物理模拟的节点
#     └── BodyContainer (Node2D)
#           ├── Segment0 (ChainSegment)
#           ├── Segment1 (ChainSegment)
#           └── ...
#
# 核心算法：路径历史轨迹跟随（Path History Trail）
#   Head 在 _physics_process 中以固定距离间隔记录 (position, rotation) 到环形缓冲区。
#   每个 Body 段查找其目标距离对应的轨迹点，用 lerp 平滑插值跟随。
#   碰撞反弹时旧轨迹点暂留在缓冲区，Body 段自然经过旧路径产生鞭尾效果。
#
# 伤害聚合：
#   敌人碰撞 Head → Head.get_hit_damage() → MarbleChain.get_total_damage() →
#   遍历 Head + 所有 Body 段累加伤害（BROWN 满层加伤，BOMB 不贡献接触伤害）。
#
# 炸弹 / 回声：
#   Head.body_entered 信号统一在此连接，按碰撞目标分发到对应 Body 段的逻辑。

extends Node2D
class_name MarbleChain


# ---- 导出调参 ----

## 轨迹点采样间距（像素）。值越小链越紧，越大越松散。
## 原值 10.0 在 head 来回移动时因轨迹弯曲导致段太近。改为 15.0 补偿弯曲。
@export var trail_point_spacing: float = 15.0

## Body 段跟随的 lerp 系数（0-1）。越大跟随越紧，越小越有弹性延迟感。
## 原值 0.2 导致段跟不上目标位置，链太紧凑。改为 0.35 平衡跟随速度和弹性感。
@export var body_follow_lerp: float = 0.35

## 轨迹缓冲区最大条目数（自动计算：chain_length * trail_point_spacing * 2）。
const TRAIL_MULTIPLIER: int = 3


# ---- 链成员 ----

## 头部弹珠——链中唯一的 RigidBody2D。
var head: Marble = null

## Body 段数组，从头到尾排列：body[0] = NECK（最接近 Head），body[-1] = TAIL（最远离 Head）。
var body: Array[ChainSegment] = []

## Body 段容器。
var _body_container: Node2D


# ---- 轨迹数据 ----

## 环形缓冲区：[{pos: Vector2, rot: float}, ...]，从前（最新）到后（最旧）。
var _trail: Array[Dictionary] = []

## 链总长（head + body 数量）。
var _chain_length: int = 1

## 爆炸特效预加载。
var _explosion_effect_scene: PackedScene = preload("res://Effects/explosion_effect/explosion_effect.tscn")

## ChainSegment 场景预加载。
var _segment_scene: PackedScene = preload("res://Marbles/chain_segment.tscn")


# ---- 链构建 ----

## 用一组 [MarbleSpec] 构建链。specs[0] 固定为 Head（DEFAULT），后续为 Body 段。
## spawn_positions 为每段提供独立的初始位置（下标越界时截断到最后一个）。
func build_chain(specs: Array, spawn_positions: Array[Vector2]) -> void:
	_clear_chain()

	if specs.is_empty() or spawn_positions.is_empty():
		return

	# 创建 Body 容器
	_body_container = Node2D.new()
	_body_container.name = "BodyContainer"
	add_child(_body_container)

	# Head
	var head_spec: MarbleSpec = specs[0] as MarbleSpec
	head = _create_head(head_spec, spawn_positions[0])
	add_child(head)

	# Body 段：按顺序分配位置，确保生成点连续
	# specs[0] (Head) → positions[0]
	# specs[1] (body[0]) → positions[1]
	# specs[2] (body[1]) → positions[2]
	var last_pos_idx: int = spawn_positions.size() - 1
	for i: int in range(1, specs.size()):
		var spec: MarbleSpec = specs[i] as MarbleSpec
		var pos_idx: int = mini(i, last_pos_idx)
		var segment: ChainSegment = _create_segment(spec, spawn_positions[pos_idx])
		body.append(segment)
		_body_container.add_child(segment)

	_chain_length = 1 + body.size()

	# 连接 Head 的碰撞信号
	_head_connect_signals()


## 销毁旧链内容。
func _clear_chain() -> void:
	_head_disconnect_signals()

	if head != null and is_instance_valid(head):
		head.queue_free()
	head = null

	for seg: ChainSegment in body:
		if seg != null and is_instance_valid(seg):
			seg.queue_free()
	body.clear()

	if _body_container != null and is_instance_valid(_body_container):
		_body_container.queue_free()
	_body_container = null

	_trail.clear()
	_chain_length = 1


## 创建 Head（唯一 RigidBody2D）。
func _create_head(spec: MarbleSpec, spawn_pos: Vector2) -> Marble:
	var instance: Node = spec.scene.instantiate()
	var marble: Marble = instance as Marble
	marble.global_position = spawn_pos
	marble.marble_type = Marble.MARBLE_TYPE.DEFAULT
	marble.is_head = true
	return marble


## 创建一段 Body（ChainSegment，纯视觉）。
func _create_segment(spec: MarbleSpec, spawn_pos: Vector2) -> ChainSegment:
	var segment: ChainSegment = _segment_scene.instantiate() as ChainSegment
	segment.segment_type = spec.marble_type
	segment.damage = spec.segment_damage
	segment.global_position = spawn_pos

	# 按弹珠类型换贴图（通过 get_node 而非 @onready sprite，避免节点未入树时的时序问题）
	var texture_path: String = _get_texture_for_type(spec.marble_type)
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		var sprite_node: Sprite2D = segment.get_node_or_null("Sprite2D")
		if sprite_node != null:
			sprite_node.texture = load(texture_path)

	return segment


func _get_texture_for_type(marble_type: Marble.MARBLE_TYPE) -> String:
	match marble_type:
		Marble.MARBLE_TYPE.BOMB:
			return "res://Assets/Marbles/bomb_marble.png"
		Marble.MARBLE_TYPE.BROWN:
			return "res://Assets/Marbles/brown_marble.png"
		_:
			return "res://Assets/Marbles/dark_marble.png"


# ---- Head 碰撞信号 ----

func _head_connect_signals() -> void:
	if head == null or not is_instance_valid(head):
		return
	if not head.body_entered.is_connected(_on_head_body_entered):
		head.body_entered.connect(_on_head_body_entered)


func _head_disconnect_signals() -> void:
	if head == null or not is_instance_valid(head):
		return
	if head.body_entered.is_connected(_on_head_body_entered):
		head.body_entered.disconnect(_on_head_body_entered)


func _on_head_body_entered(collided_body: Node) -> void:
	if collided_body == null:
		return

	if collided_body.is_in_group("enemies"):
		# 炸弹弹珠：碰敌即爆
		_try_trigger_bomb()
	else:
		# 棕色弹珠：碰非敌（墙/挡板等）叠回声
		_try_add_echo()


# ---- 炸弹逻辑 ----

## 若链中存在 BOMB 段，执行爆炸。
func _try_trigger_bomb() -> void:
	var bomb_segment: ChainSegment = _find_segment(Marble.MARBLE_TYPE.BOMB)
	if bomb_segment == null:
		return

	var explosion_center: Vector2 = head.global_position
	_damage_enemies_in_radius(explosion_center)
	_spawn_explosion_effect(explosion_center)


func _find_segment(marble_type: Marble.MARBLE_TYPE) -> ChainSegment:
	for seg: ChainSegment in body:
		if seg != null and is_instance_valid(seg) and seg.segment_type == marble_type:
			return seg
	return null


func _damage_enemies_in_radius(center: Vector2) -> void:
	const EXPLOSION_RADIUS: float = 100.0
	const EXPLOSION_DAMAGE: int = 5

	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy is Node2D:
			continue
		var enemy_node: Node2D = enemy as Node2D
		if enemy_node.global_position.distance_to(center) > EXPLOSION_RADIUS:
			continue
		if enemy_node.has_method("take_damage"):
			enemy_node.take_damage(EXPLOSION_DAMAGE)


func _spawn_explosion_effect(center: Vector2) -> void:
	var scene: Node = Engine.get_main_loop().current_scene
	if scene == null:
		return
	var effect: Node2D = _explosion_effect_scene.instantiate() as Node2D
	scene.add_child(effect)
	effect.global_position = center


# ---- 回声逻辑 ----

## 若链中存在 BROWN 段，为其叠加一层回声。
func _try_add_echo() -> void:
	var brown_segment: ChainSegment = _find_segment(Marble.MARBLE_TYPE.BROWN)
	if brown_segment == null:
		return
	brown_segment.add_echo_stack()


# ---- 伤害聚合 ----

## 敌人碰撞时调用此方法，聚合 Head 基础伤害 + 所有 Body 段贡献。
func get_total_damage(_target: Node) -> int:
	var total: int = 0

	if head != null and is_instance_valid(head):
		total += head.damage

	for seg: ChainSegment in body:
		if seg == null or not is_instance_valid(seg):
			continue
		total += seg.damage
		total += seg.get_echo_damage()

	return total


# ---- 轨迹 & 跟随 ----

func _physics_process(_delta: float) -> void:
	if head == null or not is_instance_valid(head):
		return
	_record_trail()
	_update_body_segments()


## 在 Head 当前位置记录轨迹点。仅当移动距离 ≥ 1px 时才写入。
## 使用较小的阈值（1px）确保轨迹点足够密集，所有段都能找到目标点。
func _record_trail() -> void:
	if _trail.is_empty():
		_trail.push_front({"pos": head.global_position, "rot": head.rotation})
		return

	var last: Dictionary = _trail[0]
	var dist: float = head.global_position.distance_to(last["pos"])
	if dist >= 1.0:  # 降低阈值，从 trail_point_spacing (10px) 改为 1px
		_trail.push_front({"pos": head.global_position, "rot": head.rotation})

	# 限制缓冲区大小
	var max_trail: int = _chain_length * int(trail_point_spacing) * TRAIL_MULTIPLIER
	while _trail.size() > max_trail:
		_trail.pop_back()


## 每个 Body 段根据其在链中的位置查找对应轨迹点并平滑跟随。
func _update_body_segments() -> void:
	for i: int in range(body.size()):
		var seg: ChainSegment = body[i]
		if seg == null or not is_instance_valid(seg):
			continue

		# segment index 0 is nearest to head → target_distance = trail_point_spacing
		# segment index N → target_distance = (N+1) * trail_point_spacing
		var target_dist: float = (i + 1) * trail_point_spacing
		var point: Dictionary = _get_trail_point_at_distance(target_dist)

		if point.is_empty():
			continue

		seg.global_position = seg.global_position.lerp(point["pos"], body_follow_lerp)
		seg.rotation = lerp_angle(seg.rotation, point["rot"], body_follow_lerp)


## 沿轨迹缓冲区查找距离为 target_distance 的点（从头开始累计距离）。
## 如果轨迹不够长，沿最后两个点的方向外推。
func _get_trail_point_at_distance(target_distance: float) -> Dictionary:
	if _trail.is_empty():
		return {}

	if _trail.size() < 2:
		return _trail[0]

	# 先尝试在轨迹内查找
	var accumulated: float = 0.0
	for i: int in range(_trail.size() - 1):
		var seg_len: float = _trail[i]["pos"].distance_to(_trail[i + 1]["pos"])
		if accumulated + seg_len >= target_distance:
			var t: float = (target_distance - accumulated) / seg_len if seg_len > 0.0 else 0.0
			return {
				"pos": _trail[i]["pos"].lerp(_trail[i + 1]["pos"], t),
				"rot": lerp_angle(_trail[i]["rot"], _trail[i + 1]["rot"], t),
			}
		accumulated += seg_len

	# 轨迹不够长，沿最后两个点的方向外推
	var last_point: Dictionary = _trail[-1]
	var second_last: Dictionary = _trail[-2]
	var direction: Vector2 = (last_point["pos"] - second_last["pos"]).normalized()
	if direction.length() < 0.001:
		# 如果方向为零，使用默认方向（向下）
		direction = Vector2(0, 1)

	var remaining_distance: float = target_distance - accumulated
	var extrapolated_pos: Vector2 = last_point["pos"] + direction * remaining_distance
	return {
		"pos": extrapolated_pos,
		"rot": last_point["rot"],
	}
