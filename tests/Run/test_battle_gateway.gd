extends GutTest

const GatewayScript: GDScript = preload("res://Run/battle_gateway.gd")

class FakeSpawner:
	extends Node
	signal battle_completed(group_id: String)
	var enemy_container: Node2D
	var started_groups: Array[BattleGroupDef] = []
	var clear_count: int = 0
	var fail_start: bool = false
	var complete_synchronously: bool = false

	func start_battle(group: BattleGroupDef) -> bool:
		started_groups.append(group)
		if fail_start:
			return false
		if complete_synchronously:
			battle_completed.emit(group.id)
		return true

	func clear_enemies() -> void:
		clear_count += 1


class LegacyEvents:
	extends Node
	signal marble_fell(marble: Variant)


var _gateway: BattleGateway
var _spawner: FakeSpawner
var _legacy: LegacyEvents
var _level_parent: Node2D
var _base_enemies: Node2D
var _reset_count: int
var _floating_clear_count: int


func before_each() -> void:
	_reset_count = 0
	_floating_clear_count = 0
	_spawner = FakeSpawner.new()
	add_child_autofree(_spawner)
	_legacy = LegacyEvents.new()
	add_child_autofree(_legacy)
	_level_parent = Node2D.new()
	add_child_autofree(_level_parent)
	_base_enemies = Node2D.new()
	_level_parent.add_child(_base_enemies)
	_gateway = GatewayScript.new()
	add_child_autofree(_gateway)
	assert_true(_gateway.configure(
		_spawner,
		_base_enemies,
		_level_parent,
		func() -> void: _reset_count += 1,
		func() -> void: _floating_clear_count += 1,
		func(_stat_id: StringName, _entity_id: StringName) -> float: return 0.25,
		_legacy
	))


func test_start_loads_level_switches_container_and_clear_restores_runtime() -> void:
	var plan := _plan(&"battle:level", "group_level", _packed_level())
	var token := RunFlowToken.new(1, 2, 3)

	assert_true(_gateway.start(plan, token))
	assert_eq(_spawner.started_groups, [plan.group])
	assert_eq(_reset_count, 1)
	assert_eq(_floating_clear_count, 1)
	assert_not_null(_gateway.active_level_scene)
	assert_eq(_spawner.enemy_container, _gateway.active_level_scene.get_node("Enemies"))
	assert_false(_base_enemies.visible)
	var wall := _gateway.active_level_scene.get_node("BouncelessWall") as StaticBody2D
	assert_almost_eq(wall.physics_material_override.bounce, 0.25, 0.001)

	_gateway.clear(true)
	assert_null(_gateway.active_level_scene)
	assert_eq(_spawner.enemy_container, _base_enemies)
	assert_true(_base_enemies.visible)
	assert_eq(_reset_count, 2)
	assert_eq(_floating_clear_count, 2)


func test_synchronous_empty_battle_completion_keeps_typed_metadata() -> void:
	_spawner.complete_synchronously = true
	watch_signals(_gateway)
	var plan := _plan(&"battle:empty", "empty")
	var token := RunFlowToken.new(2, 4, 6)

	assert_true(_gateway.start(plan, token))
	assert_signal_emitted_with_parameters(
		_gateway, "battle_completed", [token, plan.battle_id, plan]
	)
	assert_false(_legacy.has_connections(&"marble_fell"))


func test_stale_or_wrong_group_completion_is_ignored() -> void:
	watch_signals(_gateway)
	var first := _plan(&"battle:first", "first")
	var second := _plan(&"battle:second", "second")
	assert_true(_gateway.start(first, RunFlowToken.new(1, 1, 1)))
	var stale_completion: Callable = _gateway._spawner_completion_callable
	assert_true(_gateway.start(second, RunFlowToken.new(1, 2, 1)))

	stale_completion.call("first")
	_spawner.battle_completed.emit("wrong")
	assert_signal_not_emitted(_gateway, "battle_completed")
	_spawner.battle_completed.emit("second")
	assert_signal_emit_count(_gateway, "battle_completed", 1)


func test_saved_legacy_callback_forwards_its_bound_old_token() -> void:
	watch_signals(_gateway)
	var first_token := RunFlowToken.new(4, 1, 1)
	assert_true(_gateway.start(_plan(&"battle:first", "first"), first_token))
	var old_callback: Callable = _gateway._legacy_marble_callable
	assert_true(_gateway.start(
		_plan(&"battle:second", "second"), RunFlowToken.new(4, 2, 1)
	))
	var marble := RigidBody2D.new()
	add_child_autofree(marble)
	marble.add_to_group("marbles")

	old_callback.call(marble)
	assert_signal_emitted_with_parameters(_gateway, "marble_fell", [first_token, marble])


func test_invalid_marble_payloads_are_not_forwarded() -> void:
	watch_signals(_gateway)
	assert_true(_gateway.start(
		_plan(&"battle:valid", "valid"), RunFlowToken.new(5, 1, 1)
	))
	var not_a_marble := RigidBody2D.new()
	add_child_autofree(not_a_marble)

	_legacy.marble_fell.emit(null)
	var wrong_type := Node.new()
	_legacy.marble_fell.emit(wrong_type)
	wrong_type.free()
	_legacy.marble_fell.emit(not_a_marble)
	assert_signal_not_emitted(_gateway, "marble_fell")


func test_start_failure_returns_false_and_clears_connections_and_scene() -> void:
	_spawner.fail_start = true
	var plan := _plan(&"battle:failure", "failure", _packed_level())

	assert_false(_gateway.start(plan, RunFlowToken.new(6, 1, 1)))
	assert_null(_gateway.active_level_scene)
	assert_eq(_spawner.enemy_container, _base_enemies)
	assert_false(_legacy.has_connections(&"marble_fell"))
	assert_gt(_spawner.clear_count, 0)


func _plan(battle_id: StringName, group_id: String, level_scene: PackedScene = null) -> BattlePlan:
	var group := BattleGroupDef.new()
	group.id = group_id
	if level_scene != null:
		var level := LevelDef.new()
		level.level_scene = level_scene
		group.level_def = level
	return BattlePlan.new(
		battle_id, group, BattlePlan.Origin.NODE, BattlePlan.RewardPolicy.NORMAL
	)


func _packed_level() -> PackedScene:
	var root := Node2D.new()
	var enemies := Node2D.new()
	enemies.name = "Enemies"
	root.add_child(enemies)
	enemies.owner = root
	var wall := StaticBody2D.new()
	wall.name = "BouncelessWall"
	root.add_child(wall)
	wall.owner = root
	var original_material := PhysicsMaterial.new()
	original_material.bounce = 0.9
	wall.physics_material_override = original_material
	var packed := PackedScene.new()
	assert_eq(packed.pack(root), OK)
	root.free()
	return packed
