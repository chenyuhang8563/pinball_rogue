# 炸弹弹珠，击中敌人时爆炸，对周围敌人造成伤害，并推开爆炸范围内的我方弹珠

extends Marble
class_name BombMarble

@export var explosion_radius: float = 100.0
@export var explosion_damage: int = 2
@export var shockwave_impulse: float = 120.0

@onready var explosion_effect_scene: PackedScene = preload("res://Effects/explosion_effect/explosion_effect.tscn")

func _ready() -> void:
	marble_type = MARBLE_TYPE.BOMB
	super()
	body_entered.connect(_on_body_entered)

func get_hit_damage(_target: Node) -> int:
	return explosion_damage

func _on_body_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("enemies"):
		_explode()

func _explode() -> void:
	var explosion_center: Vector2 = global_position
	_damage_enemies_in_radius(explosion_center)
	_apply_shockwave(explosion_center)
	_spawn_explosion_effect(explosion_center)

func _damage_enemies_in_radius(explosion_center: Vector2) -> void:
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy is Node2D:
			continue
		var enemy_node: Node2D = enemy as Node2D
		if enemy_node.global_position.distance_to(explosion_center) > explosion_radius:
			continue
		if enemy_node.has_method("take_damage"):
			enemy_node.take_damage(explosion_damage)

func _apply_shockwave(explosion_center: Vector2) -> void:
	for marble_node: Node in get_tree().get_nodes_in_group("marbles"):
		if marble_node == self or marble_node == null or not is_instance_valid(marble_node):
			continue
		if not marble_node is RigidBody2D:
			continue

		var marble_body: RigidBody2D = marble_node as RigidBody2D
		var offset: Vector2 = marble_body.global_position - explosion_center
		var distance: float = offset.length()
		if distance > explosion_radius:
			continue

		var direction: Vector2 = Vector2.RIGHT if distance <= 0.001 else offset / distance
		var falloff: float = 1.0 - (distance / explosion_radius)
		marble_body.apply_central_impulse(direction * shockwave_impulse * max(falloff, 0.1))

func _spawn_explosion_effect(explosion_center: Vector2) -> void:
	var scene: Node = Engine.get_main_loop().current_scene
	if scene == null:
		return
	var explosion_effect: Node2D = explosion_effect_scene.instantiate() as Node2D
	scene.add_child(explosion_effect)
	explosion_effect.global_position = explosion_center
