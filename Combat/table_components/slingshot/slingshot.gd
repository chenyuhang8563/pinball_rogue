class_name Slingshot
extends Node2D

signal component_activated(component_id: StringName, marble: Marble)

@export var component_id: StringName = &""
@export_range(0.0, 600.0, 1.0) var minimum_entry_speed: float = 90.0
@export_range(-1.0, 1.0, 0.01) var toward_origin_dot_threshold: float = 0.5
@export_range(1.0, 1000.0, 1.0) var target_speed: float = 420.0
@export_range(1.0, 1000.0, 1.0) var maximum_speed: float = 560.0
@export_range(0.0, 2.0, 0.01) var cooldown_seconds: float = 0.35
@export_range(0.0, 1.0, 0.01) var visual_activation_seconds: float = 0.08

@onready var kick_sensor: Area2D = $KickSensor
@onready var kick_origin: Marker2D = $KickOrigin
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _cooldowns: Dictionary[int, float] = {}


func _ready() -> void:
	add_to_group(&"table_component")
	if not kick_sensor.body_entered.is_connected(_on_kick_sensor_body_entered):
		kick_sensor.body_entered.connect(_on_kick_sensor_body_entered)


func _exit_tree() -> void:
	remove_from_group(&"table_component")
	if kick_sensor != null and kick_sensor.body_entered.is_connected(_on_kick_sensor_body_entered):
		kick_sensor.body_entered.disconnect(_on_kick_sensor_body_entered)


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
	if _cooldowns.has(head.get_instance_id()) or head.linear_velocity.length() < minimum_entry_speed:
		return false
	var to_origin := kick_origin.global_position - head.global_position
	return not to_origin.is_zero_approx() and head.linear_velocity.normalized().dot(to_origin.normalized()) >= toward_origin_dot_threshold


func activate(marble: Node) -> bool:
	if not can_activate(marble):
		return false
	var head: Marble = marble as Marble
	var reaction_direction := (head.global_position - kick_origin.global_position).normalized()
	var target_velocity := reaction_direction * target_speed
	if target_velocity.length() > maximum_speed:
		target_velocity = target_velocity.limit_length(maximum_speed)
	head.set_sleeping(false)
	head.apply_central_impulse(target_velocity - head.linear_velocity)
	_cooldowns[head.get_instance_id()] = cooldown_seconds
	if animation_player != null and animation_player.has_animation(&"activate"):
		if visual_activation_seconds <= 0.0:
			animation_player.stop()
		else:
			var activation_animation: Animation = animation_player.get_animation(&"activate")
			var playback_speed := 1.0
			if activation_animation != null and activation_animation.length > 0.0:
				playback_speed = activation_animation.length / visual_activation_seconds
			animation_player.play(&"activate", -1.0, playback_speed)
	component_activated.emit(component_id, head)
	return true


func _on_kick_sensor_body_entered(body: Node) -> void:
	activate(body)


func _is_head_marble(body: Node) -> bool:
	return body is Marble and (body as Marble).is_head and body.is_in_group(&"marbles")
