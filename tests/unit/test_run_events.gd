extends GutTest

const RunControllerScript: GDScript = preload("res://Run/run_controller.gd")
const RunEventPanelScene: PackedScene = preload("res://UI/run_event_panel.tscn")

var _original_shop: Node
var _fake_shop: FakeShop


class FakeShop extends Node:
	signal gold_changed(value: int)

	var gold: int = 0:
		set(value):
			gold = value
			gold_changed.emit(value)


class FakeEventPanel extends Control:
	signal wager_requested(cost: int, reward: int)
	signal fight_requested
	signal escape_requested
	signal continued

	var dice_show_count: int = 0
	var crossroads_show_count: int = 0
	var dismiss_count: int = 0
	var reveal_count: int = 0
	var shown_gold: int = -1
	var revealed_roll: int = -1
	var revealed_delta: int = 0
	var revealed_reward: int = 0

	func show_dice_event(gold: int) -> void:
		dice_show_count += 1
		shown_gold = gold

	func show_crossroads_event() -> void:
		crossroads_show_count += 1

	func reveal_dice_result(roll: int, gold_delta: int, reward: int) -> void:
		reveal_count += 1
		revealed_roll = roll
		revealed_delta = gold_delta
		revealed_reward = reward

	func dismiss() -> void:
		dismiss_count += 1


func before_each() -> void:
	_install_fake_shop()


func after_each() -> void:
	get_tree().paused = false
	_remove_fake_shop()


func test_event_panel_scene_contains_both_event_states_and_dice_animation() -> void:
	var panel: RunEventPanel = add_child_autofree(RunEventPanelScene.instantiate()) as RunEventPanel
	var player := panel.get_node("AnimationPlayer") as AnimationPlayer

	assert_not_null(panel.get_node_or_null("Center/Panel/MarginContainer/Layout/DiceChoiceRow/SmallWagerButton"))
	assert_not_null(panel.get_node_or_null("Center/Panel/MarginContainer/Layout/DiceChoiceRow/LargeWagerButton"))
	assert_not_null(panel.get_node_or_null("Center/Panel/MarginContainer/Layout/EncounterChoiceRow/FightButton"))
	assert_not_null(panel.get_node_or_null("Center/Panel/MarginContainer/Layout/EncounterChoiceRow/EscapeButton"))
	assert_true(player.has_animation(&"dice_roll"))
	panel.dismiss()


func test_dice_event_disables_unaffordable_wagers_without_softlocking() -> void:
	var panel: RunEventPanel = add_child_autofree(RunEventPanelScene.instantiate()) as RunEventPanel
	panel.show_dice_event(19)

	var small := panel.get_node("Center/Panel/MarginContainer/Layout/DiceChoiceRow/SmallWagerButton") as Button
	var large := panel.get_node("Center/Panel/MarginContainer/Layout/DiceChoiceRow/LargeWagerButton") as Button
	var leave := panel.get_node("Center/Panel/MarginContainer/Layout/ContinueButton") as Button
	assert_true(small.disabled)
	assert_true(large.disabled)
	assert_true(leave.visible)
	panel.dismiss()


func test_dice_roll_three_loses_the_small_wager() -> void:
	var setup := _make_controller_with_panel()
	var controller: RunController = setup.controller
	var panel: FakeEventPanel = setup.panel
	_fake_shop.gold = 100
	controller.event_roll_callable = func() -> int: return 0
	controller.dice_roll_callable = func() -> int: return 3

	controller.call("_show_random_event")
	panel.wager_requested.emit(20, 30)

	assert_eq(_fake_shop.gold, 80)
	assert_eq(panel.revealed_roll, 3)
	assert_eq(panel.revealed_delta, -20)
	assert_eq(panel.revealed_reward, 0)


