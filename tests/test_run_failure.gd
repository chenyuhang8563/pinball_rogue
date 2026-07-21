extends GutTest


const RunControllerScript: GDScript = preload("res://Run/run_controller.gd")
const RunFailurePanelScene: PackedScene = preload("res://UI/run_failure_panel.tscn")
const RUN_HEALTH_ENTITY_ID: String = "run:current"
const RUN_HEALTH_STAT: StringName = &"run_health"


func after_each() -> void:
	get_tree().paused = false
	var stat_system: Node = get_tree().root.get_node_or_null("StatSystem")
	if stat_system == null:
		return
	stat_system.call("unregister_entity", RUN_HEALTH_ENTITY_ID)
	stat_system.call("register_entity", RUN_HEALTH_ENTITY_ID, [RUN_HEALTH_STAT])


# Verifies that a lethal marble loss ends exactly one run and restart restores its initial state.
func test_lethal_marble_loss_fails_once_and_restart_starts_a_new_run() -> void:
	var stat_system: Node = get_tree().root.get_node_or_null("StatSystem")
	assert_not_null(stat_system, "StatSystem autoload must be available for run-health behavior.")
	if stat_system == null:
		return

	stat_system.call("unregister_entity", RUN_HEALTH_ENTITY_ID)
	stat_system.call("register_entity", RUN_HEALTH_ENTITY_ID, [RUN_HEALTH_STAT])
	stat_system.call("set_stat_base", RUN_HEALTH_ENTITY_ID, RUN_HEALTH_STAT, 1.0)

	var controller: RunController = RunControllerScript.new() as RunController
	add_child_autofree(controller)
	var marble := RigidBody2D.new()
	marble.add_to_group(&"marbles")
	add_child_autofree(marble)

	var health_updates: Array[int] = []
	var failure_count: Array[int] = [0]
	controller.run_health_changed.connect(func(health: int) -> void:
		health_updates.append(health)
	)
	controller.run_failed.connect(func() -> void:
		failure_count[0] += 1
	)

	controller.battle_is_active = true
	controller._on_marble_fell(marble)
	controller._on_marble_fell(marble)

	assert_eq(int(stat_system.call("get_stat", RUN_HEALTH_STAT, RUN_HEALTH_ENTITY_ID)), 0)
	assert_eq(health_updates, [0])
	assert_true(controller.run_is_failed)
	assert_false(controller.battle_is_active)
	assert_eq(failure_count[0], 1)

	controller.start_run()

	assert_false(controller.run_is_failed)
	assert_false(controller.run_is_complete)
	assert_eq(controller.current_node_index, 1)
	assert_true(controller.battle_is_active)
	assert_gt(int(stat_system.call("get_stat", RUN_HEALTH_STAT, RUN_HEALTH_ENTITY_ID)), 0)


# Verifies that the failure panel pauses input and emits a restart request without reloading a scene.
func test_failure_panel_pauses_until_confirmation_and_then_closes() -> void:
	var panel: RunFailurePanel = RunFailurePanelScene.instantiate() as RunFailurePanel
	add_child_autofree(panel)
	await get_tree().process_frame

	var restart_count: Array[int] = [0]
	panel.restart_requested.connect(func() -> void:
		restart_count[0] += 1
	)

	assert_false(panel.visible)
	panel.open_failure()
	await get_tree().process_frame

	var confirm_button: Button = panel.get_node("Center/Panel/MarginContainer/Layout/ConfirmButton") as Button
	assert_true(panel.visible)
	assert_true(get_tree().paused)
	assert_true(confirm_button.has_focus())
	confirm_button.pressed.emit()
	assert_eq(restart_count[0], 1)

	panel.close_failure()
	await get_tree().process_frame
	assert_false(panel.visible)
	assert_false(get_tree().paused)
