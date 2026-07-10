extends Node

@export var floating_text_scene: PackedScene = preload("res://UI/floating_text.tscn")

var _available: Array[Node2D] = []
var _active: Array[Node2D] = []


func show_damage(damage_amount: int, spawn_position: Vector2) -> Node2D:
	var text: Node2D = _obtain_text()
	if text == null:
		return null
	if text.get_parent() == null:
		add_child(text)
	text.global_position = spawn_position
	_active.append(text)
	text.call("display_damage_text", damage_amount)
	return text


func get_active_count() -> int:
	return _active.size()


func get_available_count() -> int:
	return _available.size()


func release_text(text: Node2D) -> void:
	if text == null or not is_instance_valid(text):
		return
	_active.erase(text)
	if not _available.has(text):
		_available.append(text)


func _obtain_text() -> Node2D:
	if not _available.is_empty():
		return _available.pop_back()
	if floating_text_scene == null:
		push_warning("FloatDamageTextPool needs a floating_text_scene.")
		return null
	var text: Node2D = floating_text_scene.instantiate() as Node2D
	if text == null:
		push_warning("FloatDamageTextPool can only pool Node2D scenes.")
		return null
	_connect_finished_signal(text)
	return text


func _connect_finished_signal(text: Node2D) -> void:
	if not text.has_signal(&"animation_finished"):
		return
	var release_callable: Callable = Callable(self, "_on_text_animation_finished").bind(text)
	if not text.is_connected(&"animation_finished", release_callable):
		text.connect(&"animation_finished", release_callable)


func _on_text_animation_finished(text: Node2D) -> void:
	release_text(text)
