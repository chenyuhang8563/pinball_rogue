extends GutTest

const RewardServiceScript: GDScript = preload("res://Run/application/reward_service.gd")
const EventResolverScript: GDScript = preload("res://Run/application/event_resolver.gd")
const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")


class ControlledRandom extends RunRandomSource:
	func range_int(minimum: int, _maximum: int) -> int:
		return minimum

	func weighted_index(weights: PackedInt32Array) -> int:
		for index: int in range(weights.size()):
			if weights[index] > 0:
				return index
		return -1


class FakeStatSystem extends Node:
	func get_stat(stat_id: String, _entity_id: String) -> Variant:
		if stat_id.contains("slot_count"):
			return 10
		if stat_id == "sell_price_multiplier":
			return 0.5
		return 1.0


func test_active_enemy_attack_crosses_the_run_flow_and_damages_once() -> void:
	var fixture := _fixture(5)
	var controller := fixture.controller as RunFlowController
	var gateway := fixture.gateway as BattleGateway
	var scope := fixture.scope as RunScope

	assert_true(controller.start_run())
	_handle_known_shader_error()
	assert_not_null(gateway.active_level_scene)
	var enemy := gateway.active_level_scene.get_node("Enemies").get_child(0) as Enemy
	assert_not_null(enemy)
	enemy.player_damage_requested.emit(enemy, 2)

	assert_eq(int(scope.health.call("current")), 3)


func test_stale_invalid_and_terminal_enemy_attacks_do_not_damage_or_reopen_run() -> void:
	var fixture := _fixture(5)
	var controller := fixture.controller as RunFlowController
	var gateway := fixture.gateway as BattleGateway
	var scope := fixture.scope as RunScope

	assert_true(controller.start_run())
	_handle_known_shader_error()
	var enemy := gateway.active_level_scene.get_node("Enemies").get_child(0) as Enemy
	var token := controller.current_state().token()
	var stale_token := RunFlowToken.new(token.run_id, token.node_id, token.phase_id + 1)
	var failure_reasons: Array[StringName] = []
	controller.run_failed.connect(func(_token: RunFlowToken, reason: StringName) -> void:
		failure_reasons.append(reason)
	)
	watch_signals(controller)

	controller.call("_on_enemy_attack_hit", stale_token, enemy, 2)
	controller.call("_on_enemy_attack_hit", token, null, 2)
	controller.call("_on_enemy_attack_hit", token, enemy, 0)
	assert_eq(int(scope.health.call("current")), 5)
	assert_signal_emit_count(controller, "run_failed", 0)

	controller.call("_on_enemy_attack_hit", token, enemy, 5)
	assert_eq(int(scope.health.call("current")), 0)
	assert_eq(failure_reasons, [&"health_depleted"])

	var terminal_enemy := EnemyScene.instantiate() as Enemy
	add_child_autofree(terminal_enemy)
	controller.call("_on_enemy_attack_hit", token, terminal_enemy, 1)
	assert_eq(int(scope.health.call("current")), 0)
	assert_signal_emit_count(controller, "run_failed", 1)


func _handle_known_shader_error() -> void:
	for tracked_error: GutTrackedError in get_errors():
		if tracked_error.contains_text("custom_samplers"):
			tracked_error.handled = true


func _fixture(initial_health: int) -> Dictionary:
	var stat := FakeStatSystem.new()
	add_child_autofree(stat)
	var scope := RunScope.new()
	add_child_autofree(scope)
	assert_true(scope.initialize(stat, 100, initial_health))
	var random := ControlledRandom.new()
	var floor_config := RunFloorConfig.new()
	floor_config.boss_floor = 6
	var reward := RewardServiceScript.new() as RewardService
	assert_true(reward.configure(
		scope.loadout,
		scope.progression,
		scope.wallet,
		BattleRewardConfig.new(),
		random
	))
	var event := EventResolverScript.new() as EventResolver
	assert_true(event.configure(scope.wallet, random))
	var level_parent := Node2D.new()
	add_child_autofree(level_parent)
	var base_enemies := Node2D.new()
	base_enemies.name = "BaseEnemies"
	level_parent.add_child(base_enemies)
	var spawner := BattleSpawner.new()
	add_child_autofree(spawner)
	var gateway := BattleGateway.new()
	add_child_autofree(gateway)
	assert_true(gateway.configure(
		spawner,
		base_enemies,
		level_parent,
		func() -> void: pass
	))
	var controller := RunFlowController.new()
	add_child_autofree(controller)
	assert_true(controller.configure(
		scope,
		BattlePlanFactory.new(),
		reward,
		event,
		floor_config,
		random,
		gateway
	))
	return {
		&"controller": controller,
		&"gateway": gateway,
		&"scope": scope,
	}
