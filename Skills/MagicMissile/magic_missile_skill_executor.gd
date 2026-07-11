extends Node

const AimIndicatorScene: PackedScene = preload("res://Skills/MagicMissile/magic_missile_aim_indicator.tscn")
const MissileScene: PackedScene = preload("res://Skills/MagicMissile/magic_missile.tscn")

var _indicator: MagicMissileAimIndicator = null
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
	var indicator: MagicMissileAimIndicator = AimIndicatorScene.instantiate() as MagicMissileAimIndicator
	if indicator == null:
		return false
	_saved_time_scale = Engine.time_scale
	_has_saved_time_scale = true
	_head = head
	parent.add_child(indicator)
	_indicator = indicator
	_indicator.configure(head, definition.aim_rotation_speed_degrees, definition.aim_radius)
	Engine.time_scale = definition.aiming_time_scale
	return true


func release_aim(controller: Node, definition: SkillDefinition) -> bool:
	if not is_aiming() or not _indicator.has_valid_target() or not is_instance_valid(_head):
		cancel_aim()
		return false
	var direction: Vector2 = _indicator.get_fire_direction()
	var spawn_position: Vector2 = _head.global_position + direction * definition.spawn_safe_offset
	var shooter: PhysicsBody2D = _head
	var parent: Node = controller.call("get_projectile_parent") as Node
	cancel_aim()
	if parent == null or direction.is_zero_approx():
		return false
	var missile: MagicMissile = MissileScene.instantiate() as MagicMissile
	if missile == null:
		return false
	parent.add_child(missile)
	missile.global_position = spawn_position
	if not missile.initialize(
		direction,
		definition.base_damage,
		definition.projectile_speed,
		definition.projectile_lifetime,
		shooter
	):
		missile.queue_free()
		return false
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
	return _indicator.get_fire_direction() if is_aiming() else Vector2.ZERO


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
