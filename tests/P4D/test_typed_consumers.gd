extends GutTest

const MainScene: PackedScene = preload("res://Main/main.tscn")
const MarbleScene: PackedScene = preload("res://Marbles/marble.tscn")
const EnemyScene: PackedScene = preload("res://Enemies/enemy.tscn")


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
