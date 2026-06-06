extends Node2D

@export var keycode = "ui_left"

@export var snap_time = 0.25
@export var snap_angle = 90
@export var kick_impulse = 50.0

var tween: Tween
var is_raised := false
var is_flipping_up := false
var kicked_this_swing: Dictionary = {}

@onready var flipper_body: RigidBody2D = $RigidBody2D

func _ready() -> void:
	flipper_body.contact_monitor = true
	flipper_body.max_contacts_reported = 8

func _physics_process(_delta: float) -> void:
	if Input.is_action_pressed(keycode):
		if not is_raised:
			_flip_to(snap_angle)
			is_raised = true
			is_flipping_up = true
			kicked_this_swing.clear()
		_kick_touching_marbles()
	else:
		if is_raised:
			_flip_to(0.0)
			is_raised = false
			is_flipping_up = false

func _flip_to(target_angle: float) -> void:
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(flipper_body, "rotation_degrees", target_angle, snap_time)
	if target_angle == snap_angle:
		tween.finished.connect(func() -> void: is_flipping_up = false)

func _kick_touching_marbles() -> void:
	if not is_flipping_up:
		return

	for body in flipper_body.get_colliding_bodies():
		var marble := body as RigidBody2D
		if marble == null or not marble.is_in_group("marbles"):
			continue
		if kicked_this_swing.has(marble.get_instance_id()):
			continue

		var pivot_to_marble := marble.global_position - global_position
		var tangent := Vector2(-pivot_to_marble.y, pivot_to_marble.x) * signf(snap_angle)
		var kick_direction := tangent.normalized()
		marble.apply_central_impulse(kick_direction * kick_impulse)
		kicked_this_swing[marble.get_instance_id()] = true
