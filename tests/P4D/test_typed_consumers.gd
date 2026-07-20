extends GutTest

const MainScene: PackedScene = preload("res://Main/main.tscn")
const MarbleScene: PackedScene = preload("res://Marbles/marble.tscn")
const EnemyScene: PackedScene = preload("res://Enemies/enemy.tscn")


class TrackingBuffManager extends BuffManager:
	var deliveries: Array[Dictionary] = []

	func dispatch(method_name: StringName, args: Array = []) -> void:
		deliveries.append({"method": method_name, "args": args.duplicate()})


class TrackingSkillController extends SkillController:
	var lifecycle_events: Array[StringName] = []

	func _on_battle_started(_token: RunFlowToken, _plan: BattlePlan) -> void:
		lifecycle_events.append(&"battle_started")

	func _on_battle_completed(
		_token: RunFlowToken,
		_battle_id: StringName,
		_plan: BattlePlan
	) -> void:
		lifecycle_events.append(&"battle_completed")

	func _on_run_completed(_token: RunFlowToken) -> void:
		lifecycle_events.append(&"run_completed")


func test_buff_manager_reconfigure_disconnects_old_session_and_chain_sources() -> void:
	var manager := TrackingBuffManager.new()
	var first_session := BattleSession.new()
	var second_session := BattleSession.new()
	var first_chain := MarbleChain.new()
	var second_chain := MarbleChain.new()
	var enemy := EnemyScene.instantiate() as Enemy
	add_child_autofree(first_session)
	add_child_autofree(second_session)
	add_child_autofree(first_chain)
	add_child_autofree(second_chain)
	add_child_autofree(enemy)

	assert_true(manager.configure(first_session, first_chain))
	var enemy_callback := Callable(manager, "_on_enemy_defeated")
	var chain_callback := Callable(manager, "_on_chain_collision")
	assert_true(first_session.enemy_defeated.is_connected(enemy_callback))
	assert_true(first_chain.chain_collision.is_connected(chain_callback))

	assert_true(manager.reconfigure(second_session, second_chain))
	assert_false(first_session.enemy_defeated.is_connected(enemy_callback))
	assert_false(first_chain.chain_collision.is_connected(chain_callback))
	assert_true(second_session.enemy_defeated.is_connected(enemy_callback))
	assert_true(second_chain.chain_collision.is_connected(chain_callback))

	first_session.enemy_defeated.emit(null, enemy, &"stale")
	first_chain.chain_collision.emit(enemy, "wall")
	assert_eq(manager.deliveries.size(), 0, "old typed sources must be inert after reconfigure")
	second_session.enemy_defeated.emit(null, enemy, &"current")
	second_chain.chain_collision.emit(enemy, "flipper")
	assert_eq(manager.deliveries.size(), 2)
	assert_eq(manager.deliveries[0]["method"], &"on_enemy_killed")
	assert_eq(manager.deliveries[1]["method"], &"on_chain_collision")

	assert_true(manager.reconfigure(null, null))
	assert_false(second_session.enemy_defeated.is_connected(enemy_callback))
	assert_false(second_chain.chain_collision.is_connected(chain_callback))
	manager.free()


func test_skill_controller_lifecycle_reconfigure_disconnects_old_run_flow() -> void:
	var controller := TrackingSkillController.new()
	var first_flow := RunFlowController.new()
	var second_flow := RunFlowController.new()
	add_child_autofree(first_flow)
	add_child_autofree(second_flow)
	var token := RunFlowToken.new(1, 1, 1)
	var group := BattleGroupDef.new()
	group.id = "typed"
	var plan := BattlePlan.new(
		&"typed", group, BattlePlan.Origin.NODE, BattlePlan.RewardPolicy.NORMAL
	)

	assert_true(controller.configure_lifecycle(first_flow))
	var started_callback := Callable(controller, "_on_battle_started")
	var completed_callback := Callable(controller, "_on_battle_completed")
	var run_callback := Callable(controller, "_on_run_completed")
	assert_true(first_flow.is_connected(&"battle_started", started_callback))
	assert_true(first_flow.is_connected(&"battle_completed", completed_callback))
	assert_true(first_flow.is_connected(&"run_completed", run_callback))
	first_flow.battle_started.emit(token, plan)
	first_flow.battle_completed.emit(token, &"first", plan)
	first_flow.run_completed.emit(token)
	assert_eq(controller.lifecycle_events, [&"battle_started", &"battle_completed", &"run_completed"])

	assert_true(controller.configure_lifecycle(second_flow))
	assert_false(first_flow.is_connected(&"battle_started", started_callback))
	assert_false(first_flow.is_connected(&"battle_completed", completed_callback))
	assert_false(first_flow.is_connected(&"run_completed", run_callback))
	first_flow.run_completed.emit(token)
	second_flow.run_completed.emit(token)
	assert_eq(controller.lifecycle_events, [
		&"battle_started", &"battle_completed", &"run_completed", &"run_completed",
	])

	controller.disconnect_lifecycle()
	assert_false(second_flow.is_connected(&"battle_started", started_callback))
	assert_false(second_flow.is_connected(&"battle_completed", completed_callback))
	assert_false(second_flow.is_connected(&"run_completed", run_callback))
	controller.free()


func test_main_consumes_gateway_marble_output_and_disconnects_it_explicitly() -> void:
	var main := MainScene.instantiate()
	var gateway := BattleGateway.new()
	var chain := MarbleChain.new()
	var marble := MarbleScene.instantiate() as Marble
	assert_not_null(marble)
	chain.head = marble
	main.set("marble_chain", chain)
	main.set("battle_gateway", gateway)
	var token := RunFlowToken.new(2, 1, 1)

	assert_true(main.call("_connect_gateway_marble_fell"))
	var callback := Callable(main, "_on_accepted_marble_fell")
	assert_true(gateway.is_connected(&"marble_fell", callback))
	gateway.marble_fell.emit(token, marble)
	gateway.marble_fell.emit(token, marble)
	assert_null(main.get("marble_chain"), "one accepted head fall must retire the chain once")
	assert_true(chain.is_queued_for_deletion())

	main.call("_disconnect_gateway_marble_fell")
	assert_false(gateway.is_connected(&"marble_fell", callback))
	gateway.free()
	chain.free()
	marble.free()
	main.free()
