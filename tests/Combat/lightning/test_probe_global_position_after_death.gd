extends GutTest

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")


## Probe: what does an enemy's global_position return after defeat()/queue_free()?
## This determines whether the lightning chain link can anchor to (0,0).

var _dummy_scene: Node2D = null


func before_each() -> void:
	_dummy_scene = Node2D.new()
	_dummy_scene.name = "ProbeScene"
	get_tree().root.add_child(_dummy_scene)
	get_tree().current_scene = _dummy_scene


func after_each() -> void:
	if _dummy_scene != null and is_instance_valid(_dummy_scene):
		_dummy_scene.queue_free()
		_dummy_scene = null
	get_tree().current_scene = null


func test_global_position_preserved_after_defeat() -> void:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	enemy.health = 1
	_dummy_scene.add_child(enemy)
	enemy.global_position = Vector2(72, 48)
	assert_eq(enemy.global_position, Vector2(72, 48))

	# Simulate a lethal hit → defeat() → queue_free()
	var packet := DamagePacket.new(&"marble_head", 100.0)
	packet.is_marble = true
	packet.target = enemy
	enemy.apply_damage_packet(packet)

	assert_true(enemy.is_queued_for_deletion(), "enemy is queued for deletion")
	assert_eq(enemy.global_position, Vector2(72, 48),
		"global_position must be preserved after queue_free (node still in tree this frame)")


func test_global_position_after_remove_from_tree() -> void:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	_dummy_scene.add_child(enemy)
	enemy.position = Vector2(120, 72)
	enemy.global_position = Vector2(120, 72)
	assert_eq(enemy.global_position, Vector2(120, 72))

	_dummy_scene.remove_child(enemy)
	assert_eq(enemy.global_position, Vector2(120, 72),
		"global_position keeps local position after remove_child when position was set")

	_dummy_scene.add_child(enemy)
	enemy.free()


func test_enemy_never_in_tree_has_zero_position() -> void:
	# A fresh instance NOT added to the tree reports (0,0).
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	assert_eq(enemy.global_position, Vector2.ZERO,
		"an enemy never added to the tree reports global_position (0,0)")
	enemy.free()
