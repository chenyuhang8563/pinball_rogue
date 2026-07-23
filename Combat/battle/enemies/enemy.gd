class_name Enemy
extends RigidBody2D

signal defeated(enemy: Enemy, cause: StringName)

const StatContextScript: GDScript = preload("res://Core/stats/stat_context.gd")
const DamagePacketScript: GDScript = preload("res://Combat/damage/damage_packet.gd")
const DamagePipelineScript: GDScript = preload("res://Combat/damage/damage_pipeline.gd")
const FrostStatusVisualScene: PackedScene = preload("res://Combat/effects/frost_status_visual/frost_status_visual.tscn")
const FireStatusVisualScene: PackedScene = preload("res://Combat/effects/fire_status_visual/fire_status_visual.tscn")
const META_FROST_TO_FROZEN_TRANSITION: StringName = &"frost_to_frozen_transition"
## 伤害飘字在敌怪上方生成时，X 轴随机偏移的半范围（像素）。
## 实际偏移范围为 [-FLOAT_DAMAGE_X_SPREAD_HALF, FLOAT_DAMAGE_X_SPREAD_HALF]，
## 使同一点上的多次伤害在水平方向上散开，避免完全重叠。
const FLOAT_DAMAGE_X_SPREAD_HALF: float = 8.0
## 碰撞前速度采样环大小。contact_monitor 的 body_entered 比碰撞步晚一个物理步触发，
## 触发时最新采样往往已是碰撞后的值，因此保留最近若干步速度、排除最新帧后取最强者
## 还原碰撞前速度（详见 _get_impact_velocity）。
const FROZEN_IMPACT_VELOCITY_HISTORY: int = 3

@export var health: int = 100:
	set(value):
		health = max(0, value)
		if health_label != null:
			health_label.text = str(health)

@export var flash_duration: float = 0.08
@export var frozen_push_impulse_scale: float = 0.25

@onready var sprite: Sprite2D = $Sprite2D
@onready var hit_flash: Node = $HitFlash
@onready var health_label: Label = $HealthLabel
@onready var buff_host: BuffHost = $BuffHost
@onready var weak_point_host: Node = get_node_or_null("WeakPointHost")
@onready var physics_state_machine: Node = $PhysicsStateMachine

var _entity_id: String = ""
var _death_emitted: bool = false
var _frost_visual: Node2D = null
var _fire_visual: Node2D = null
## 本物理步开始时的速度快照（在 _integrate_forces 记录）。body_entered 触发时
## linear_velocity 可能已是反弹后的值，冻结体碰撞判定必须使用碰撞前速度。
var _pre_step_velocity: Vector2 = Vector2.ZERO
## 最近若干步的速度采样环（碰撞判定用"最近最强速度"还原碰撞前速度）。
var _velocity_history: Array[Vector2] = []
var _velocity_history_cursor: int = 0


func _ready() -> void:
	add_to_group("enemies")
	_entity_id = "enemy_%d" % get_instance_id()
	_register_stat_entity()
	_update_health_label()
	if buff_host != null and not buff_host.buff_ticked.is_connected(_on_buff_ticked):
		buff_host.buff_ticked.connect(_on_buff_ticked)
	if weak_point_host != null and weak_point_host.has_method("sync_to_assassin"):
		weak_point_host.call("sync_to_assassin")


func _exit_tree() -> void:
	if buff_host != null and buff_host.buff_ticked.is_connected(_on_buff_ticked):
		buff_host.buff_ticked.disconnect(_on_buff_ticked)
	var stat_system: Node = _get_stat_system()
	if stat_system != null and stat_system.has_method("unregister_entity") and _entity_id != "":
		stat_system.call("unregister_entity", _entity_id)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# 记录本物理步开始时的速度，作为碰撞判定用的"碰撞前速度"快照。
	_pre_step_velocity = state.linear_velocity
	if _velocity_history.size() < FROZEN_IMPACT_VELOCITY_HISTORY:
		_velocity_history.append(state.linear_velocity)
	else:
		_velocity_history[_velocity_history_cursor] = state.linear_velocity
		_velocity_history_cursor = (_velocity_history_cursor + 1) % FROZEN_IMPACT_VELOCITY_HISTORY


