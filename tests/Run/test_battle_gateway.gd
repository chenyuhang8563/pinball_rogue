extends GutTest

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")
const RealLevel: LevelDef = preload("res://Combat/levels/level_001_weak.tres")

var _gateway: BattleGateway
var _spawner: BattleSpawner
var _level_parent: Node2D
var _base_enemies: Node2D
var _reset_count: int
var _floating_clear_count: int


func before_each() -> void:
	_reset_count = 0
	_floating_clear_count = 0
	_level_parent = Node2D.new()
	add_child_autofree(_level_parent)
	_base_enemies = Node2D.new()
	_base_enemies.name = "BaseEnemies"
	_level_parent.add_child(_base_enemies)
	_spawner = BattleSpawner.new()
	add_child_autofree(_spawner)
	_gateway = BattleGateway.new()
	add_child_autofree(_gateway)
	assert_true(_gateway.configure(
		_spawner,
		_base_enemies,
		_level_parent,
		func() -> void: _reset_count += 1,
		func() -> void: _floating_clear_count += 1,
		func(_stat_id: StringName, _entity_id: StringName) -> float: return 0.25
	))


func after_each() -> void:
	if is_instance_valid(_gateway):
		_gateway.dispose()
	if is_instance_valid(_spawner):
		_spawner.dispose()


func test_real_level_uses_fixed_zone_and_session_as_only_completion_source() -> void:
	watch_signals(_gateway)
	var plan: BattlePlan = _real_level_plan(&"battle:real", 1)
	var token := RunFlowToken.new(1, 2, 3)

	assert_true(_gateway.start(plan, token))
	assert_eq(_reset_count, 1)
	assert_eq(_floating_clear_count, 1)
	assert_not_null(_gateway.active_level_scene)
	assert_eq(
		_spawner.enemy_container,
		_gateway.active_level_scene.get_node("Enemies")
	)
	assert_not_null(_gateway.active_level_scene.get_node("TableBase/KillZone"))
	assert_false(_base_enemies.visible)
	assert_eq(_spawner.enemy_container.get_child_count(), 1)
	assert_false(_spawner.has_signal(&"battle_completed"))
	assert_eq(_gateway._session.completed.get_connections().size(), 1)
	var wall := _gateway.active_level_scene.get_node(
		"TableBase/BouncelessWall"
	) as StaticBody2D
	assert_almost_eq(wall.physics_material_override.bounce, 0.25, 0.001)

	var enemy: Enemy = _spawner.enemy_container.get_child(0) as Enemy
	assert_true(enemy.defeat(&"gateway_success"))
	assert_signal_emitted_with_parameters(
		_gateway, "battle_completed", [token, plan.battle_id, plan]
	)


func test_force_complete_uses_the_normal_session_completion_signal() -> void:
	watch_signals(_gateway)
	var plan: BattlePlan = _real_level_plan(&"battle:debug_skip", 1)
	var token := RunFlowToken.new(11, 2, 3)

	assert_true(_gateway.start(plan, token))
	assert_true(_gateway.force_complete_current_battle())
	assert_signal_emitted_with_parameters(
		_gateway, "battle_completed", [token, plan.battle_id, plan]
	)
	assert_null(_gateway._active_plan)
	assert_null(_gateway._active_token)


func test_real_level_zero_entry_completes_synchronously_and_start_returns_true() -> void:
	watch_signals(_gateway)
	var plan: BattlePlan = _real_level_plan(&"battle:zero", 0)
	var token := RunFlowToken.new(2, 4, 6)

	assert_true(_gateway.start(plan, token))
	assert_signal_emitted_with_parameters(
		_gateway, "battle_completed", [token, plan.battle_id, plan]
	)
	assert_null(_gateway._active_plan)
	assert_null(_gateway._active_token)
	assert_null(_gateway._session.active_plan())
	assert_false(_spawner.has_signal(&"battle_completed"))
	assert_eq(_gateway._session.completed.get_connections().size(), 1)


