extends RigidBody2D
class_name DemolitionChargeBomb

## 抛射炸弹实体 —— 不是弹珠，是独立实体炸弹。
##
## - 抛射期：freeze=true，Tween 驱动 _flight_progress，_process 沿 lerp+sin 弧线
##   移动；倒计时（fuse_time）从抛射瞬间（launch）开始。
## - 落地：freeze=false 转物理（可被弹珠推动、与敌人物理碰撞弹开），
##   落地瞬间清空速度；后续被推才有速度。
## - 视觉：落地后红光闪烁，越接近爆炸周期越短（Time.get_ticks_msec 抗 time_scale）。
## - 出台：镜像 small_bomb_marble，检测 TableBase/KillZone，contained 则自毁不炸。
## - 爆炸：走 ExplosionContext 事务管线（modify_explosion → finalize → 伤害 →
##   VFX），【不扣弹药】【不触发 on_explosion_resolved】；ammo_before 读真实
##   弹药数快照，使背水/倾泻等数值遗物生效。RadialDamage 以 is_skill=true 结算。

const AmmoStateScript: GDScript = preload("res://Combat/ammo/ammo_state.gd")
const ExplosionContextScript: GDScript = preload("res://Combat/explosion/explosion_context.gd")
const RadialDamageScript: GDScript = preload("res://Combat/explosion/radial_damage.gd")
const ExplosionEffectScene: PackedScene = preload("res://Combat/effects/explosion_effect/explosion_effect.tscn")

const STAT_ENTITY: String = "marble_chain"
const EXPLOSION_RADIUS_STAT: String = "explosion_radius"
const EXPLOSION_RADIUS_BASELINE: float = 75.0
const FALL_CHECK_INTERVAL: float = 0.2

var _start_pos: Vector2 = Vector2.ZERO
var _end_pos: Vector2 = Vector2.ZERO
var _arc_height: float = 60.0
var _flight_progress: float = 0.0
var _flying: bool = false
var _landed: bool = false
var _exploded: bool = false
var _fuse_time: float = 3.0
var _base_damage: int = 12
var _blast_radius: float = 70.0

var _ammo_state: Node = null
var _effect_manager: Node = null
var _kill_zone: Node = null
var _fall_check_timer: float = 0.0

@onready var _fuse_timer: Timer = $FuseTimer
@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group(&"skill_projectiles")
	_effect_manager = _get_autoload_node(&"EffectManager")


## 从 launch 时的 global_position 抛向 target，倒计时即刻开始。
func launch(target: Vector2, definition: SkillDefinition) -> void:
	_start_pos = global_position
	_end_pos = target
	_arc_height = maxf(0.0, definition.aim_arc_height)
	_base_damage = maxi(0, definition.base_damage)
	_blast_radius = maxf(0.0, definition.blast_radius)
	_fuse_time = maxf(0.1, definition.fuse_time)
	_flight_progress = 0.0
	_flying = true
	_landed = false
	freeze = true
	if _fuse_timer != null:
		_fuse_timer.start(_fuse_time)
	var flight_duration: float = maxf(0.05, definition.flight_duration)
	var tween: Tween = create_tween()
	tween.tween_property(self, "_flight_progress", 1.0, flight_duration)
	tween.tween_callback(_on_landed)


func set_ammo_state(ammo: Node) -> void:
	_ammo_state = ammo


func _process(_delta: float) -> void:
	if _exploded:
		return
	if _flying:
		_update_arc_position()
	elif _landed:
		_update_flash()


func _physics_process(delta: float) -> void:
	if not _landed or _exploded:
		return
	_fall_check_timer -= delta
	if _fall_check_timer <= 0.0:
		_fall_check_timer = FALL_CHECK_INTERVAL
		_check_kill_zone()


func _update_arc_position() -> void:
	var t: float = clampf(_flight_progress, 0.0, 1.0)
	var linear_pos: Vector2 = _start_pos.lerp(_end_pos, t)
	var arc_offset: float = -_arc_height * sin(PI * t)
	global_position = linear_pos + Vector2(0.0, arc_offset)


## 动画结束：落地无速度，转入物理（后续被弹珠推动才有速度）。
func _on_landed() -> void:
	if _exploded:
		return
	_flying = false
	_landed = true
	freeze = false
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_fall_check_timer = 0.0
	_check_kill_zone()


