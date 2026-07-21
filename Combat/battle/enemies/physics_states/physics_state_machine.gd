class_name EnemyPhysicsStateMachine
extends Node

@export var initial_state_name: StringName = &"Normal"

var current_state: Node = null
var states: Dictionary = {}


func _ready() -> void:
	for child in get_children():
		if child.has_method("enter") and child.has_method("exit"):
			states[StringName(child.name)] = child
			child.set("enemy", owner as RigidBody2D)
			child.set("state_machine", self)
	transition_to(initial_state_name)


func transition_to(state_name: StringName, payload: Dictionary = {}) -> void:
	if current_state != null and StringName(current_state.name) == state_name:
		current_state.call("enter", payload)
		return
	if not states.has(state_name):
		push_error("EnemyPhysicsStateMachine: unknown state '%s'" % state_name)
		return
	if current_state != null:
		current_state.call("exit")
	current_state = states[state_name] as Node
	current_state.call("enter", payload)


func _physics_process(delta: float) -> void:
	if current_state != null:
		current_state.call("physics_update", delta)
