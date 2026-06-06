extends RigidBody2D
class_name Marble

@export var damage: int = 1
@export var max_speed := 800.0

enum MARBLE_TYPE {
    DEFAULT,
    BROWN,
    BOMB
}

@export var marble_type: MARBLE_TYPE = MARBLE_TYPE.DEFAULT

var init_position: Vector2

func _ready() -> void:
    init_position = position

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
    if state.linear_velocity.length() > max_speed:
        state.linear_velocity = state.linear_velocity.normalized() * max_speed

func get_hit_damage(_target: Node) -> int:
    return damage
