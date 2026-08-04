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
#   遍历 Head + 所有 Body 段累加伤害（BOMB 不贡献接触伤害）。
#
# 回响弹珠（新机制）：
#   链不再拥有蓄力条。敌人碰撞产生的共享蓄力由 TableBase 上的
#   EchoFlipperChargeController 持有；挡板消费蓄力后通过 arm_echo_damage()
#   武装本链的待结算回响伤害 token，下一次敌人命中消费一个 token。
#
# 炸弹弹药（新机制）：
#   爆炸由 ExplosionContext 事务驱动：碰敌时若链含 BOMB 且弹药 > 0 则
#   modify_explosion → finalize → 扣弹 → 伤害 → VFX → on_explosion_resolved。
#   弹药 0 时不爆炸，普通碰撞补 1 点伤害（_dry_bomb_contact_damage）。

extends Node2D
class_name MarbleChain

signal chain_collision(collider: Node, collision_type: String)

const FireMarbleScript: GDScript = preload("res://Combat/marbles/fire_marble.gd")
const LightningMarbleScript: GDScript = preload("res://Combat/marbles/lightning_marble.gd")
const DamagePacketScript: GDScript = preload("res://Combat/damage/damage_packet.gd")
const ExplosionContextScript: GDScript = preload("res://Combat/explosion/explosion_context.gd")
const RadialDamageScript: GDScript = preload("res://Combat/explosion/radial_damage.gd")

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
@export var head: Marble = null

## Body 段数组，从尾到头排列：body[0] = TAIL, body[-1] = NECK。
var body: Array[ChainSegment] = []

## Body 段容器。
var _body_container: Node2D
var _registry: MarbleChainRegistry = null
## 待结算回响伤害 token：由 EchoFlipperChargeController 在挡板消费蓄力后武装，
## 敌人命中时逐个消费（墙面/挡板碰撞不消费）。
var _echo_pending_tokens: int = 0
## 待结算 token 的每 token 追加伤害（锻锤按本发反弹计数武装；最后一批 token 消费完清零）。
var _echo_token_bonus: int = 0

## 弹药状态（Main 注入）。null 时按旧行为：爆炸不扣弹、无 0 弹药检查。
var _ammo_state: AmmoState = null


# ---- 轨迹数据 ----

## 环形缓冲区：[{pos: Vector2, rot: float}, ...]，从前（最新）到后（最旧）。
var _trail: Array[Dictionary] = []

## 链总长（head + body 数量）。
var _chain_length: int = 1

## 爆炸特效预加载。
var _explosion_effect_scene: PackedScene = preload("res://Combat/effects/explosion_effect/explosion_effect.tscn")

## Head 弹珠场景。Head 固定为基础 dark marble。
var _head_scene: PackedScene = preload("res://Combat/marbles/marble.tscn")

## ChainSegment 场景预加载。
var _segment_scene: PackedScene = preload("res://Combat/marbles/chain_segment.tscn")


func _ready() -> void:
	# 支持纯场景搭建：head 通过 @export 在编辑器中绑定（未调用 build_chain()）时，
	# 在这里完成 Head 接管，让场景里连好的弹珠链开箱即用。
	if head == null or not is_instance_valid(head):
		return
	head.is_head = true
	_prime_trail_from_spawn_positions([head.global_position])
	_head_connect_signals()
	_register_with_registry()
	_bind_echo_charge_controller()


func _exit_tree() -> void:
	remove_from_group(&"marble_chain")
	_unregister_from_registry()
	_head_disconnect_signals()
	exit_pierce_state()


func set_chain_registry(registry: MarbleChainRegistry) -> void:
	_unregister_from_registry()
	_registry = registry
	_register_with_registry()


