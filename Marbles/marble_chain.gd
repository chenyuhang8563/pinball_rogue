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

const StatContextScript: GDScript = preload("res://Stats/stat_context.gd")

# ---- 导出调参 ----

## 轨迹点采样间距（像素）。和 Main 的出生点间距保持一致，避免开局收缩。
@export var trail_point_spacing: float = 24.0

## Head 移动多少像素记录一次轨迹点。采样要比链段间距密，避免 Body 目标点跳变。
@export var trail_sample_spacing: float = 2.0

## Body 段跟随的 lerp 系数（0-1）。越大跟随越紧，越小越有弹性延迟感。
@export var body_follow_lerp: float = 0.3

## 轨迹缓冲区最大条目数（自动计算：chain_length * trail_point_spacing * 2）。
const TRAIL_MULTIPLIER: int = 3


# ---- 链成员 ----

## 头部弹珠——链中唯一的 RigidBody2D。
var head: Marble = null

## Body 段数组，从尾到头排列：body[0] = TAIL, body[-1] = NECK。
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

## Head 弹珠场景。Head 固定为基础 dark marble。
var _head_scene: PackedScene = preload("res://Marbles/marble.tscn")

## ChainSegment 场景预加载。
var _segment_scene: PackedScene = preload("res://Marbles/chain_segment.tscn")


# ---- 链构建 ----

## 用一组弹珠 Item 构建链。items[0] 固定为 Head（DEFAULT），后续为 Body 段。
## items 顺序对应 spawn_positions 顺序，调用方负责把槽位顺序映射到出生点。
func build_chain(items: Array[Item], spawn_positions: Array[Vector2]) -> void:
	_clear_chain()

	if items.is_empty() or spawn_positions.is_empty():
		return

	# 创建 Body 容器
	_body_container = Node2D.new()
	_body_container.name = "BodyContainer"
	add_child(_body_container)

	# Head
	head = _create_head(_get_spawn_position(spawn_positions, 0))
	add_child(head)

	# Body 段
	for i: int in range(1, items.size()):
		var item: Item = items[i]
		var segment: ChainSegment = _create_segment(item, _get_spawn_position(spawn_positions, i))
		body.append(segment)
		_body_container.add_child(segment)

	_chain_length = 1 + body.size()
	_prime_trail_from_spawn_positions(spawn_positions)

	# 连接 Head 的碰撞信号
	_head_connect_signals()


func _get_spawn_position(spawn_positions: Array[Vector2], index: int) -> Vector2:
	var pos_idx: int = mini(index, spawn_positions.size() - 1)
	return spawn_positions[pos_idx]


func _prime_trail_from_spawn_positions(spawn_positions: Array[Vector2]) -> void:
	_trail.clear()
	for i: int in range(_chain_length):
		_trail.append({
			"pos": _get_spawn_position(spawn_positions, i),
			"rot": 0.0,
		})


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
func _create_head(spawn_pos: Vector2) -> Marble:
	var instance: Node = _head_scene.instantiate()
	var marble: Marble = instance as Marble
	marble.global_position = spawn_pos
	marble.marble_type = Marble.MARBLE_TYPE.DEFAULT
	marble.is_head = true
	return marble


## 创建一段 Body（ChainSegment，纯视觉）。
func _create_segment(item: Item, spawn_pos: Vector2) -> ChainSegment:
	var segment: ChainSegment = _segment_scene.instantiate() as ChainSegment
	segment.segment_type = item.marble_type
	segment.damage = item.marble_segment_damage
	segment.global_position = spawn_pos

	var sprite_node: Sprite2D = segment.get_node_or_null("Sprite2D")
	if sprite_node != null and item.icon != null:
		sprite_node.texture = item.icon

	return segment


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

	_emit_chain_collision(collided_body)

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
	var explosion_radius: float = _get_stat_float("explosion_radius", 100.0)
	var explosion_damage: int = roundi(_get_stat_float("explosion_damage", 5.0))

	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy is Node2D:
			continue
		var enemy_node: Node2D = enemy as Node2D
		if enemy_node.global_position.distance_to(center) > explosion_radius:
			continue
		if enemy_node.has_method("take_damage"):
			enemy_node.take_damage(explosion_damage)


