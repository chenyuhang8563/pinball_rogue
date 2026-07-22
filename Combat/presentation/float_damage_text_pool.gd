extends Node

@export var floating_text_scene: PackedScene = preload("res://Combat/presentation/floating_text.tscn")
@export var burn_floating_text_scene: PackedScene = preload("res://Combat/presentation/burn_floating_text.tscn")
@export var crit_floating_text_scene: PackedScene = preload("res://Combat/presentation/crit_floating_text.tscn")

var _available: Dictionary = {}
var _active: Array[Node2D] = []


func show_damage(damage_amount: int, spawn_position: Vector2, style: StringName = &"default") -> Node2D:
	var text: Node2D = _obtain_text(style)
	if text == null:
		return null
	if text.get_parent() == null:
		add_child(text)
	# release_all_active() hides in-flight texts during battle transitions;
	# restore visibility whenever a pooled instance is (re)used, otherwise
	# recycled texts stay invisible forever.
	text.visible = true
	text.global_position = spawn_position
	text.set_meta("floating_text_style", style)
	_active.append(text)
	text.call("display_damage_text", damage_amount)
	return text


## Immediately clears all currently-displaying damage texts.
## Used when transitioning between battles to prevent lingering texts
## from a previous fight from bleeding into the next one.
func release_all_active() -> void:
	# Snapshot first — release_text mutates _active.
	var snapshot: Array[Node2D] = _active.duplicate()
	for text: Node2D in snapshot:
		if text == null or not is_instance_valid(text):
			continue
		# Kill any in-flight tweens so the text snaps to its current state.
		if text.has_method("kill_tweens"):
			text.call("kill_tweens")
		text.visible = false
		release_text(text)


func get_active_count() -> int:
	return _active.size()


func get_available_count() -> int:
	var total: int = 0
	for available: Variant in _available.values():
		if available is Array:
			total += (available as Array).size()
	return total


func release_text(text: Node2D) -> void:
	if text == null or not is_instance_valid(text):
		return
	_active.erase(text)
	var style: StringName = text.get_meta("floating_text_style", &"default") as StringName
	var available: Array = _available.get(style, []) as Array
	if not available.has(text):
		available.append(text)
		_available[style] = available


func _obtain_text(style: StringName) -> Node2D:
	var available: Array = _available.get(style, []) as Array
	if not available.is_empty():
		return available.pop_back()
	var scene: PackedScene = _scene_for_style(style)
	if scene == null:
		push_warning("FloatDamageTextPool needs a floating_text_scene.")
		return null
	var text: Node2D = scene.instantiate() as Node2D
	if text == null:
		push_warning("FloatDamageTextPool can only pool Node2D scenes.")
		return null
	_connect_finished_signal(text)
	return text


func _scene_for_style(style: StringName) -> PackedScene:
	match style:
		&"burn":
			return burn_floating_text_scene
		&"crit":
			return crit_floating_text_scene
		_:
			return floating_text_scene


func _connect_finished_signal(text: Node2D) -> void:
	if not text.has_signal(&"animation_finished"):
		return
	var release_callable: Callable = Callable(self, "_on_text_animation_finished").bind(text)
	if not text.is_connected(&"animation_finished", release_callable):
		text.connect(&"animation_finished", release_callable)


func _on_text_animation_finished(text: Node2D) -> void:
	release_text(text)
