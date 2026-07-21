extends RigidBody2D
class_name MagicMissile

@export var damage: int = 10
@export var launch_speed: float = 220.0
@export var max_lifetime: float = 4.0

var _shooter: PhysicsBody2D = null
var _damaged_enemy_ids: Dictionary = {}

@onready var _lifetime_timer: Timer = $LifetimeTimer
@onready var _safety_timer: Timer = $SafetyTimer


func _ready() -> void:
	add_to_group("skill_projectiles")


func initialize(
	direction: Vector2,
	p_damage: int,
	p_speed: float,
	p_lifetime: float,
	shooter: PhysicsBody2D = null
) -> bool:
	if direction.is_zero_approx():
		return false
	damage = maxi(0, p_damage)
	launch_speed = maxf(0.0, p_speed)
	max_lifetime = maxf(0.05, p_lifetime)
	_shooter = shooter
	rotation = direction.angle()
	linear_velocity = direction.normalized() * launch_speed
	set_sleeping(false)
	if is_instance_valid(_shooter):
		add_collision_exception_with(_shooter)
		_safety_timer.start()
	_lifetime_timer.start(max_lifetime)
	return true


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not state.linear_velocity.is_zero_approx():
		var body_transform := state.transform
		body_transform = Transform2D(state.linear_velocity.angle(), body_transform.origin)
		state.transform = body_transform


func _on_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group("enemies"):
		return
	var instance_id: int = body.get_instance_id()
	if _damaged_enemy_ids.has(instance_id):
		return
	_damaged_enemy_ids[instance_id] = true
	if not body.has_method("take_damage"):
		return
	body.call("take_damage", damage, Color(0.55, 0.75, 1.0, 1.0))


func _on_safety_timer_timeout() -> void:
	if is_instance_valid(_shooter):
		remove_collision_exception_with(_shooter)
	_shooter = null


func _on_lifetime_timer_timeout() -> void:
	queue_free()


func has_shooter_exception() -> bool:
	return is_instance_valid(_shooter)
