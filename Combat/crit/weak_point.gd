class_name WeakPoint
extends RefCounted

## Value object describing a single directional weak point on an enemy.
##
## Directions map to the angle (in degrees) of the direction vector measured from
## the enemy center, in the enemy's LOCAL space (Godot's +X is 0deg, +Y/down is
## 90deg). WeakPointHost resolves hits by comparing the contact angle against these
## centers within a tolerance.

enum Direction {
	UP,
	RIGHT,
	DOWN,
	LEFT,
}

enum Kind {
	BASE,
	PRISM,
}

const CENTER_ANGLE_DEG: Dictionary = {
	Direction.UP: -90.0,
	Direction.RIGHT: 0.0,
	Direction.DOWN: 90.0,
	Direction.LEFT: 180.0,
}

var direction: Direction = Direction.UP
var kind: Kind = Kind.BASE
## Remaining lifetime in seconds. Negative means infinite (base weak points).
var remaining_time: float = -1.0
var total_time: float = -1.0


func _init(
	p_direction: Direction = Direction.UP,
	p_kind: Kind = Kind.BASE,
	p_remaining_time: float = -1.0
) -> void:
	direction = p_direction
	kind = p_kind
	remaining_time = p_remaining_time
	total_time = p_remaining_time


func center_angle_deg() -> float:
	return float(CENTER_ANGLE_DEG.get(direction, 0.0))


func is_permanent() -> bool:
	return remaining_time < 0.0