## 接管关卡中预放置的 Head，并使其成为该链唯一的物理头部。
func adopt_scene_head(scene_head: Marble) -> bool:
	if scene_head == null or not is_instance_valid(scene_head):
		return false
	_unregister_from_registry()
	_head_disconnect_signals()
	if head != null and head != scene_head and is_instance_valid(head):
		head.queue_free()
	head = scene_head
	if head.get_parent() == null:
		add_child(head)
	elif head.get_parent() != self:
		head.reparent(self, true)
	head.is_head = true
	_chain_length = 1
	for segment: ChainSegment in body:
		if segment != null and is_instance_valid(segment):
			segment.queue_free()
	body.clear()
	if _body_container != null and is_instance_valid(_body_container):
		_body_container.queue_free()
	_body_container = null
	_prime_trail_from_spawn_positions([head.global_position])
	_head_connect_signals()
	_register_with_registry()
	_bind_echo_charge_controller()
	return true


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
	head = _create_head(items[0], _get_spawn_position(spawn_positions, 0))
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
	_register_with_registry()
	_bind_echo_charge_controller()


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
	_unregister_from_registry()
	_head_disconnect_signals()
	# 清理穿透态：避免传感器悬挂（Head 随后销毁，掩码恢复无副作用）。
	exit_pierce_state()

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
func _create_head(item: Item, spawn_pos: Vector2) -> Marble:
	var instance: Node = _head_scene.instantiate()
	var marble: Marble = instance as Marble
	marble.global_position = spawn_pos
	marble.marble_type = item.marble_type
	marble.damage = item.marble_segment_damage
	var sprite_node: Sprite2D = marble.get_node_or_null("Sprite2D") as Sprite2D
	if sprite_node != null and item.icon != null:
		sprite_node.texture = item.icon
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
		# 新回响机制：敌人碰撞充能由 EchoFlipperChargeController 经
		# chain_collision 信号处理；非敌碰撞不再叠加回声。
		var effect_manager: Node = _get_autoload_node(&"EffectManager")
		if effect_manager != null and effect_manager.has_method("on_surface_bounce"):
			var surface_type: StringName = &"flipper" if collided_body.is_in_group("flipper") else &"wall"
			effect_manager.call("on_surface_bounce", surface_type, {})


# ---- 炸弹逻辑 ----

## 链中是否存在 BOMB 弹珠（HUD 弹药行显隐等使用）。
func has_bomb_marble() -> bool:
	return _contains_marble_type(Marble.MARBLE_TYPE.BOMB)


func set_ammo_state(ammo: AmmoState) -> void:
	_ammo_state = ammo


func _get_ammo_state() -> AmmoState:
	if _ammo_state != null and is_instance_valid(_ammo_state):
		return _ammo_state
	return null


## 若链中存在 BOMB 段且弹药 > 0，构建主爆炸上下文并执行。
## 弹药 0 时不爆炸（普通碰撞 1 伤由 get_total_damage 补）。
func _try_trigger_bomb() -> bool:
	if not _contains_marble_type(Marble.MARBLE_TYPE.BOMB):
		return false
	var ammo_state := _get_ammo_state()
	if ammo_state != null and ammo_state.get_ammo() <= 0:
		return false

	var context: ExplosionContext = ExplosionContextScript.new() as ExplosionContext
	context.center = head.global_position
	context.base_damage = roundi(_get_stat_float("explosion_damage", 4.0))
	context.base_radius = _get_stat_float("explosion_radius", 75.0)
	context.ammo_before = ammo_state.get_ammo() if ammo_state != null else 0
	return _execute_explosion(context)


## 爆炸事务流水线：modify_explosion → finalize → 扣弹 → 伤害 → VFX → resolved。
## 扣弹失败（弹药不足）返回 false，爆炸不生效。
func _execute_explosion(context: ExplosionContext) -> bool:
	var effect_manager: Node = _get_autoload_node(&"EffectManager")
	if effect_manager != null and effect_manager.has_method("modify_explosion"):
		effect_manager.call("modify_explosion", context)
	var resolved: Dictionary = context.finalize()
	var ammo_state := _get_ammo_state()
	if ammo_state != null and not ammo_state.consume(int(resolved["ammo_cost"])):
		return false
	_damage_enemies_in_radius(context, resolved)
	_spawn_explosion_effect(context, resolved)
	if effect_manager != null and effect_manager.has_method("on_explosion_resolved"):
		effect_manager.call("on_explosion_resolved", context)
	return true


func _find_segment(marble_type: Marble.MARBLE_TYPE) -> ChainSegment:
	for seg: ChainSegment in body:
		if seg != null and is_instance_valid(seg) and seg.segment_type == marble_type:
			return seg
	return null


func _contains_marble_type(marble_type: Marble.MARBLE_TYPE) -> bool:
	if head != null and is_instance_valid(head) and head.marble_type == marble_type:
		return true
	return _find_segment(marble_type) != null


