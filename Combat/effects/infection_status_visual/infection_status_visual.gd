extends Node2D
class_name InfectionStatusVisual

## Decorative orbiting-fly markers for an infected enemy. The fly sprites live under
## an Orbit node that spins each frame; the body tint is applied by the enemy itself
## (Enemy.set_infection_visual). Infection state is owned by InfectionDebuff — this
## node is purely cosmetic.

@export var orbit_speed: float = 2.6

@onready var orbit: Node2D = $Orbit


func _process(delta: float) -> void:
	if orbit != null:
		orbit.rotation += orbit_speed * delta
