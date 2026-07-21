extends Node2D

@export var keycode = "ui_left"

@export var snap_angle = 90
@export var raise_degrees_per_second := 700.0
@export var return_degrees_per_second := 700.0
@export_range(0.0, 1.0, 0.05) var easing_strength := 0.35
@export var hit_impulse_multiplier := 0.18
@export var min_hit_impulse := 80.0
@export var max_hit_impulse := 360.0
@export var hit_cooldown := 0.08

@onready var flipper_body: AnimatableBody2D = $FlipperBody
@onready var hit_sensor: Area2D = $FlipperBody/HitSensor

var _motion_start_angle := 0.0
var _motion_target_angle := 0.0
var _motion_elapsed := 0.0
var _motion_duration := 0.0
var _angular_velocity := 0.0
var _hit_cooldowns: Dictionary = {}

func _physics_process(delta: float) -> void:
	_tick_hit_cooldowns(delta)

	var target_angle := 0.0
	var degrees_per_second := return_degrees_per_second

	if Input.is_action_pressed(keycode):
		target_angle = snap_angle
		degrees_per_second = raise_degrees_per_second

	_step_rotation_toward(target_angle, degrees_per_second, delta)
	_apply_swing_impulse_to_overlapping_marbles()


func _step_rotation_toward(target_angle: float, degrees_per_second: float, delta: float) -> void:
	if not is_equal_approx(_motion_target_angle, target_angle):
		_begin_motion(target_angle, degrees_per_second)

	if _motion_duration <= 0.0:
		var instant_previous_rotation := flipper_body.rotation
		flipper_body.rotation_degrees = target_angle
		_update_angular_velocity(instant_previous_rotation, flipper_body.rotation, delta)
		return

	var previous_rotation := flipper_body.rotation
	_motion_elapsed = minf(_motion_elapsed + delta, _motion_duration)
	var progress := _motion_elapsed / _motion_duration
	flipper_body.rotation_degrees = _get_eased_rotation(_motion_start_angle, target_angle, progress, easing_strength)
	_update_angular_velocity(previous_rotation, flipper_body.rotation, delta)


func _begin_motion(target_angle: float, degrees_per_second: float) -> void:
	_motion_start_angle = flipper_body.rotation_degrees
	_motion_target_angle = target_angle
	_motion_elapsed = 0.0

	var distance := absf(target_angle - _motion_start_angle)
	if is_zero_approx(degrees_per_second):
		_motion_duration = 0.0
	else:
		_motion_duration = distance / absf(degrees_per_second)


func _get_step_limited_rotation(current_angle: float, target_angle: float, degrees_per_second: float, delta: float) -> float:
	var max_step := absf(degrees_per_second) * delta
	return move_toward(current_angle, target_angle, max_step)


func _get_eased_rotation(start_angle: float, target_angle: float, progress: float, strength: float) -> float:
	var linear_progress := clampf(progress, 0.0, 1.0)
	var clamped_strength := clampf(strength, 0.0, 1.0)
	var ease_out_progress := 1.0 - pow(1.0 - linear_progress, 3.0)
	var eased_progress := lerpf(linear_progress, ease_out_progress, clamped_strength)
	return lerpf(start_angle, target_angle, eased_progress)


func _update_angular_velocity(previous_rotation: float, current_rotation: float, delta: float) -> void:
	if delta <= 0.0:
		_angular_velocity = 0.0
		return
	_angular_velocity = angle_difference(previous_rotation, current_rotation) / delta


func _apply_swing_impulse_to_overlapping_marbles() -> void:
	if is_zero_approx(_angular_velocity):
		return

	for body: Node2D in hit_sensor.get_overlapping_bodies():
		var marble := body as Marble
		if marble == null or _is_body_on_hit_cooldown(marble):
			continue
		_apply_swing_impulse(marble)


func _apply_swing_impulse(marble: Marble) -> void:
	var lever := marble.global_position - flipper_body.global_position
	if lever.is_zero_approx():
		return

	var tangent := Vector2(-lever.y, lever.x).normalized() * signf(_angular_velocity)
	var contact_speed := absf(_angular_velocity) * lever.length()
	var impulse_strength := clampf(
		contact_speed * marble.mass * hit_impulse_multiplier,
		min_hit_impulse,
		max_hit_impulse
	)

	marble.set_sleeping(false)
	marble.apply_central_impulse(tangent * impulse_strength)
	_hit_cooldowns[marble.get_instance_id()] = hit_cooldown


func _tick_hit_cooldowns(delta: float) -> void:
	for body_id: int in _hit_cooldowns.keys():
		var remaining := float(_hit_cooldowns[body_id]) - delta
		if remaining <= 0.0:
			_hit_cooldowns.erase(body_id)
		else:
			_hit_cooldowns[body_id] = remaining


func _is_body_on_hit_cooldown(body: Node) -> bool:
	return _hit_cooldowns.has(body.get_instance_id())
