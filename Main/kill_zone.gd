extends Area2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("marbles"):
		_handle_marble_fell(body)
	elif body.is_in_group("enemies"):
		_handle_enemy_fell(body)


func _handle_marble_fell(body: Node) -> void:
	var event_bus: Node = _get_event_bus()
	if event_bus != null and event_bus.has_signal(&"marble_fell"):
		event_bus.emit_signal(&"marble_fell", body)
	body.queue_free()


func _handle_enemy_fell(body: Node) -> void:
	var event_bus: Node = _get_event_bus()
	if event_bus != null and event_bus.has_signal(&"enemy_killed"):
		event_bus.emit_signal(&"enemy_killed", body)
	body.queue_free()


func _get_event_bus() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("Event")