func _on_body_entered(body: Node) -> void:
	if body == null or body == self or not is_alive():
		return
	var was_frozen_at_collision: bool = has_buff("frozen_debuff")
	if was_frozen_at_collision:
		_apply_frozen_collision_damage()
		if not is_alive():
			return
	if body.is_in_group("marbles"):
		var was_burning: bool = has_buff("fire_burn_debuff")
		var was_frozen: bool = has_buff("frozen_debuff")
		# 弹珠接触冻结敌人也属于冻结碰撞，必须在碎冰锤可能解除 Frozen 前分发。
		if was_frozen:
			_try_report_frozen_impact(body)
		var packet: DamagePacket = DamagePacketScript.new(&"marble_head", 0.0)
		packet.is_marble = true
		packet.target = self
		# This hook intentionally runs before chain aggregation to preserve legacy
		# lightning timing. Consumers may write metadata or flat damage only; base
		# is assigned after get_hit_damage completes below.
		var effect_manager: Node = _get_effect_manager()
		if effect_manager != null and effect_manager.has_method("on_enemy_hit_by_marble"):
			effect_manager.call("on_enemy_hit_by_marble", self, packet)
		var hit_damage: int = _get_damage_from_body(body, packet)
		packet.base = float(hit_damage)
		packet.flash_color = _get_active_buff_flash_color()
		_resolve_weak_point_crit(body, packet)
		apply_damage_packet(packet)
		if is_alive() and effect_manager != null and effect_manager.has_method("on_enemy_hit_resolved"):
			effect_manager.call("on_enemy_hit_resolved", self, was_burning, was_frozen, packet)
		_apply_frozen_push_from_body(body)
		return
	_try_report_frozen_impact(body)


## Frozen 敌人的任意 body_entered 接触固定结算 1 点自身伤害。使用 DamagePacket 以
## 复用生命同步、死亡、伤害飘字和 Effect 通知管线，并显式绕过伤害修正保证固定 -1。
func _apply_frozen_collision_damage() -> void:
	var packet: DamagePacket = DamagePacketScript.new(&"frozen_collision", 1.0)
	packet.bypasses_damage_modifiers = true
	packet.target = self
	apply_damage_packet(packet)


func take_damage(amount: int, flash_color: Color = Color.WHITE, floating_style: StringName = &"default") -> void:
	var packet: DamagePacket = DamagePacketScript.new(&"untyped", float(amount))
	packet.flash_color = flash_color
	packet.floating_style = floating_style
	apply_damage_packet(packet)


func apply_damage_packet(packet: DamagePacket) -> void:
	if packet == null:
		return
	if packet.target == null or packet.target != self:
		packet.target = self
	var effect_manager: Node = _get_effect_manager()
	if effect_manager != null and effect_manager.has_method("modify_damage_packet"):
		effect_manager.call("modify_damage_packet", self, packet)
	var pre_armor: int = max(0, roundi(packet.base + packet.flat)) if packet.bypasses_damage_modifiers \
			else DamagePipelineScript.resolve_pre_armor(packet, _get_stat_system())
	var final_damage: int = pre_armor
	var stat_system: Node = _get_stat_system()
	if stat_system != null and stat_system.has_method("get_stat") and _entity_id != "":
		if not packet.bypasses_damage_modifiers:
			var context: RefCounted = StatContextScript.new(
				_entity_id,
				"",
				"apply_damage_packet",
				{"raw_damage": pre_armor}
			)
			final_damage = int(stat_system.call("get_stat", "damage_received", _entity_id, context))
		var current_health: int = int(stat_system.call("get_stat", "current_health", _entity_id))
		stat_system.call("set_stat_base", _entity_id, "current_health", current_health - final_damage)
		health = int(stat_system.call("get_stat", "current_health", _entity_id))
	else:
		health -= final_damage
	packet.final_amount = final_damage

	flash_hit_mask(packet.flash_color)
	_show_float_damage_text(final_damage, packet.floating_style)
	if effect_manager != null and effect_manager.has_method("on_damage_dealt"):
		effect_manager.call("on_damage_dealt", self, packet)

	if health <= 0:
		if defeat(&"health_depleted") and effect_manager != null and effect_manager.has_method("on_enemy_defeated"):
			effect_manager.call("on_enemy_defeated", self, packet)


func defeat(cause: StringName) -> bool:
	if _death_emitted or is_queued_for_deletion():
		return false
	_death_emitted = true
	if buff_host != null:
		buff_host.notify_host_death()
	defeated.emit(self, cause)
	queue_free()
	return true


func add_buff(buff: BuffDef, stacks: int = 1, packet: DamagePacket = null) -> void:
	if buff_host != null:
		var applied: bool = buff_host.add_buff(buff, stacks)
		var after_stacks: int = get_buff_stacks(buff.id) if buff != null else 0
		if applied and buff != null and after_stacks > 0:
			var effect_manager: Node = _get_effect_manager()
			if effect_manager != null and effect_manager.has_method("on_status_applied"):
				effect_manager.call("on_status_applied", self, StringName(buff.id), after_stacks, packet)


