class_name PortalEndpoint
extends Area2D

signal portal_transfer_requested(pair_id: StringName, marble: Marble)
signal portal_body_exited(pair_id: StringName, marble: Marble)

@export var component_id: StringName = &""
@export var pair_id: StringName = &""
@export var forward_local: Vector2 = Vector2.UP
@export_range(0.0, 128.0, 1.0) var exit_clearance_pixels: float = 2.0

@onready var portal_anchor: Marker2D = $PortalAnchor
@onready var safety_sensor: Area2D = $SafetySensor


func _ready() -> void:
	add_to_group(&"table_component")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _exit_tree() -> void:
	remove_from_group(&"table_component")
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	if body_exited.is_connected(_on_body_exited):
		body_exited.disconnect(_on_body_exited)


func forward() -> Vector2:
	return forward_local.rotated(global_rotation).normalized()


func is_overlapping_head(head: Marble) -> bool:
	return head != null and is_instance_valid(head) and get_overlapping_bodies().has(head)


func is_exit_safe(head: Marble, destination: Vector2) -> bool:
	if head == null or not is_instance_valid(head):
		return false
	if safety_sensor != null and not safety_sensor.get_overlapping_bodies().is_empty():
		return false
	var head_shape_node := head.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if head_shape_node == null or head_shape_node.shape == null:
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = head_shape_node.shape
	query.transform = Transform2D(head.global_rotation, destination)
	query.collision_mask = head.collision_mask
	query.exclude = [head.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func minimum_exit_offset(head_collision_radius: float) -> float:
	var trigger_radius := 0.0
	var trigger_shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if trigger_shape_node != null and trigger_shape_node.shape is CircleShape2D:
		trigger_radius = (trigger_shape_node.shape as CircleShape2D).radius
	return head_collision_radius + trigger_radius + exit_clearance_pixels


func anchor_position() -> Vector2:
	return portal_anchor.global_position


func _on_body_entered(body: Node) -> void:
	if body is Marble and (body as Marble).is_head and body.is_in_group(&"marbles"):
		portal_transfer_requested.emit(pair_id, body as Marble)


func _on_body_exited(body: Node) -> void:
	if body is Marble and (body as Marble).is_head and body.is_in_group(&"marbles"):
		portal_body_exited.emit(pair_id, body as Marble)
