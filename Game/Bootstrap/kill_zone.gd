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


## 非刚体金币保持 collision_layer = 0；由掉落导演显式查询边界，
## 避免为了超时逻辑改变既有物理层约定。
func contains_global_point(world_position: Vector2) -> bool:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not shape_node.shape is RectangleShape2D:
		return false
	var rectangle := shape_node.shape as RectangleShape2D
	var local_point := shape_node.to_local(world_position)
	return absf(local_point.x) <= rectangle.size.x * 0.5 \
		and absf(local_point.y) <= rectangle.size.y * 0.5