func test_dice_roll_four_wins_the_large_wager() -> void:
	var setup := _make_controller_with_panel()
	var controller: RunController = setup.controller
	var panel: FakeEventPanel = setup.panel
	_fake_shop.gold = 100
	controller.event_roll_callable = func() -> int: return 0
	controller.dice_roll_callable = func() -> int: return 4

	controller.call("_show_random_event")
	panel.wager_requested.emit(60, 120)
	panel.wager_requested.emit(60, 120)

	assert_eq(_fake_shop.gold, 160)
	assert_eq(panel.reveal_count, 1)
	assert_eq(panel.revealed_roll, 4)
	assert_eq(panel.revealed_delta, 60)
	assert_eq(panel.revealed_reward, 120)


func test_controller_rejects_a_wager_when_gold_is_insufficient() -> void:
	var setup := _make_controller_with_panel()
	var controller: RunController = setup.controller
	var panel: FakeEventPanel = setup.panel
	_fake_shop.gold = 19
	controller.event_roll_callable = func() -> int: return 0
	controller.dice_roll_callable = func() -> int: return 6

	controller.call("_show_random_event")
	panel.wager_requested.emit(20, 30)

	assert_eq(_fake_shop.gold, 19)
	assert_eq(panel.reveal_count, 0)
	assert_eq(panel.dice_show_count, 2)
	assert_eq(panel.shown_gold, 19)


func test_event_roll_selects_each_event() -> void:
	var setup := _make_controller_with_panel()
	var controller: RunController = setup.controller
	var panel: FakeEventPanel = setup.panel
	controller.event_roll_callable = func() -> int: return 0
	controller.call("_show_random_event")
	assert_eq(panel.dice_show_count, 1)

	controller.event_roll_callable = func() -> int: return 1
	controller.call("_show_random_event")
	assert_eq(panel.crossroads_show_count, 1)


func test_escape_keeps_gold_and_advances_the_run() -> void:
	var setup := _make_controller_with_panel()
	var controller: RunController = setup.controller
	var panel: FakeEventPanel = setup.panel
	_fake_shop.gold = 75
	controller.current_node_index = 1
	controller.event_roll_callable = func() -> int: return 1
	controller.call("_show_random_event")

	panel.escape_requested.emit()

	assert_eq(_fake_shop.gold, 75)
	assert_eq(controller.current_node_index, 2)
	assert_eq(panel.dismiss_count, 1)


func test_crossroads_fight_uses_strong_enemies_with_elite_rewards() -> void:
	var setup := _make_controller_with_panel()
	var controller: RunController = setup.controller
	var group: BattleGroupDef = controller.call("_make_event_strong_group") as BattleGroupDef

	assert_not_null(group)
	assert_eq(group.kind, BattleGroupDef.Kind.ELITE)
	assert_eq((group.level_def as LevelDef).id, "strong_normal")
	assert_eq(group.enemy_entries.size(), 5)
	assert_true(group.id.begins_with("event_elite_"))
	var gold_reward: int = controller.call("_roll_battle_gold", group.id)
	assert_gte(gold_reward, 35)
	assert_lte(gold_reward, 40)
	var item_rewards: Array[Item] = controller.call("_pick_battle_reward_items", group.id)
	assert_eq(item_rewards.size(), 1)
	assert_eq(item_rewards[0].type, Item.ItemType.RELIC)


func _make_controller_with_panel() -> Dictionary:
	var panel := FakeEventPanel.new()
	add_child_autofree(panel)
	var controller: RunController = RunControllerScript.new() as RunController
	controller.event_panel = panel
	add_child_autofree(controller)
	return {
		"controller": controller,
		"panel": panel,
	}


func _install_fake_shop() -> void:
	_original_shop = get_tree().root.get_node_or_null("Shop")
	if _original_shop != null:
		_original_shop.name = "OriginalShopForRunEventTest"
	_fake_shop = FakeShop.new()
	_fake_shop.name = "Shop"
	get_tree().root.add_child(_fake_shop)


func _remove_fake_shop() -> void:
	if _fake_shop != null and is_instance_valid(_fake_shop):
		get_tree().root.remove_child(_fake_shop)
		_fake_shop.free()
	_fake_shop = null
	if _original_shop != null and is_instance_valid(_original_shop):
		_original_shop.name = "Shop"
	_original_shop = null
