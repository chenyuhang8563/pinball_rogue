extends RefCounted
class_name LightningEffect

const DAMAGE: int = 1
const LightningEffectScene := preload("res://Effects/lightning_effect.tscn")


func on_enemy_hit_by_marble(enemy: Node2D) -> void:
	if enemy == null:
		return

	var target := _find_nearest_enemy(enemy)
	if target != null and target.has_method("take_damage"):
		target.take_damage(DAMAGE)
		_spawn_lightning_effect(enemy.global_position, target.global_position)


func _find_nearest_enemy(origin: Node2D) -> Node2D:
	var nearest_enemy: Node2D = null
	var nearest_distance := INF

	for enemy in origin.get_tree().get_nodes_in_group("enemies"):
		if enemy == origin:
			continue
		if not is_instance_valid(enemy):
			continue
		if enemy is not Node2D:
			continue

		var enemy_node := enemy as Node2D
		var distance := origin.global_position.distance_to(enemy_node.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy_node

	return nearest_enemy

func _spawn_lightning_effect(from_position: Vector2, to_position: Vector2) -> void:
	var direction := to_position - from_position
	if direction == Vector2.ZERO:
		return

	var effect := LightningEffectScene.instantiate()
	var scene = Engine.get_main_loop().current_scene
	scene.add_child(effect)
	effect.global_position = (from_position + to_position) * 0.5
	effect.rotation = direction.angle()
