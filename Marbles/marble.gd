extends RigidBody2D
class_name Marble

@export var damage: int = 1
@export var max_speed := 800.0

@export var dash_impulse: float = 200.0
@export var dash_max_speed: float = 850.0
@export var dash_duration: float = 0.3

enum MARBLE_TYPE {
    DEFAULT,
    BROWN,
    BOMB
}

@export var marble_type: MARBLE_TYPE = MARBLE_TYPE.DEFAULT

var init_position: Vector2
var _dash_active: bool = false
var _dash_timer: Timer


func _ready() -> void:
    init_position = position
    _dash_timer = Timer.new()
    _dash_timer.one_shot = true
    _dash_timer.timeout.connect(_on_dash_timer_timeout)
    add_child(_dash_timer)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
    var speed_limit: float = dash_max_speed if _dash_active else max_speed
    if state.linear_velocity.length() > speed_limit:
        state.linear_velocity = state.linear_velocity.normalized() * speed_limit


func get_hit_damage(_target: Node) -> int:
    return damage


func dash_toward(direction: Vector2) -> void:
    if _dash_active:
        return
    _dash_active = true
    # Clear existing velocity so the impulse isn't diluted by prior momentum.
    linear_velocity = Vector2.ZERO
    apply_central_impulse(direction * dash_impulse)
    _dash_timer.start(dash_duration)


func _on_dash_timer_timeout() -> void:
    _dash_active = false
