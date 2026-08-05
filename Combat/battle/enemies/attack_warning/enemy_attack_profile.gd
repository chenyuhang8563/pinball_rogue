class_name EnemyAttackProfile
extends Resource

@export var warning_radius: float = 0.0
@export var warning_angle_degrees: float = 0.0
@export var fill_seconds: float = 0.0
@export var damage: int = 0
@export var attack_cooldown_seconds: float = 0.0
@export var stun_seconds: float = 0.0
@export var interrupt_immunity_seconds: float = 0.0
@export var knockback_impulse: float = 0.0


func is_valid() -> bool:
	return (
		warning_radius > 0.0
		and warning_angle_degrees > 0.0
		and warning_angle_degrees <= 360.0
		and fill_seconds > 0.0
		and damage > 0
		and attack_cooldown_seconds >= 0.0
		and stun_seconds >= 0.0
		and interrupt_immunity_seconds >= 0.0
		and knockback_impulse >= 0.0
	)
