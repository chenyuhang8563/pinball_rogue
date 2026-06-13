extends Node2D

@export var keycode = "ui_left"

@export var snap_angle = 90
@export var raise_degrees_per_second := 700.0
@export var return_degrees_per_second := 700.0
@export_range(0.0, 1.0, 0.05) var easing_strength := 0.35

@onready var flipper_body: AnimatableBody2D = $FlipperBody

var _motion_start_angle := 0.0
var _motion_target_angle := 0.0
var _motion_elapsed := 0.0
var _motion_duration := 0.0

func _physics_process(delta: float) -> void:
	var target_angle := 0.0
	var degrees_per_second := return_degrees_per_second

	if Input.is_action_pressed(keycode):
		target_angle = snap_angle
		degrees_per_second = raise_degrees_per_second

	_step_rotation_toward(target_angle, degrees_per_second, delta)


func _step_rotation_toward(target_angle: float, degrees_per_second: float, delta: float) -> void:
	if not is_equal_approx(_motion_target_angle, target_angle):
		_begin_motion(target_angle, degrees_per_second)

	if _motion_duration <= 0.0:
		flipper_body.rotation_degrees = target_angle
		return

	_motion_elapsed = minf(_motion_elapsed + delta, _motion_duration)
	var progress := _motion_elapsed / _motion_duration
	flipper_body.rotation_degrees = _get_eased_rotation(_motion_start_angle, target_angle, progress, easing_strength)


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
