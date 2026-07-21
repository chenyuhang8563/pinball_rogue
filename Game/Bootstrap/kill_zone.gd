extends Area2D

signal marble_fell(marble: RigidBody2D)

var _handled_body_ids: Dictionary[int, bool] = {}


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _exit_tree() -> void:
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	_handled_body_ids.clear()


func _on_body_entered(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	var instance_id: int = body.get_instance_id()
	if _handled_body_ids.has(instance_id):
		return

	if body is RigidBody2D and body.is_in_group("marbles"):
		_handled_body_ids[instance_id] = true
		_handle_marble_fell(body as RigidBody2D)
	elif body is Enemy and body.is_in_group("enemies"):
		_handled_body_ids[instance_id] = true
		_handle_enemy_fell(body as Enemy)


func _handle_marble_fell(marble: RigidBody2D) -> void:
	marble_fell.emit(marble)
	marble.queue_free()


func _handle_enemy_fell(enemy: Enemy) -> void:
	enemy.defeat(&"kill_zone")
