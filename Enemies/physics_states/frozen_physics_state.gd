class_name FrozenEnemyPhysicsState
extends "res://Enemies/physics_states/physics_state.gd"

var _snapshot: Dictionary = {}
var _captured: bool = false


func enter(_payload: Dictionary = {}) -> void:
	if enemy == null:
		return
	if _captured:
		return
	_snapshot = {
		"freeze": enemy.freeze,
		"freeze_mode": enemy.freeze_mode,
		"gravity_scale": enemy.gravity_scale,
		"lock_rotation": enemy.lock_rotation,
	}
	_captured = true
	enemy.set_deferred("gravity_scale", 0.0)
	enemy.set_deferred("freeze", false)
	enemy.set_deferred("lock_rotation", true)
	enemy.call_deferred("set_sleeping", false)


func exit() -> void:
	if enemy == null or not _captured:
		return
	if enemy.has_method("restore_frozen_physics_snapshot"):
		enemy.call_deferred("restore_frozen_physics_snapshot", _snapshot)
	_captured = false
	_snapshot = {}
