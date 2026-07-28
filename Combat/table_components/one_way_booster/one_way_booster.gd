class_name OneWayBooster
extends StaticBody2D

signal component_activated(component_id: StringName, marble: Marble)

@export var component_id: StringName = &""
@export var forward_local: Vector2 = Vector2.UP
@export_range(0.0, 600.0, 1.0) var added_speed: float = 180.0
@export_range(1.0, 1000.0, 1.0) var maximum_speed: float = 520.0
@export_range(0.0, 2.0, 0.01) var cooldown_seconds: float = 0.18
@export_range(0.0, 600.0, 1.0) var minimum_speed: float = 60.0
@export_range(-1.0, 1.0, 0.01) var front_dot_threshold: float = 0.35

@onready var front_trigger: Area2D = $FrontTrigger

var _cooldowns: Dictionary[int, float] = {}


func _ready() -> void:
	add_to_group(&"table_component")
	if not front_trigger.body_entered.is_connected(_on_front_trigger_body_entered):
		front_trigger.body_entered.connect(_on_front_trigger_body_entered)


func _exit_tree() -> void:
	remove_from_group(&"table_component")
	if front_trigger != null and front_trigger.body_entered.is_connected(_on_front_trigger_body_entered):
		front_trigger.body_entered.disconnect(_on_front_trigger_body_entered)


func _physics_process(delta: float) -> void:
	for marble_id: int in _cooldowns.keys():
		var remaining: float = _cooldowns[marble_id] - delta
		if remaining <= 0.0:
			_cooldowns.erase(marble_id)
		else:
			_cooldowns[marble_id] = remaining


func can_activate(marble: Node) -> bool:
	if not _is_head_marble(marble):
		return false
	var head: Marble = marble as Marble
	if _cooldowns.has(head.get_instance_id()) or head.linear_velocity.length() < minimum_speed:
		return false
	var forward := forward_local.rotated(global_rotation).normalized()
	return not forward.is_zero_approx() and (-head.linear_velocity.normalized()).dot(forward) >= front_dot_threshold


func activate(marble: Node) -> bool:
	if not can_activate(marble):
		return false
	var head: Marble = marble as Marble
	var forward := forward_local.rotated(global_rotation).normalized()
	var target_speed := minf(head.linear_velocity.length() + added_speed, maximum_speed)
	var target_velocity := forward * target_speed
	head.set_sleeping(false)
	head.apply_central_impulse(target_velocity - head.linear_velocity)
	_cooldowns[head.get_instance_id()] = cooldown_seconds
	component_activated.emit(component_id, head)
	return true


func _on_front_trigger_body_entered(body: Node) -> void:
	activate(body)


func _is_head_marble(body: Node) -> bool:
	return body is Marble and (body as Marble).is_head and body.is_in_group(&"marbles")