func remove_buff(buff_id: String) -> void:
	if buff_host != null:
		buff_host.remove_buff(buff_id)


func has_buff(buff_id: String) -> bool:
	return buff_host != null and buff_host.has_buff(buff_id)


func get_buff_stacks(buff_id: String) -> int:
	if buff_host == null:
		return 0
	return buff_host.get_buff_stacks(buff_id)


func consume_buff_stacks(buff_id: String, amount: int = 1) -> int:
	if buff_host == null:
		return 0
	return buff_host.consume_buff_stacks(buff_id, amount)


func append_buff_duration(buff_id: String, duration_to_append: float, max_duration: float = -1.0) -> bool:
	return buff_host != null and buff_host.append_buff_duration(buff_id, duration_to_append, max_duration)


## Buff 通过宿主门面报告离散 tick；BuffHost 负责 typed 事件发射，使 buff 脚本
## 完全不依赖 Effect 域。
func notify_buff_ticked(buff_id: String) -> void:
	if buff_host != null:
		buff_host.notify_ticked(buff_id)


## 单向桥：Buff 只发事件，由宿主把 poison tick 转给 Effect 域（毒循环反转）。
func _on_buff_ticked(buff_id: String, host: Node) -> void:
	if not host is Node2D:
		return
	var effect_manager: Node = _get_effect_manager()
	if effect_manager == null:
		return
	if buff_id == "poison_debuff" and effect_manager.has_method("on_poison_tick"):
		effect_manager.call("on_poison_tick", host as Node2D, get_buff_stacks(buff_id))
	if buff_id == "fire_burn_debuff" and effect_manager.has_method("on_burn_tick"):
		effect_manager.call("on_burn_tick", host as Node2D, get_buff_stacks(buff_id))


func is_alive() -> bool:
	return health > 0 and not _death_emitted


func flash_hit_mask(flash_color: Color) -> void:
	if hit_flash == null or not hit_flash.has_method("flash"):
		return
	hit_flash.call("flash", flash_color)


func set_frost_visual(stacks: int, max_stacks: int, is_frozen: bool) -> void:
	_set_sprite_frost_amount(_get_frost_amount(stacks, max_stacks))
	if _frost_visual == null or not is_instance_valid(_frost_visual):
		_frost_visual = FrostStatusVisualScene.instantiate() as Node2D
		_frost_visual.name = "FrostStatusVisual"
		add_child(_frost_visual)
	if _frost_visual != null and _frost_visual.has_method("set_frost_state"):
		_frost_visual.call("set_frost_state", stacks, max_stacks, is_frozen)
	set_meta("frozen", is_frozen)


func set_frozen_visual(is_frozen: bool) -> void:
	_set_sprite_frost_amount(0.0)
	if is_frozen:
		if _frost_visual == null or not is_instance_valid(_frost_visual):
			_frost_visual = FrostStatusVisualScene.instantiate() as Node2D
			_frost_visual.name = "FrostStatusVisual"
			add_child(_frost_visual)
		if _frost_visual != null and _frost_visual.has_method("set_frost_state"):
			_frost_visual.call("set_frost_state", 0, 1, true)
	else:
		if _frost_visual != null and is_instance_valid(_frost_visual):
			_frost_visual.queue_free()
		_frost_visual = null
	set_meta("frozen", is_frozen)


func begin_frozen_physics() -> void:
	_transition_physics_state(&"Frozen")


func end_frozen_physics() -> void:
	_transition_physics_state(&"Normal")


func restore_frozen_physics_snapshot(snapshot: Dictionary) -> void:
	var restored_transform: Transform2D = global_transform
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	gravity_scale = float(snapshot.get("gravity_scale", gravity_scale))
	lock_rotation = bool(snapshot.get("lock_rotation", lock_rotation))
	physics_material_override = snapshot.get("physics_material_override", physics_material_override)
	linear_damp = float(snapshot.get("linear_damp", linear_damp))
	linear_damp_mode = snapshot.get("linear_damp_mode", linear_damp_mode)
	angular_damp = float(snapshot.get("angular_damp", angular_damp))
	angular_damp_mode = snapshot.get("angular_damp_mode", angular_damp_mode)
	freeze_mode = snapshot.get("freeze_mode", freeze_mode)
	freeze = bool(snapshot.get("freeze", freeze))
	global_transform = restored_transform
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, restored_transform)
	reset_physics_interpolation()
	set_sleeping(false)


