extends GutTest

const EnemyScene: PackedScene = preload("res://Enemies/enemy.tscn")
const KillZoneScript: GDScript = preload("res://Main/kill_zone.gd")

var _marble_bodies: Array[RigidBody2D] = []


func before_each() -> void:
	_marble_bodies.clear()


func test_kill_zone_emits_each_distinct_raw_marble_once() -> void:
	var kill_zone: Area2D = KillZoneScript.new() as Area2D
	add_child_autofree(kill_zone)
	kill_zone.marble_fell.connect(_on_marble_fell)
	watch_signals(kill_zone)

	var first := RigidBody2D.new()
	first.add_to_group("marbles")
	add_child_autofree(first)
	var second := RigidBody2D.new()
	second.add_to_group("marbles")
	add_child_autofree(second)
	var unrelated := RigidBody2D.new()
	add_child_autofree(unrelated)

	kill_zone.call("_on_body_entered", first)
	kill_zone.call("_on_body_entered", first)
	kill_zone.call("_on_body_entered", second)
	kill_zone.call("_on_body_entered", unrelated)

	assert_signal_emit_count(kill_zone, "marble_fell", 2)
	assert_eq(_marble_bodies, [first, second])
	assert_true(first.is_queued_for_deletion())
	assert_true(second.is_queued_for_deletion())
	assert_false(unrelated.is_queued_for_deletion())


func test_kill_zone_defeat_flows_to_the_local_session_once() -> void:
	var container := Node2D.new()
	add_child_autofree(container)
	var spawner := BattleSpawner.new()
	spawner.enemy_container = container
	add_child_autofree(spawner)
	var session := BattleSession.new()
	add_child_autofree(session)
	assert_true(session.configure(spawner))
	var kill_zone: Area2D = KillZoneScript.new() as Area2D
	add_child_autofree(kill_zone)
	watch_signals(session)

	var plan := BattlePlan.new(
		&"kill_zone_p4b", _single_enemy_group(), BattlePlan.Origin.NODE,
		BattlePlan.RewardPolicy.NORMAL
	)
	var token := RunFlowToken.new(8, 1, 1)
	assert_true(session.start(plan, token, kill_zone))
	var enemy: Enemy = container.get_child(0) as Enemy
	assert_not_null(enemy)
	assert_eq(enemy.defeated.get_connections().size(), 1)

	kill_zone.call("_on_body_entered", enemy)
	kill_zone.call("_on_body_entered", enemy)

	assert_signal_emit_count(session, "enemy_defeated", 1)
	assert_signal_emitted_with_parameters(session, "completed", [token, plan.battle_id, plan])
	assert_true(enemy.is_queued_for_deletion())
	session.dispose()
	spawner.dispose()


func test_kill_zone_ignores_enemy_group_body_without_enemy_type() -> void:
	var impostor := RigidBody2D.new()
	impostor.add_to_group("enemies")
	add_child_autofree(impostor)
	var kill_zone: Area2D = KillZoneScript.new() as Area2D
	add_child_autofree(kill_zone)

	kill_zone.call("_on_body_entered", impostor)
	kill_zone.call("_on_body_entered", impostor)

	assert_false(impostor.is_queued_for_deletion())
	assert_true(_marble_bodies.is_empty())


func test_kill_zone_disconnects_its_body_callback_on_exit() -> void:
	var kill_zone: Area2D = KillZoneScript.new() as Area2D
	add_child(kill_zone)
	assert_true(kill_zone.body_entered.is_connected(Callable(kill_zone, "_on_body_entered")))

	remove_child(kill_zone)

	assert_false(kill_zone.body_entered.is_connected(Callable(kill_zone, "_on_body_entered")))
	kill_zone.free()


func test_marble_chain_emits_typed_classification_once_per_fact() -> void:
	var chain := MarbleChain.new()
	add_child_autofree(chain)
	watch_signals(chain)
	var facts: Array[Dictionary] = []
	chain.chain_collision.connect(func(collider: Node, collision_type: String) -> void:
		facts.append({"collider": collider, "collision_type": collision_type})
	)

	var enemy_collider := Node2D.new()
	enemy_collider.add_to_group("enemies")
	add_child_autofree(enemy_collider)
	var flipper_collider := Node2D.new()
	flipper_collider.add_to_group("flipper")
	add_child_autofree(flipper_collider)
	var wall_collider := StaticBody2D.new()
	add_child_autofree(wall_collider)

	chain._on_head_body_entered(enemy_collider)
	chain._on_head_body_entered(flipper_collider)
	chain._on_head_body_entered(wall_collider)

	assert_signal_emit_count(chain, "chain_collision", 3)
	assert_eq(facts, [
		{"collider": enemy_collider, "collision_type": "enemy"},
		{"collider": flipper_collider, "collision_type": "flipper"},
		{"collider": wall_collider, "collision_type": "wall"},
	])


func test_marble_chain_starts_without_a_legacy_bridge() -> void:
	var chain := MarbleChain.new()
	add_child_autofree(chain)
	assert_eq(chain.chain_collision.get_connections().size(), 0)


func _on_marble_fell(marble: RigidBody2D) -> void:
	_marble_bodies.append(marble)


func _single_enemy_group() -> BattleGroupDef:
	var group := BattleGroupDef.new()
	group.id = "kill_zone_p4b"
	var entry := BattleGroupDef.EnemyEntry.new()
	entry.scene = EnemyScene
	entry.position = Vector2(12, 24)
	entry.health = 10
	group.enemy_entries.append(entry)
	return group
