extends GutTest

const EnemyScene: PackedScene = preload("res://Enemies/enemy.tscn")

class CountingDeathBuff:
	extends BuffDef
	var death_count: int = 0
	var order: Array[StringName] = []

	func on_host_death(_host: Node, _state: Dictionary) -> void:
		death_count += 1
		order.append(&"host_death")


func test_real_enemy_scene_has_typed_surface_and_guarded_defeat_order() -> void:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	assert_not_null(enemy)
	assert_true(enemy is Enemy)
	assert_true(enemy.has_signal(&"defeated"))
	assert_true(enemy.has_method(&"defeat"))
	add_child_autofree(enemy)

	var buff := CountingDeathBuff.new()
	buff.id = "counting_death"
	enemy.add_buff(buff)
	var order: Array[StringName] = buff.order
	var causes: Array[StringName] = []
	enemy.defeated.connect(func(defeated_enemy: Enemy, cause: StringName) -> void:
		assert_eq(defeated_enemy, enemy)
		assert_eq(buff.death_count, 1, "BuffHost death hook must run before defeated")
		order.append(&"defeated")
		causes.append(cause)
	)

	assert_true(enemy.defeat(&"test_cause"))
	assert_false(enemy.defeat(&"later_cause"))
	assert_eq(buff.death_count, 1)
	assert_eq(causes, [&"test_cause"])
	assert_eq(order, [&"host_death", &"defeated"])
	assert_true(enemy.is_queued_for_deletion(), "queue_free must be scheduled after defeated")


func test_health_depletion_uses_the_same_guarded_command() -> void:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	add_child_autofree(enemy)
	var causes: Array[StringName] = []
	enemy.defeated.connect(func(_enemy: Enemy, cause: StringName) -> void:
		causes.append(cause)
	)

	enemy.take_damage(enemy.health)
	assert_eq(causes, [&"health_depleted"])
	assert_false(enemy.defeat(&"duplicate"))


func test_batch_spawner_has_no_legacy_enemy_bridge_or_completion_surface() -> void:
	var container := Node2D.new()
	add_child_autofree(container)
	var spawner := BattleSpawner.new()
	spawner.enemy_container = container
	add_child_autofree(spawner)
	var registered: Array[Enemy] = []

	assert_true(spawner.start_batch(_group(2, "batch_two"), 1, func(
		_batch_id: int, _entry_index: int, enemy: Enemy
	) -> bool:
		registered.append(enemy)
		return true
	))
	assert_eq(registered.size(), 2)
	assert_eq(container.get_child_count(), 2)
	var first: Enemy = container.get_child(0) as Enemy
	var second: Enemy = container.get_child(1) as Enemy
	assert_eq(first.defeated.get_connections().size(), 0)
	assert_eq(second.defeated.get_connections().size(), 0)

	assert_true(first.defeat(&"first"))
	assert_false(first.defeat(&"duplicate"))
	assert_true(second.defeat(&"second"))
	assert_false(second.defeat(&"duplicate"))
	assert_false(spawner.has_signal(&"battle_completed"))


func _group(enemy_count: int, group_id: String) -> BattleGroupDef:
	var group := BattleGroupDef.new()
	group.id = group_id
	for index: int in range(enemy_count):
		var entry := BattleGroupDef.EnemyEntry.new()
		entry.scene = EnemyScene
		entry.position = Vector2(16 * index, 24)
		entry.health = 10 + index
		group.enemy_entries.append(entry)
	return group