func test_invalid_real_level_batch_rolls_back_every_runtime_owner() -> void:
	watch_signals(_gateway)
	var plan: BattlePlan = _real_level_plan(&"battle:failure", 0)
	var invalid_entry := BattleGroupDef.EnemyEntry.new()
	plan.group.enemy_entries.append(invalid_entry)

	assert_false(_gateway.start(plan, RunFlowToken.new(3, 1, 1)))
	assert_signal_not_emitted(_gateway, "battle_completed")
	assert_null(_gateway.active_level_scene)
	assert_null(_gateway._active_plan)
	assert_null(_gateway._active_token)
	assert_null(_gateway._session.active_plan())
	assert_eq(_gateway._session.active_batch_id(), 0)
	assert_eq(_spawner.enemy_container, _base_enemies)
	assert_eq(_base_enemies.get_child_count(), 0)
	assert_true(_base_enemies.visible)
	assert_eq(_spawner.spawn_batch_sealed.get_connections().size(), 0)
	assert_eq(_spawner.spawn_batch_failed.get_connections().size(), 0)


func test_missing_fixed_kill_zone_fails_synchronously_and_restores_base() -> void:
	watch_signals(_gateway)
	var plan: BattlePlan = _plan_with_level(
		&"battle:missing_zone", _packed_level_without_fixed_zone()
	)

	assert_false(_gateway.start(plan, RunFlowToken.new(4, 1, 1)))
	assert_signal_not_emitted(_gateway, "battle_completed")
	assert_null(_gateway.active_level_scene)
	assert_eq(_spawner.enemy_container, _base_enemies)
	assert_true(_base_enemies.visible)
	assert_null(_gateway._session.active_plan())
	assert_eq(_reset_count, 0)


func test_stale_session_callbacks_do_not_cross_into_the_current_battle() -> void:
	watch_signals(_gateway)
	var first_plan: BattlePlan = _real_level_plan(&"battle:first", 1)
	var first_token := RunFlowToken.new(5, 1, 1)
	assert_true(_gateway.start(first_plan, first_token))
	_gateway.clear()

	var second_plan: BattlePlan = _real_level_plan(&"battle:second", 1)
	var second_token := RunFlowToken.new(5, 2, 1)
	assert_true(_gateway.start(second_plan, second_token))
	var marble := RigidBody2D.new()
	marble.add_to_group("marbles")
	add_child_autofree(marble)

	_gateway._on_session_completed(first_token, first_plan.battle_id, first_plan)
	_gateway._on_session_marble_fell(first_token, marble)
	assert_signal_not_emitted(_gateway, "battle_completed")
	assert_signal_not_emitted(_gateway, "marble_fell")

	var kill_zone: Area2D = _gateway.active_level_scene.get_node(
		"TableBase/KillZone"
	) as Area2D
	kill_zone.marble_fell.emit(marble)
	assert_signal_emitted_with_parameters(
		_gateway, "marble_fell", [second_token, marble]
	)