## 范围扫描与伤害。resolved 为 finalize 后的最终参数（含遗物改写）。
## VFX 分发（EffectManager.on_explosion）保留在本链，目标收集/造伤事件语义
## 委托给共享工具 RadialDamage（小炸弹复用，保证 event_id/过滤不变量一致）。
func _damage_enemies_in_radius(context: ExplosionContext, resolved: Dictionary) -> void:
	var explosion_radius: float = float(resolved["radius"])
	var explosion_damage: int = int(resolved["damage"])
	var effect_manager: Node = _get_autoload_node(&"EffectManager")
	if effect_manager != null and effect_manager.has_method("on_explosion"):
		effect_manager.call("on_explosion", context.center, explosion_radius)
	RadialDamageScript.damage_enemies_in_radius(
		context.center,
		explosion_radius,
		explosion_damage,
		false,
		true,
	)


## 特效缩放 = effect_scale stat × 实际半径/基础半径：觉醒 ×4 保持，
## 背水/弹药倾泻的半径放大同步放大视觉。
func _spawn_explosion_effect(context: ExplosionContext, resolved: Dictionary) -> void:
	var scene: Node = Engine.get_main_loop().current_scene
	if scene == null:
		return
	var effect: Node2D = _explosion_effect_scene.instantiate() as Node2D
	scene.add_child(effect)
	effect.global_position = context.center
	var effect_scale: float = _get_stat_float("explosion_effect_scale", 1.0)
	if context.base_radius > 0.0:
		effect_scale *= float(resolved["radius"]) / context.base_radius
	effect.scale = Vector2(effect_scale, effect_scale)


# ---- 回响伤害 token ----

## 由 EchoFlipperChargeController 调用：挡板每消费一层蓄力即武装一个待结算
## 回响伤害 token。token 随本链生命周期存在（掉球重建链后清零），蓄力保留在控制器。
## per_token_bonus 为锻锤武装的每 token 追加伤害（发射时按本发反弹计数结算）。
func arm_echo_damage(tokens: int = 1, per_token_bonus: int = 0) -> void:
	var added: int = maxi(0, tokens)
	_echo_pending_tokens = maxi(0, _echo_pending_tokens + added)
	if added > 0:
		_echo_token_bonus = maxi(0, per_token_bonus)


## 当前待结算回响伤害 token 数（测试与调试用）。
func get_echo_pending_tokens() -> int:
	return _echo_pending_tokens


## 链（Head 或任一 Body 段）中是否存在 BROWN 大地弹珠。
## EchoFlipperChargeController 据此决定回响蓄力机制是否激活。
func has_brown_marble() -> bool:
	if head != null and is_instance_valid(head) and head.marble_type == Marble.MARBLE_TYPE.BROWN:
		return true
	for seg: ChainSegment in body:
		if seg != null and is_instance_valid(seg) and seg.segment_type == Marble.MARBLE_TYPE.BROWN:
			return true
	return false


## 敌人碰撞结算时消费一个 token 并返回回响加成伤害；墙面/挡板等非敌碰撞不消费。
## 返回值为 echo_bonus_damage 基础值 + 锻锤武装的每 token 追加伤害。
func _consume_echo_token(target: Node, packet: DamagePacket) -> int:
	if _echo_pending_tokens <= 0:
		return 0
	if target == null or not target.is_in_group("enemies"):
		return 0
	_echo_pending_tokens -= 1
	if packet != null:
		packet.is_echo = true
	var base: int = roundi(_get_stat_float("echo_bonus_damage", 2.0))
	var bonus: int = _echo_token_bonus
	if _echo_pending_tokens <= 0:
		_echo_token_bonus = 0
	return base + bonus


# ---- 破城锥穿透态 ----

## Head 正常碰撞掩码（marble.tscn：mask bits 0/2/3）。穿透期间移除 enemy 层（bit 3）。
const HEAD_COLLISION_MASK_NORMAL: int = 13
const HEAD_COLLISION_MASK_PIERCING: int = 5
## 穿透传感器：layer 0（不参与碰撞），仅探测 enemy 层（bit 3）。Godot 双端规则下
## Head 侧 mask 移除 enemy 位即不再与敌人刚体碰撞，穿透成立。
const PIERCE_SENSOR_LAYER: int = 0
const PIERCE_SENSOR_MASK: int = 8
## 传感器探测半径（与 Head 碰撞体半径一致）。
const PIERCE_SENSOR_RADIUS: float = 8.0
## 穿透耗尽后，Head 需与所有敌人保持的退出距离（接触距离 16 + 余量）。
const PIERCE_EXIT_CLEARANCE: float = 20.0
## 穿透耗尽后延迟退出的物理帧上限，防止 Head 被夹住时传感器悬挂。
const PIERCE_EXIT_MAX_FRAMES: int = 60
## 穿透态弹珠描边：金色高亮（marble_outline.gdshader 的 clr / thickness）。
const PIERCE_OUTLINE_COLOR: Color = Color(1.0, 0.78, 0.2, 1.0)
const PIERCE_OUTLINE_THICKNESS: float = 2.0
const OUTLINE_THICKNESS_NORMAL: float = 1.0

