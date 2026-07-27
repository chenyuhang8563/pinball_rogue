extends RigidBody2D
class_name CryoclasmIceShard

## 冰爆遗物的冰碎片抛射物：命中即消失、不分裂。
## - 有分配目标的碎片只伤害其分配目标（其余敌人穿透），由命中逻辑保证
##   "各命中一个不同敌人"；
## - 无目标碎片是补足等级数量（3/4/6）的纯视觉飞行物，不造成伤害、到期自毁；
## - 源碎裂敌人作为永久碰撞例外，碎片不会回头命中它（保住"源 HP 不变"）。
## 同时加入 projectiles 组（让敌人冻结碰撞分类忽略它，不触发冰爆递归）与
## relic_projectiles 组（冰爆遗物本发末清理用）。

const DamagePacketScript: GDScript = preload("res://Combat/damage/damage_packet.gd")
const FROST_DEBUFF_ID: String = "frost_debuff"

@export var damage: int = 4
@export var speed: float = 260.0
@export var max_lifetime: float = 3.0
@export var turn_rate: float = 8.0

var _target: Node2D = null
var _direction: Vector2 = Vector2.RIGHT
var _ignored_source: PhysicsBody2D = null
var _generation: int = 1
var _applies_frost: int = 0
var _has_hit: bool = false

@onready var _lifetime_timer: Timer = $LifetimeTimer


func _ready() -> void:
	add_to_group("projectiles")
	add_to_group("relic_projectiles")


## 仅由 CryoclasmEffect 在 deferred 阶段调用：先写入刚体出生 transform，再启用速度和碰撞。
func activate_from_spawn(
	spawn_position: Vector2,
	target: Node2D,
	initial_direction: Vector2,
	p_damage: int,
	p_speed: float,
	p_lifetime: float,
	p_turn_rate: float = 8.0,
	generation: int = 1,
	applies_frost: int = 0,
	ignored_source: PhysicsBody2D = null
) -> bool:
	global_position = spawn_position
	PhysicsServer2D.body_set_state(
		get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, global_transform
	)
	return initialize(
		target, initial_direction, p_damage, p_speed, p_lifetime, p_turn_rate, generation, applies_frost,
		ignored_source
	)


## target 可为 null（无目标视觉飞行物）。initial_direction 为扇区发射初向；有目标者
## 逐帧转向，目标失效后保持最后方向。ignored_source 为永久碰撞例外（源碎裂敌人）。
func initialize(
	target: Node2D,
	initial_direction: Vector2,
	p_damage: int,
	p_speed: float,
	p_lifetime: float,
	p_turn_rate: float = 8.0,
	generation: int = 1,
	applies_frost: int = 0,
	ignored_source: PhysicsBody2D = null
) -> bool:
	if initial_direction.is_zero_approx():
		return false
	_target = target if (target != null and is_instance_valid(target)
		and (not target.has_method("is_alive") or bool(target.call("is_alive")))) else null
	damage = maxi(0, p_damage)
	speed = maxf(1.0, p_speed)
	max_lifetime = maxf(0.05, p_lifetime)
	turn_rate = maxf(0.0, p_turn_rate)
	_generation = maxi(0, generation)
	_applies_frost = maxi(0, applies_frost)
	_direction = initial_direction.normalized()
	_ignored_source = ignored_source
	rotation = _direction.angle()
	linear_velocity = _direction * speed
	set_sleeping(false)
	if _target == null:
		# 无目标碎片是纯视觉飞行物；不应被墙、挡板或弹珠弹开而改变轨迹。
		collision_mask = 0
	if _ignored_source != null and is_instance_valid(_ignored_source):
		add_collision_exception_with(_ignored_source)
	# 物理穿透非分配目标：对所有当前敌人加碰撞例外——有目标者只保留其分配目标可碰撞，
	# 无目标视觉碎片（_target==null）忽略全部敌人。这才让"穿透"在刚体层面成立，
	# 而非仅在 body_entered 回调里跳过伤害（否则非目标会物理挡住/弹开碎片）。
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		for candidate: Node in tree.get_nodes_in_group("enemies"):
			if candidate is PhysicsBody2D and candidate != _target and candidate != _ignored_source:
				add_collision_exception_with(candidate as PhysicsBody2D)
	_lifetime_timer.start(max_lifetime)
	return true


func get_target() -> Node2D:
	return _target


func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target) \
			or (_target.has_method("is_alive") and not bool(_target.call("is_alive"))):
		# 目标失效：保持最后方向直线飞行、到期自毁（不重新抢占目标）。
		linear_velocity = _direction * speed
		return
	var to_target: Vector2 = _target.global_position - global_position
	if to_target.is_zero_approx():
		linear_velocity = _direction * speed
		return
	var desired: Vector2 = to_target.normalized()
	var steer: float = clampf(turn_rate * delta, 0.0, 1.0)
	_direction = _direction.slerp(desired, steer).normalized()
	linear_velocity = _direction * speed
	rotation = _direction.angle()


func _on_body_entered(body: Node) -> void:
	if _has_hit:
		return
	if body == null or body == _ignored_source:
		return
	if not body.is_in_group("enemies"):
		return
	# 有目标碎片只命中其分配目标（其余穿透）；无目标碎片（_target==null）不造成伤害。
	if body != _target:
		return
	if body.has_method("is_alive") and not bool(body.call("is_alive")):
		return
	# 先置位再结算，抵御同一物理步多个 body_entered。
	_has_hit = true
	if body.has_method("apply_damage_packet"):
		var packet: DamagePacket = DamagePacketScript.new(
			&"relic_cryoclasm_shard", float(damage), &"frost"
		)
		packet.is_relic = true
		packet.generation = _generation
		packet.target = body as Node2D
		packet.flash_color = Color(0.6, 0.85, 1.0, 1.0)
		body.call("apply_damage_packet", packet)
		if _applies_frost > 0 and body.has_method("is_alive") and bool(body.call("is_alive")) \
				and body.has_method("add_buff"):
			var frost: BuffDef = _make_buff(FROST_DEBUFF_ID)
			if frost != null:
				body.call("add_buff", frost, _applies_frost)
	queue_free()


func _on_lifetime_timer_timeout() -> void:
	queue_free()


func _make_buff(buff_id: String) -> BuffDef:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var registry: Node = tree.root.get_node_or_null("BuffRegistry")
	if registry == null or not registry.has_method("get_buff_def"):
		return null
	return registry.call("get_buff_def", buff_id) as BuffDef
