extends Node
## 抛射炸弹技能 executor —— HOLD_RELEASE 激活。
##
## 按住技能键进入慢镜头瞄准：只显示鼠标抛物线预览（无方向箭头），松手时从
## 弹珠 Head 位置抛出一颗实体炸弹。倒计时从松手抛射瞬间开始，落地后红光
## 随剩余时间加速闪烁，导火索结束走爆炸事务管线结算。
##
## 弹药规则：瞄准/抛射/爆炸都不 consume 弹药，但读真实弹药数写入
## ExplosionContext.ammo_before，使背水一击/弹药倾泻等 modify_explosion 类
## 数值遗物按弹药快照生效。

const AimIndicatorScene: PackedScene = preload("res://Combat/skills/DemolitionCharge/demolition_charge_aim_indicator.tscn")
const BombScene: PackedScene = preload("res://Combat/skills/DemolitionCharge/demolition_charge_bomb.tscn")

var _indicator: DemolitionChargeAimIndicator = null
var _head: PhysicsBody2D = null
var _saved_time_scale: float = 1.0
var _has_saved_time_scale: bool = false


func begin_aim(controller: Node, definition: SkillDefinition) -> bool:
	if is_aiming() or controller == null or definition == null:
		return false
	var head: PhysicsBody2D = controller.call("get_active_head") as PhysicsBody2D
	var parent: Node = controller.call("get_projectile_parent") as Node
	if head == null or not is_instance_valid(head) or parent == null:
		return false
	var indicator: DemolitionChargeAimIndicator = AimIndicatorScene.instantiate() as DemolitionChargeAimIndicator
	if indicator == null:
		return false
	_saved_time_scale = Engine.time_scale
	_has_saved_time_scale = true
	_head = head
	parent.add_child(indicator)
	_indicator = indicator
	_indicator.configure(
		head,
		definition.aim_max_distance,
		definition.aim_arc_height,
		definition.aim_arc_steps
	)
	Engine.time_scale = definition.aiming_time_scale
	return true


func release_aim(controller: Node, definition: SkillDefinition) -> bool:
	if not is_aiming() or not _indicator.has_valid_target() or not is_instance_valid(_head):
		cancel_aim()
		return false
	var start_position: Vector2 = _head.global_position
	var target: Vector2 = _indicator.get_aim_target()
	var parent: Node = controller.call("get_projectile_parent") as Node
	cancel_aim()
	if parent == null or start_position.distance_to(target) < 0.5:
		return false
	var bomb: DemolitionChargeBomb = BombScene.instantiate() as DemolitionChargeBomb
	if bomb == null:
		return false
	parent.add_child(bomb)
	bomb.global_position = start_position
	bomb.launch(target, definition)
	return true


func cancel_aim() -> void:
	if _indicator != null and is_instance_valid(_indicator):
		var parent := _indicator.get_parent()
		if parent != null:
			parent.remove_child(_indicator)
		_indicator.free()
	_indicator = null
	_head = null
	_restore_time_scale()


func is_aiming() -> bool:
	return _indicator != null and is_instance_valid(_indicator)


func has_valid_aim_target() -> bool:
	return is_aiming() and _indicator.has_valid_target()


func get_aim_direction() -> Vector2:
	if is_aiming() and is_instance_valid(_head):
		return (_indicator.get_aim_target() - _head.global_position).normalized()
	return Vector2.ZERO


func _exit_tree() -> void:
	if _indicator != null and is_instance_valid(_indicator):
		_indicator.queue_free()
	_indicator = null
	_head = null
	_restore_time_scale()


func _restore_time_scale() -> void:
	if not _has_saved_time_scale:
		return
	Engine.time_scale = _saved_time_scale
	_has_saved_time_scale = false