func _spawn_explosion_effect(center: Vector2) -> void:
	var scene: Node = Engine.get_main_loop().current_scene
	if scene == null:
		return
	var effect: Node2D = _explosion_effect_scene.instantiate() as Node2D
	scene.add_child(effect)
	effect.global_position = center
	var effect_scale: float = _get_stat_float("explosion_effect_scale", 1.0)
	effect.scale = Vector2(effect_scale, effect_scale)


# ---- 回声逻辑 ----

## 若链中存在 BROWN 段，为其叠加一层回声。
func _try_add_echo() -> void:
	var brown_segment: ChainSegment = _find_segment(Marble.MARBLE_TYPE.BROWN)
	if brown_segment == null:
		return
	brown_segment.add_echo_stack()


# ---- 伤害聚合 ----

## 敌人碰撞时调用此方法，聚合 Head 基础伤害 + 所有 Body 段贡献。
func get_total_damage(target: Node) -> int:
	var total: int = 0

	if head != null and is_instance_valid(head):
		total += roundi(_get_stat_float("dark_marble_damage", float(head.damage)))

	for seg: ChainSegment in body:
		if seg == null or not is_instance_valid(seg):
			continue
		if seg.segment_type == Marble.MARBLE_TYPE.GREEN:
			GreenMarble.apply_poison_to_enemy(target)
		elif seg.segment_type == Marble.MARBLE_TYPE.BLUE:
			BlueMarble.apply_frost_to_enemy(target)
		total += seg.damage
		total += seg.get_echo_damage()

	var stat_system: Node = _get_autoload_node(&"StatSystem")
	if stat_system == null or not stat_system.has_method("get_stat"):
		return total

	var context: RefCounted = StatContextScript.new(
		"marble_chain",
		target.name if target != null else "",
		"marble_hit",
		{"base_damage": total}
	)
	return int(stat_system.call("get_stat", "final_damage", "marble_chain", context))


func _get_autoload_node(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))


func _get_stat_float(stat_id: String, fallback: float) -> float:
	var stat_system: Node = _get_autoload_node(&"StatSystem")
	if stat_system == null or not stat_system.has_method("get_stat"):
		return fallback
	return float(stat_system.call("get_stat", stat_id, "marble_chain"))


func _emit_chain_collision(collided_body: Node) -> void:
	var event_bus: Node = get_node_or_null("/root/Event")
	if event_bus == null or not event_bus.has_signal(&"chain_collision"):
		return

	var collision_type: String = "wall"
	if collided_body.is_in_group("enemies"):
		collision_type = "enemy"
	elif collided_body.is_in_group("flipper"):
		collision_type = "flipper"

	event_bus.emit_signal(&"chain_collision", collided_body, collision_type)


# ---- 轨迹 & 跟随 ----

func _physics_process(_delta: float) -> void:
	if head == null or not is_instance_valid(head):
		return
	_record_trail()
	_update_body_segments()


## 在 Head 当前位置记录轨迹点。采样密度和链段间距分离，避免视觉段一格一格跳。
func _record_trail() -> void:
	if _trail.is_empty():
		_trail.push_front({"pos": head.global_position, "rot": head.rotation})
		return

	var last: Dictionary = _trail[0]
	var dist: float = head.global_position.distance_to(last["pos"])
	if dist >= trail_sample_spacing:
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
func _get_trail_point_at_distance(target_distance: float) -> Dictionary:
	if _trail.size() < 2:
		return _trail[0] if not _trail.is_empty() else {}

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

	# 轨迹不够长，返回最远的点
	return _trail[-1]