func clear_frost_visual() -> void:
	_set_sprite_frost_amount(0.0)
	if bool(get_meta(META_FROST_TO_FROZEN_TRANSITION, false)):
		return
	if bool(get_meta("frozen", false)):
		return
	if _frost_visual != null and is_instance_valid(_frost_visual):
		_frost_visual.free()
	_frost_visual = null


func set_fire_status_visual() -> void:
	if _fire_visual == null or not is_instance_valid(_fire_visual):
		_fire_visual = FireStatusVisualScene.instantiate() as Node2D
		_fire_visual.name = "FireStatusVisual"
		add_child(_fire_visual)


func clear_fire_status_visual() -> void:
	if _fire_visual != null and is_instance_valid(_fire_visual):
		_fire_visual.queue_free()
	_fire_visual = null


func _get_damage_from_body(body: Node, packet: DamagePacket = null) -> int:
	if body.has_method("get_hit_damage"):
		return body.get_hit_damage(self, packet)
	return 1


## Resolves a weak-point crit for a marble hit. The contact direction is measured in
## enemy-local space (matching the weak-point visual, a child of this enemy) so it
## stays correct even if the enemy rotates. On a crit the packet is flagged and the
## consumed weak point is relocated atomically by the host.
func _resolve_weak_point_crit(body: Node, packet: DamagePacket) -> void:
	if weak_point_host == null or not weak_point_host.has_method("try_resolve_crit"):
		return
	if not body is Node2D:
		return
	var local_point: Vector2 = to_local((body as Node2D).global_position)
	if local_point == Vector2.ZERO:
		return
	var info: Dictionary = weak_point_host.call("try_resolve_crit", local_point.angle())
	if info.is_empty() or not bool(info.get("is_crit", false)):
		return
	packet.is_crit = true
	packet.is_perfect_crit = bool(info.get("is_perfect", false))
	packet.crit_multiplier = float(info.get("multiplier", 1.0))
	packet.crit_source = &"weak_point_prism" \
		if int(info.get("kind", 0)) == int(WeakPoint.Kind.PRISM) else &"weak_point_base"
	packet.crit_direction = int(info.get("direction", -1))
	packet.floating_style = &"perfect" if packet.is_perfect_crit else &"crit"
	if weak_point_host.has_method("consume_crit"):
		weak_point_host.call("consume_crit", info)


func _apply_frozen_push_from_body(body: Node) -> void:
	if not bool(get_meta("frozen", false)):
		return
	if not body is RigidBody2D:
		return
	var marble: RigidBody2D = body as RigidBody2D
	var push_velocity: Vector2 = marble.linear_velocity
	if push_velocity == Vector2.ZERO and marble.global_position != global_position:
		push_velocity = (global_position - marble.global_position).normalized() * 80.0
	if push_velocity == Vector2.ZERO:
		return
	call_deferred("_apply_frozen_push_impulse", push_velocity * frozen_push_impulse_scale)


func _apply_frozen_push_impulse(impulse: Vector2) -> void:
	if not bool(get_meta("frozen", false)):
		return
	freeze = false
	set_sleeping(false)
	angular_velocity = 0.0
	linear_velocity += impulse / maxf(mass, 0.001)


## 碰撞判定用的"碰撞前速度"：取最近采样环中最强的速度，但排除最新一帧采样。
## contact_monitor 的 body_entered 比碰撞步晚一个物理步触发（Godot 延迟上报接触）：
## 回调执行时最新采样已是"碰撞后一步"的速度——对撞墙反弹的主动方是反弹低速
## （取最强可避开），但对被撞的静止目标却是被撞击后获得的高速度，会导致它
## 误报自己的"碰撞前速度"。排除最新采样后，剩余采样中最强者 = 碰撞步开始时
## 的速度；敌人对撞再用该方向关系过滤被撞的静止目标。
## 采样环为空（GUT 分支测试直接注入 _pre_step_velocity、未经真实物理步）时回退到
## _pre_step_velocity 本身。
func _get_impact_velocity() -> Vector2:
	var count: int = _velocity_history.size()
	if count == 0:
		return _pre_step_velocity
	var strongest := Vector2.ZERO
	# 环满时最新采样位于 (cursor - 1) mod count；环未满时不跳过，最新采样仍是
	# 碰撞前速度。
	var newest_index: int = -1
	if count >= FROZEN_IMPACT_VELOCITY_HISTORY:
		newest_index = (_velocity_history_cursor - 1 + count) % count
	for i: int in range(count):
		if i == newest_index:
			continue
		var sample: Vector2 = _velocity_history[i]
		if sample.length_squared() > strongest.length_squared():
			strongest = sample
	if strongest == Vector2.ZERO and _pre_step_velocity != Vector2.ZERO:
		return _pre_step_velocity
	return strongest


