class_name FrozenEnemyPhysicsState
extends "res://Enemies/physics_states/physics_state.gd"

const ICE_FRICTION: float = 0.02
const ICE_BOUNCE: float = 0.08
const ICE_LINEAR_DAMP: float = 0.18
const ICE_ANGULAR_DAMP: float = 8.0

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
		"physics_material_override": enemy.physics_material_override,
		"linear_damp": enemy.linear_damp,
		"linear_damp_mode": enemy.linear_damp_mode,
		"angular_damp": enemy.angular_damp,
		"angular_damp_mode": enemy.angular_damp_mode,
	}
	_captured = true
	var ice_material := PhysicsMaterial.new()
	ice_material.friction = ICE_FRICTION
	ice_material.bounce = ICE_BOUNCE
	enemy.set_deferred("physics_material_override", ice_material)
	enemy.set_deferred("gravity_scale", 0.0)
	enemy.set_deferred("freeze", false)
	enemy.set_deferred("lock_rotation", true)
	enemy.set_deferred("linear_damp", ICE_LINEAR_DAMP)
	enemy.set_deferred("linear_damp_mode", RigidBody2D.DAMP_MODE_REPLACE)
	enemy.set_deferred("angular_damp", ICE_ANGULAR_DAMP)
	enemy.set_deferred("angular_damp_mode", RigidBody2D.DAMP_MODE_REPLACE)
	enemy.call_deferred("set_sleeping", false)


func exit() -> void:
	if enemy == null or not _captured:
		return
	if enemy.has_method("restore_frozen_physics_snapshot"):
		enemy.call_deferred("restore_frozen_physics_snapshot", _snapshot)
	_captured = false
	_snapshot = {}