## 当前剩余穿透时长（秒）；0 = 非穿透态。
var _pierce_time_left: float = 0.0
## 穿透伤害倍率（觉醒破城锥 ×1.5，基础 1.0）。
var _pierce_damage_multiplier: float = 1.0
## 穿透时间耗尽、等待 Head 脱离敌人后恢复碰撞掩码。
var _pierce_exit_pending: bool = false
var _pierce_exit_frames: int = 0
## 穿透传感器（挂在 Head 下，跟随弹珠；layer=0, mask=8，只探测敌人）。
var _pierce_sensor: Area2D = null
## 本穿透态已结算过的敌人（body_exited 清除，防止重叠区域重复结算）。
var _pierce_hit_enemies: Array = []


## 进入穿透态：Head 移除 enemy 碰撞层，挂 Area2D 传感器探测敌人；穿透命中复用
## Enemy._on_body_entered(head) 完整伤害管线（消费回响 token 享受强力击加成），
## 并维持「命中敌人 → 蓄力」核心循环。持续 duration 秒后自动退出。
func enter_pierce_state(duration: float, damage_multiplier: float = 1.0) -> void:
	if duration <= 0.0 or head == null or not is_instance_valid(head) or _is_doomed(head):
		return
	_pierce_time_left = duration
	_pierce_damage_multiplier = maxf(1.0, damage_multiplier)
	_pierce_hit_enemies.clear()
	head.collision_mask = HEAD_COLLISION_MASK_PIERCING
	_ensure_pierce_sensor()
	_set_pierce_visual(true)


## 退出穿透态：恢复 Head 碰撞掩码、移除传感器并还原描边。幂等，可安全重复调用。
func exit_pierce_state() -> void:
	_pierce_time_left = 0.0
	_pierce_damage_multiplier = 1.0
	_pierce_exit_pending = false
	_pierce_exit_frames = 0
	_pierce_hit_enemies.clear()
	if head != null and is_instance_valid(head) and not _is_doomed(head):
		head.collision_mask = HEAD_COLLISION_MASK_NORMAL
	_clear_pierce_sensor()
	_set_pierce_visual(false)


## 当前是否处于穿透态。
func is_piercing() -> bool:
	return _pierce_time_left > 0.0


## 当前剩余穿透时长（秒；0 = 非穿透态）。
func get_pierce_time_left() -> float:
	return _pierce_time_left


func _ensure_pierce_sensor() -> void:
	if _pierce_sensor != null and is_instance_valid(_pierce_sensor):
		return
	var sensor := Area2D.new()
	sensor.name = "EchoPierceSensor"
	sensor.collision_layer = PIERCE_SENSOR_LAYER
	sensor.collision_mask = PIERCE_SENSOR_MASK
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = PIERCE_SENSOR_RADIUS
	shape.shape = circle
	sensor.add_child(shape)
	sensor.body_entered.connect(_on_pierce_sensor_body_entered)
	sensor.body_exited.connect(_on_pierce_sensor_body_exited)
	head.add_child(sensor)
	_pierce_sensor = sensor


func _clear_pierce_sensor() -> void:
	if _pierce_sensor == null:
		return
	if is_instance_valid(_pierce_sensor):
		if _pierce_sensor.body_entered.is_connected(_on_pierce_sensor_body_entered):
			_pierce_sensor.body_entered.disconnect(_on_pierce_sensor_body_entered)
		if _pierce_sensor.body_exited.is_connected(_on_pierce_sensor_body_exited):
			_pierce_sensor.body_exited.disconnect(_on_pierce_sensor_body_exited)
		_pierce_sensor.queue_free()
	_pierce_sensor = null


