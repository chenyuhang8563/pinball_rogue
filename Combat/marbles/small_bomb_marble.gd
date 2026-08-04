# 小炸弹弹珠 —— 高爆弹头遗物产出的独立投射物。
#
# 独立于 Marble/MarbleChain：不入 "marbles" group（避免 RunFlowController 把掉台
# 误判为主弹珠扣 1 生命），加入 "produced_marbles" group 供产出服务实时计数。
# 物理上刻意 mask=15（环境1+弹珠2+挡板4+敌人8）：多出的 layer 2 正是为了能与链
# head 碰撞（用户要求）；其余物理参数（layer=2、mass、gravity_scale、bounce、
# contact_monitor、continuous_cd）复用 marble 模板。
#
# 碰撞结果：敌人 → 每次碰撞造成一次范围伤害但继续弹跳（不消失）；环境/挡板/链
# head → 纯物理反弹（链 head 是友军不引爆）。生命周期：超时 3s 无声消失 /
# 掉出台消失。3s 内可多次碰撞敌人、多次造成伤害。速度每物理帧 clamp 到
# max_speed（默认 450 px/s），bounce=1.0 的连续反弹不会让速度失控。
#
# 独立结算：不构造 ExplosionContext、不触发 EffectManager.on_explosion*，
# 仅复用共享径向伤害工具 RadialDamage 与爆炸 VFX；敌人侧自身伤害/死亡流程照常。

extends RigidBody2D
class_name SmallBombMarble

const RadialDamageScript: GDScript = preload("res://Combat/explosion/radial_damage.gd")
const ExplosionEffectScene: PackedScene = preload("res://Combat/effects/explosion_effect/explosion_effect.tscn")

@export var damage_ratio: float = 0.5
@export var lifetime: float = 3.0
@export var initial_impulse: float = 140.0
## 速度上限（px/s）：小炸弹 bounce=1.0 无能量损失，连续反弹会越弹越快；
## 每物理帧 clamp 到该值，避免速度失控。低于普通弹珠的 max_speed=800。
@export var max_speed: float = 450.0

## 掉出台检测：缓存父场景 TableBase/KillZone 引用；父场景重建/失效时重新查找。
var _kill_zone: Node = null
var _fall_check_timer: float = 0.0


func _ready() -> void:
	add_to_group(&"produced_marbles")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	# 生成时随机方向初速。set_sleeping(false) 唤醒物理体，否则 impulse 不生效。
	set_sleeping(false)
	apply_central_impulse(Vector2.RIGHT.rotated(randf() * TAU) * initial_impulse)


func _physics_process(delta: float) -> void:
	_clamp_speed()
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	_fall_check_timer -= delta
	if _fall_check_timer <= 0.0:
		_fall_check_timer = 0.2
		_check_kill_zone()


## 规范速度：超过 max_speed 时按比例缩短到上限（保留方向）。
func _clamp_speed() -> void:
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.limit_length(max_speed)


func _on_body_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group(&"enemies"):
		# 碰敌造成一次范围伤害，但弹珠不消失，继续在场上弹跳直到 3s 超时。
		_deal_damage()


func _deal_damage() -> void:
	var center: Vector2 = global_position
	var damage: int = roundi(_get_stat_float(&"explosion_damage", 4.0) * damage_ratio)
	var radius: float = _get_stat_float(&"explosion_radius", 75.0)
	RadialDamageScript.damage_enemies_in_radius(center, radius, damage, true)
	_spawn_explosion_effect(center)


func _spawn_explosion_effect(center: Vector2) -> void:
	var scene: Node = Engine.get_main_loop().current_scene
	if scene == null:
		return
	var effect: Node2D = ExplosionEffectScene.instantiate() as Node2D
	scene.add_child(effect)
	effect.global_position = center


func _check_kill_zone() -> void:
	if _kill_zone == null or not is_instance_valid(_kill_zone):
		_find_kill_zone()
	if _kill_zone == null or not is_instance_valid(_kill_zone):
		return
	if not _kill_zone.has_method(&"contains_global_point"):
		return
	if bool(_kill_zone.call(&"contains_global_point", global_position)):
		queue_free()


## 缓存父场景 TableBase/KillZone 引用（战斗场景一次实例化）。父场景重建时失效。
func _find_kill_zone() -> void:
	var parent := get_parent()
	if parent == null:
		return
	_kill_zone = parent.get_node_or_null(NodePath("TableBase/KillZone"))


func _get_stat_float(stat_id: StringName, fallback: float) -> float:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return fallback
	var stat_system: Node = tree.root.get_node_or_null("StatSystem")
	if stat_system == null or not stat_system.has_method("get_stat"):
		return fallback
	return float(stat_system.call("get_stat", String(stat_id), "marble_chain"))
