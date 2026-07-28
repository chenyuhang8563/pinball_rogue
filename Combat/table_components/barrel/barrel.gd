class_name Barrel
extends StaticBody2D

## 每次 Head 碰撞发一次；掉落导演据此生成一枚金币。
signal barrel_hit(barrel: Barrel, drop_anchor: Marker2D)
## 累计碰撞达到 max_hits 后发一次；桶进入终局破碎态。
signal barrel_broken(barrel: Barrel)

enum State {
	INTACT,
	BROKEN,
}

@export var component_id: StringName = &""
@export_range(1, 99, 1) var max_hits: int = 20

@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var impact_sensor: Area2D = $ImpactSensor
@onready var drop_anchor: Marker2D = $DropAnchor
@onready var break_animation: AnimationPlayer = $BreakAnimation

var _state: State = State.INTACT
var _hits_taken: int = 0


func _ready() -> void:
	add_to_group(&"table_component")
	if not impact_sensor.body_entered.is_connected(_on_impact_sensor_body_entered):
		impact_sensor.body_entered.connect(_on_impact_sensor_body_entered)


func _exit_tree() -> void:
	remove_from_group(&"table_component")
	if impact_sensor != null and impact_sensor.body_entered.is_connected(_on_impact_sensor_body_entered):
		impact_sensor.body_entered.disconnect(_on_impact_sensor_body_entered)


## 记录一次 Head 碰撞：发 barrel_hit 掉一枚币；累计满 max_hits 时破碎。
## 无速度与角度门槛——任何有效碰撞都计数。
func register_hit(marble: Node) -> bool:
	if _state != State.INTACT or not _is_head_marble(marble):
		return false
	_hits_taken += 1
	barrel_hit.emit(self, drop_anchor)
	if _hits_taken >= max_hits:
		_break()
	return true


func hits_taken() -> int:
	return _hits_taken


func state() -> State:
	return _state


func _break() -> void:
	_state = State.BROKEN
	body_collision.set_deferred(&"disabled", true)
	impact_sensor.set_deferred(&"monitoring", false)
	barrel_broken.emit(self)
	if break_animation != null and break_animation.has_animation(&"break"):
		break_animation.play(&"break")


func _on_impact_sensor_body_entered(body: Node) -> void:
	register_hit(body)


func _is_head_marble(body: Node) -> bool:
	return body is Marble and (body as Marble).is_head and body.is_in_group(&"marbles")