func _on_pierce_sensor_body_entered(collided: Node) -> void:
	if _pierce_time_left <= 0.0 or collided == null or not collided.is_in_group("enemies"):
		return
	if _pierce_hit_enemies.has(collided):
		return
	_pierce_hit_enemies.append(collided)
	# 复用 Enemy 的完整弹珠命中管线（伤害聚合、状态、死亡结算）。
	# 时间制下命中不减少剩余时长：穿透期间可穿过任意多个敌人。
	if collided.has_method("_on_body_entered"):
		collided.call("_on_body_entered", head)
	# 穿透命中也算命中：维持核心循环（命中敌人 → 挡板蓄力）。
	_emit_chain_collision(collided)


func _on_pierce_sensor_body_exited(collided: Node) -> void:
	if collided != null:
		_pierce_hit_enemies.erase(collided)


## 每物理帧递减穿透剩余时长；归零后进入退出等待（等 Head 脱离敌人再恢复掩码）。
func _tick_pierce_time(delta: float) -> void:
	if _pierce_time_left <= 0.0:
		return
	_pierce_time_left -= delta
	if _pierce_time_left <= 0.0:
		# 物理回调中不能立即恢复掩码；且此时 Head 可能仍在敌人体内，
		# 立即恢复会被物理推开。改为等待 Head 脱离所有敌人后再恢复（_tick_pierce_exit）。
		_pierce_exit_pending = true
		_pierce_exit_frames = 0


## 每物理帧驱动穿透退出：时长耗尽且 Head 已脱离所有敌人（或超时兜底）时恢复碰撞。
func _tick_pierce_exit() -> void:
	if not _pierce_exit_pending:
		return
	if _pierce_time_left > 0.0:
		_pierce_exit_pending = false
		return
	_pierce_exit_frames += 1
	if _pierce_exit_frames > PIERCE_EXIT_MAX_FRAMES or not _overlapping_any_enemy():
		_pierce_exit_pending = false
		exit_pierce_state()


## 穿透态视觉：金色描边（穿透中）/ 默认白色描边（退出）。
func _set_pierce_visual(enabled: bool) -> void:
	if head == null or not is_instance_valid(head):
		return
	var sprite: Sprite2D = head.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	var material: ShaderMaterial = sprite.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter(&"clr", PIERCE_OUTLINE_COLOR if enabled else Color.WHITE)
	material.set_shader_parameter(
		&"thickness", PIERCE_OUTLINE_THICKNESS if enabled else OUTLINE_THICKNESS_NORMAL
	)


func _overlapping_any_enemy() -> bool:
	if head == null or not is_instance_valid(head):
		return false
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	for enemy: Node in tree.get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var enemy_node: Node2D = enemy as Node2D
		if head.global_position.distance_to(enemy_node.global_position) < PIERCE_EXIT_CLEARANCE:
			return true
	return false


# ---- 回响控制器绑定 ----

## 将本链登记到 group 并绑定当前 TableBase 的 EchoFlipperChargeController。
## 掉球重建链（新节点或同节点重建）都会重新调用，蓄力保留在控制器侧。
func _bind_echo_charge_controller() -> void:
	add_to_group(&"marble_chain")
	var controller := _find_echo_charge_controller()
	if controller != null:
		controller.call("bind_chain", self)


func _find_echo_charge_controller() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	for node: Node in tree.get_nodes_in_group(&"echo_charge_controller"):
		if node == null or not is_instance_valid(node) or _is_doomed(node):
			continue
		if not node.has_method("bind_chain"):
			continue
		return node
	return null


## queue_free() 只标记根节点；子节点需向上检查祖先。返回自身或任一祖先已排入删除。
static func _is_doomed(node: Node) -> bool:
	var current: Node = node
	while current != null:
		if current.is_queued_for_deletion():
			return true
		current = current.get_parent()
	return false


# ---- 伤害聚合 ----

## 敌人碰撞时调用此方法，聚合 Head 基础伤害 + 所有 Body 段贡献。
func get_total_damage(target: Node, packet: DamagePacket = null) -> int:
	var total: int = 0

	if head != null and is_instance_valid(head):
		total += _head_contact_damage()
		total += _apply_hit_effect(head.marble_type, target, packet)

	for seg: ChainSegment in body:
		if seg == null or not is_instance_valid(seg):
			continue
		total += _apply_hit_effect(seg.segment_type, target, packet)
		total += _segment_contact_damage(seg)

	total += _dry_bomb_contact_damage(target, packet)
	total += _consume_echo_token(target, packet)

	# 破城锥觉醒：穿透伤害倍率（穿透命中享受强力击加成，觉醒 ×1.5）。
	if _pierce_time_left > 0.0 and _pierce_damage_multiplier > 1.0:
		total = roundi(total * _pierce_damage_multiplier)

	return total