## 冻结体碰撞判定与事件分发（可测试缝隙，GUT 可直接调用）。
## 分类（绝不把非敌人一律当墙）：
## - enemies 组 -> kind=&"enemy"，hit_body=对方；
## - marbles 组 -> kind=&"marble"；
## - flipper/projectiles/skill_projectiles 组或 AnimatableBody2D（台面挡板）-> ignored；
## - 仅 StaticBody2D（墙体/平台/边界）-> kind=&"world"，hit_body=null；
## - 其余未分类刚体（无组 RigidBody2D/CharacterBody2D 等）-> ignored，宁缺勿误报。
## 仅在自身冻结时分发，不使用速度阈值或时间冷却：body_entered 的每次接触边沿
## 都是觉醒永冻可延时、冰爆可碎裂的一次碰撞。敌人互撞仍用方向过滤避免受撞方误报。
## 返回是否分发了事件（被分类、方向或无接收方拦截时为 false）。
func _try_report_frozen_impact(body: Node) -> bool:
	if body == null or body == self or not is_alive():
		return false
	if not bool(get_meta("frozen", false)):
		return false
	var kind: StringName
	var hit_body: Node2D = null
	if body.is_in_group("enemies"):
		kind = &"enemy"
		hit_body = body as Node2D
	elif body.is_in_group("marbles"):
		kind = &"marble"
	elif body.is_in_group("flipper") or body.is_in_group("projectiles") or body.is_in_group("skill_projectiles") \
			or body is AnimatableBody2D:
		return false
	elif body is StaticBody2D:
		kind = &"world"
	else:
		return false
	var impact_velocity: Vector2 = _get_impact_velocity()
	# 敌人对撞时要求"我方正朝对方移动"（碰撞前速度指向对方）。被撞的静止目标
	# 获得的碰撞后速度背离撞击方；不排除会把"被高速撞击"误报为"自己高速撞敌"
	# （信号可能晚碰撞步 2 步触发，采样环排除最新帧也拦不住它）。冰材质恢复
	# 系数 0.08，碰撞后双方不会交换位置，用信号时刻位置判方向是可靠的。
	if kind == &"enemy" and hit_body != null:
		var to_other: Vector2 = hit_body.global_position - global_position
		if to_other.length_squared() > 0.0001 and impact_velocity.dot(to_other.normalized()) <= 0.0:
			return false
	var effect_manager: Node = _get_effect_manager()
	if effect_manager == null or not effect_manager.has_method("on_frozen_body_impact"):
		return false
	var velocity: Vector2 = impact_velocity
	effect_manager.call("on_frozen_body_impact", self, hit_body, velocity, kind)
	return true


func _transition_physics_state(state_name: StringName) -> void:
	if physics_state_machine != null and physics_state_machine.has_method("transition_to"):
		physics_state_machine.call("transition_to", state_name)


func _get_active_buff_flash_color() -> Color:
	if buff_host == null:
		return Color.WHITE
	return buff_host.get_active_flash_color()


func get_stat_entity_id() -> String:
	return _entity_id


func _register_stat_entity() -> void:
	var stat_system: Node = _get_stat_system()
	if stat_system == null or not stat_system.has_method("register_entity"):
		return
	stat_system.call("register_entity", _entity_id, ["max_health", "current_health", "armor"])
	stat_system.call("set_stat_base", _entity_id, "max_health", float(health))
	stat_system.call("set_stat_base", _entity_id, "current_health", float(health))


func _get_frost_amount(stacks: int, max_stacks: int) -> float:
	return clampf(float(max(0, stacks)) / float(max(1, max_stacks)), 0.0, 1.0)


func _set_sprite_frost_amount(amount: float) -> void:
	if sprite == null or not sprite.material is ShaderMaterial:
		return
	var shader_material: ShaderMaterial = sprite.material as ShaderMaterial
	shader_material.set_shader_parameter("frost_amount", amount)


func _update_health_label() -> void:
	if health_label != null:
		health_label.text = str(health)


func _get_stat_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("StatSystem")


func _get_effect_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("EffectManager")


func _show_float_damage_text(damage_amount: int, style: StringName = &"default") -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var pool: Node = tree.root.get_node_or_null("FloatDamageTextPool")
	if pool != null and pool.has_method("show_damage"):
		var spawn_pos: Vector2 = global_position + Vector2.UP * 8.0
		spawn_pos.x += randf_range(-FLOAT_DAMAGE_X_SPREAD_HALF, FLOAT_DAMAGE_X_SPREAD_HALF)
		pool.call("show_damage", damage_amount, spawn_pos, style)
