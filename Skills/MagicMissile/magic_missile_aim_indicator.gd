extends Node2D
class_name MagicMissileAimIndicator

@export var rotation_speed_degrees: float = 540.0
@export var orbit_radius: float = 20.0

var _target: Node2D = null
var _last_ticks_usec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_ticks_usec = Time.get_ticks_usec()
	_apply_orbit_radius()


func configure(target: Node2D, speed_degrees: float, radius: float) -> void:
	_target = target
	rotation_speed_degrees = speed_degrees
	orbit_radius = radius
	_apply_orbit_radius()
	if is_instance_valid(_target):
		global_position = _target.global_position
	_last_ticks_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	if not is_instance_valid(_target):
		return
	var now_usec: int = Time.get_ticks_usec()
	var real_delta: float = float(now_usec - _last_ticks_usec) / 1_000_000.0
	_last_ticks_usec = now_usec
	global_position = _target.global_position
	rotation = fposmod(rotation + deg_to_rad(rotation_speed_degrees) * real_delta, TAU)


func get_fire_direction() -> Vector2:
	return Vector2.RIGHT.rotated(global_rotation).normalized()


func has_valid_target() -> bool:
	return is_instance_valid(_target) and _target.is_inside_tree()


func _apply_orbit_radius() -> void:
	var arrow: Sprite2D = get_node_or_null("Arrow") as Sprite2D
	if arrow != null:
		arrow.position = Vector2(orbit_radius, 0.0)