## 0 弹药兜底：链含 BOMB 且弹药为 0 时，整链普通碰撞补 1 点伤害
## （爆炸已失效，保底可打）。目标必须是敌人；多个炸弹段不重复补。
## 弹药 > 0 时返回 0——碰撞伤害由爆炸负责。
func _dry_bomb_contact_damage(target: Node, packet: DamagePacket = null) -> int:
	if target == null or not is_instance_valid(target):
		return 0
	if not target.is_in_group("enemies"):
		return 0
	if not _contains_marble_type(Marble.MARBLE_TYPE.BOMB):
		return 0
	var ammo_state := _get_ammo_state()
	if ammo_state != null and ammo_state.get_ammo() > 0:
		return 0
	if packet != null:
		packet.metadata["dry_bomb"] = true
	return 1


func _head_contact_damage() -> int:
	if head == null or not is_instance_valid(head):
		return 0
	if head.marble_type == Marble.MARBLE_TYPE.DEFAULT:
		return roundi(_get_stat_float("dark_marble_damage", float(head.damage)))
	if head.marble_type == Marble.MARBLE_TYPE.ASSASSIN:
		return roundi(_get_stat_float("assassin_segment_damage", float(head.damage)))
	return head.damage


func _apply_hit_effect(
	marble_type: Marble.MARBLE_TYPE,
	target: Node,
	packet: DamagePacket
) -> int:
	match marble_type:
		Marble.MARBLE_TYPE.GREEN:
			GreenMarble.apply_poison_to_enemy(target, packet)
		Marble.MARBLE_TYPE.BLUE:
			var stacks_after_hit: int = BlueMarble.apply_frost_to_enemy(target, packet)
			return BlueMarble.get_frost_bonus_damage(stacks_after_hit)
		Marble.MARBLE_TYPE.FIRE:
			FireMarbleScript.apply_burn_to_enemy(target, packet)
		Marble.MARBLE_TYPE.LIGHTNING:
			LightningMarbleScript.prepare_direct_hit(target, packet)
			if packet != null and head != null and is_instance_valid(head):
				packet.metadata[LightningMarble.META_ORIGIN_POSITION] = head.global_position
	return 0


## Assassin segment damage grows with the assassin_weak_point progression stat; the
## crit itself is resolved on the enemy side, so here it is just contact damage.
func _segment_contact_damage(seg: ChainSegment) -> int:
	if seg.segment_type == Marble.MARBLE_TYPE.ASSASSIN:
		return roundi(_get_stat_float("assassin_segment_damage", float(seg.damage)))
	return seg.damage


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
	var collision_type: String = "wall"
	if collided_body.is_in_group("enemies"):
		collision_type = "enemy"
	elif collided_body.is_in_group("flipper"):
		collision_type = "flipper"

	chain_collision.emit(collided_body, collision_type)


# ---- 轨迹 & 跟随 ----

func _physics_process(delta: float) -> void:
	if head == null or not is_instance_valid(head):
		return
	_record_trail()
	_update_body_segments()
	_tick_pierce_time(delta)
	_tick_pierce_exit()


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


func reset_after_teleport(destination: Vector2, exit_forward: Vector2) -> void:
	if head == null or not is_instance_valid(head):
		return
	_trail.clear()
	for index: int in range(_chain_length * 2):
		_trail.append({
			"pos": destination - exit_forward * trail_sample_spacing * index,
			"rot": exit_forward.angle(),
		})
	for index: int in range(body.size()):
		var segment: ChainSegment = body[index]
		if segment == null or not is_instance_valid(segment):
			continue
		segment.global_position = destination - exit_forward * trail_point_spacing * (index + 1)
		segment.rotation = exit_forward.angle()


func _register_with_registry() -> void:
	if _registry != null and is_instance_valid(_registry) and head != null:
		_registry.register_chain(self)


func _unregister_from_registry() -> void:
	if _registry != null and is_instance_valid(_registry):
		_registry.unregister_chain(self)


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