## 红光闪烁：剩余时间越少周期越短。fmod(Time.get_ticks_msec()) 抗 time_scale。
func _update_flash() -> void:
	if _sprite == null:
		return
	var remaining: float = _fuse_timer.time_left if _fuse_timer != null else 0.0
	var progress: float = clampf(1.0 - remaining / maxf(0.001, _fuse_time), 0.0, 1.0)
	var period: float = lerpf(0.35, 0.08, progress)
	var blink_on: bool = fmod(Time.get_ticks_msec() / 1000.0, period) < period * 0.5
	_sprite.modulate = Color(1.0, 0.3, 0.3, 1.0) if blink_on else Color.WHITE


func _on_fuse_timer_timeout() -> void:
	_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var center: Vector2 = global_position
	var context: ExplosionContext = ExplosionContextScript.new() as ExplosionContext
	context.center = center
	context.base_damage = _base_damage
	context.base_radius = _blast_radius + _radius_stat_bonus()
	var ammo := _get_ammo_state()
	context.ammo_before = ammo.get_ammo() if ammo != null else 0
	if _effect_manager != null and _effect_manager.has_method(&"modify_explosion"):
		_effect_manager.call(&"modify_explosion", context)
	var resolved: Dictionary = context.finalize()
	# 【跳过】ammo_state.consume：技能不吃弹药。
	if _effect_manager != null and _effect_manager.has_method(&"on_explosion"):
		_effect_manager.call(&"on_explosion", center, float(resolved["radius"]))
	RadialDamageScript.damage_enemies_in_radius(
		center,
		float(resolved["radius"]),
		int(resolved["damage"]),
		false,
		true,
		true  # is_skill
	)
	_spawn_explosion_effect(center, float(resolved["radius"]), context.base_radius)
	# 【跳过】on_explosion_resolved：高爆不产小炸弹、回收器不补弹。
	queue_free()


## 特效缩放 = 实际半径/基础半径：背水/倾泻的半径放大同步放大视觉。
func _spawn_explosion_effect(center: Vector2, radius: float, base_radius: float) -> void:
	var scene: Node = Engine.get_main_loop().current_scene
	if scene == null:
		return
	var effect: Node2D = ExplosionEffectScene.instantiate() as Node2D
	scene.add_child(effect)
	effect.global_position = center
	var effect_scale: float = _get_stat_float(&"explosion_effect_scale", 1.0)
	if base_radius > 0.0:
		effect_scale *= radius / base_radius
	effect.scale = Vector2(effect_scale, effect_scale)


## 出台自毁（不爆炸）：缓存父场景 TableBase/KillZone 引用，contained 即销毁。
func _check_kill_zone() -> void:
	if _kill_zone == null or not is_instance_valid(_kill_zone):
		_find_kill_zone()
	if _kill_zone == null or not is_instance_valid(_kill_zone):
		return
	if not _kill_zone.has_method(&"contains_global_point"):
		return
	if bool(_kill_zone.call(&"contains_global_point", global_position)):
		queue_free()


func _find_kill_zone() -> void:
	var parent := get_parent()
	if parent == null:
		return
	_kill_zone = parent.get_node_or_null(NodePath("TableBase/KillZone"))


func _get_ammo_state() -> Node:
	if _ammo_state != null and is_instance_valid(_ammo_state):
		return _ammo_state
	return AmmoStateScript.find_current()


## 技能数值享受炸弹 stat：explosion_radius 超过基线 75 的增量并入技能半径。
## 不吃 explosion_damage（base_damage 技能自带）。
func _radius_stat_bonus() -> float:
	var stat_value: float = _get_stat_float(EXPLOSION_RADIUS_STAT, EXPLOSION_RADIUS_BASELINE)
	return maxf(0.0, stat_value - EXPLOSION_RADIUS_BASELINE)


func _get_stat_float(stat_id: StringName, fallback: float) -> float:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return fallback
	var stat_system: Node = tree.root.get_node_or_null(NodePath(&"StatSystem"))
	if stat_system == null or not stat_system.has_method(&"get_stat"):
		return fallback
	return float(stat_system.call(&"get_stat", String(stat_id), STAT_ENTITY))


func _get_autoload_node(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(node_name)))
