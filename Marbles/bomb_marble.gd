# 炸弹弹珠，击中敌人时爆炸，对周围敌人造成伤害

extends Marble
class_name BombMarble

@export var explosion_radius: float = 50.0
@export var explosion_damage: int = 5

@onready var explosion_effect_scene: PackedScene = preload("res://Effects/explosion_effect/explosion_effect.tscn")

func _ready() -> void:
	marble_type = MARBLE_TYPE.BOMB
	super()
	body_entered.connect(_on_body_entered)

func get_hit_damage(_target: Node) -> int:
	return roundi(_get_stat_float("explosion_damage", float(explosion_damage)))

func _on_body_entered(body: Node) -> void:
	if body == null:
		return
	if body.is_in_group("enemies"):
		_explode()

func _explode() -> void:
	var explosion_center: Vector2 = global_position
	_damage_enemies_in_radius(explosion_center)
	_spawn_explosion_effect(explosion_center)

func _damage_enemies_in_radius(explosion_center: Vector2) -> void:
	var effective_radius: float = _get_stat_float("explosion_radius", explosion_radius)
	var effective_damage: int = roundi(_get_stat_float("explosion_damage", float(explosion_damage)))
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy is Node2D:
			continue
		var enemy_node: Node2D = enemy as Node2D
		if enemy_node.global_position.distance_to(explosion_center) > effective_radius:
			continue
		if enemy_node.has_method("take_damage"):
			enemy_node.take_damage(effective_damage)

func _spawn_explosion_effect(explosion_center: Vector2) -> void:
	var scene: Node = Engine.get_main_loop().current_scene
	if scene == null:
		return
	var explosion_effect: Node2D = explosion_effect_scene.instantiate() as Node2D
	scene.add_child(explosion_effect)
	explosion_effect.global_position = explosion_center


func _get_stat_float(stat_id: String, fallback: float) -> float:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return fallback
	var stat_system: Node = tree.root.get_node_or_null("StatSystem")
	if stat_system == null or not stat_system.has_method("get_stat"):
		return fallback
	return float(stat_system.call("get_stat", stat_id, "marble_chain"))