func test_same_raw_marble_is_accepted_once_through_session_gateway_and_flow() -> void:
	var flow := RunBattleFlow.new()
	assert_true(flow.configure(_gateway))
	var plan: BattlePlan = _real_level_plan(&"battle:marble_dedup", 1)
	var token := RunFlowToken.new(7, 1, 1)
	var gateway_marbles: Array[RigidBody2D] = []
	var flow_marbles: Array[RigidBody2D] = []
	var completed_ids: Array[StringName] = []
	var gateway_marble_cb := func(_t: RunFlowToken, m: RigidBody2D) -> void:
		gateway_marbles.append(m)
	var flow_marble_cb := func(_t: RunFlowToken, m: RigidBody2D) -> void:
		flow_marbles.append(m)
	var flow_completed_cb := func(_t: RunFlowToken, id: StringName, _p: BattlePlan) -> void:
		completed_ids.append(id)
	_gateway.marble_fell.connect(gateway_marble_cb)
	flow.marble_fell.connect(flow_marble_cb)
	flow.completed.connect(flow_completed_cb)

	assert_true(flow.start(plan, token))
	var kill_zone: Area2D = _gateway.active_level_scene.get_node(
		"TableBase/KillZone"
	) as Area2D
	var marble := RigidBody2D.new()
	marble.add_to_group("marbles")
	add_child_autofree(marble)

	# Two raw facts for the same body: Session identity dedup accepts exactly one,
	# which is the single fact driving both chain rebuild and health decrement.
	kill_zone.marble_fell.emit(marble)
	kill_zone.marble_fell.emit(marble)
	assert_eq(gateway_marbles, [marble])
	assert_eq(flow_marbles, [marble])

	var second := RigidBody2D.new()
	second.add_to_group("marbles")
	add_child_autofree(second)
	kill_zone.marble_fell.emit(second)
	assert_eq(gateway_marbles, [marble, second])
	assert_eq(flow_marbles, [marble, second])

	# Completing the battle closes the session: later raw facts are inert.
	var enemy: Enemy = _spawner.enemy_container.get_child(0) as Enemy
	assert_true(enemy.defeat(&"dedup_done"))
	assert_eq(completed_ids, [plan.battle_id])
	kill_zone.marble_fell.emit(second)
	assert_eq(flow_marbles, [marble, second], "closed session must not accept marbles")

	_gateway.marble_fell.disconnect(gateway_marble_cb)
	flow.marble_fell.disconnect(flow_marble_cb)
	flow.completed.disconnect(flow_completed_cb)
	flow.dispose()


func test_clear_restores_base_and_dispose_removes_session_consumers() -> void:
	assert_true(_gateway.start(
		_real_level_plan(&"battle:clear", 1), RunFlowToken.new(6, 1, 1)
	))
	var session: BattleSession = _gateway._session
	assert_eq(session.completed.get_connections().size(), 1)

	_gateway.clear(true)
	assert_null(_gateway.active_level_scene)
	assert_eq(_spawner.enemy_container, _base_enemies)
	assert_true(_base_enemies.visible)
	assert_eq(_reset_count, 2)
	assert_eq(_floating_clear_count, 2)
	assert_eq(session.completed.get_connections().size(), 1)

	_gateway.dispose()
	assert_null(_gateway._session)
	assert_false(is_instance_valid(session))
	assert_false(_spawner.has_signal(&"battle_completed"))


func _real_level_plan(battle_id: StringName, enemy_count: int) -> BattlePlan:
	var plan: BattlePlan = _plan_with_level(battle_id, RealLevel.level_scene)
	for index: int in range(enemy_count):
		var entry := BattleGroupDef.EnemyEntry.new()
		entry.scene = EnemyScene
		entry.position = Vector2(20 + index * 12, 30)
		entry.health = 20 + index
		plan.group.enemy_entries.append(entry)
	return plan


func _plan_with_level(battle_id: StringName, level_scene: PackedScene) -> BattlePlan:
	var group := BattleGroupDef.new()
	group.id = String(battle_id)
	var level := LevelDef.new()
	level.level_scene = level_scene
	group.level_def = level
	return BattlePlan.new(
		battle_id, group, BattlePlan.Origin.NODE, BattlePlan.RewardPolicy.NORMAL
	)


func _packed_level_without_fixed_zone() -> PackedScene:
	var root := Node2D.new()
	var enemies := Node2D.new()
	enemies.name = "Enemies"
	root.add_child(enemies)
	enemies.owner = root
	var table := Node2D.new()
	table.name = "TableBase"
	root.add_child(table)
	table.owner = root
	var packed := PackedScene.new()
	assert_eq(packed.pack(root), OK)
	root.free()
	return packed
