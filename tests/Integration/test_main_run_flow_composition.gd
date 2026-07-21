extends GutTest

const FakeStatSystemScript: GDScript = preload("res://tests/Loadout/fake_stat_system.gd")
const EffectManagerScript: GDScript = preload("res://Combat/effects/effect_manager.gd")
const MainScene: PackedScene = preload("res://Game/Bootstrap/main.tscn")
const RewardPanelScene: PackedScene = preload("res://Run/presentation/draft_reward_panel.tscn")


class ReadOnlyLoadout extends RefCounted:
	func current_skill() -> Item:
		return null


class FailingRunFlowController extends RunFlowController:
	static var configure_calls: int = 0

	func configure(
		scope_value: RunScope,
		factory_value: BattlePlanFactory,
		reward_value: RewardService,
		resolver_value: EventResolver,
		floor_config_value: RunFloorConfig,
		random_value: RunRandomSource,
		gateway_value: BattleGateway
	) -> bool:
		if scope_value == null or factory_value == null or reward_value == null \
				or resolver_value == null or floor_config_value == null \
				or random_value == null or gateway_value == null:
			return false
		configure_calls += 1
		return false


class TrackingRunFlowController extends RunFlowController:
	static var configure_calls: int = 0
	static var start_calls: int = 0

	func configure(
		scope_value: RunScope,
		factory_value: BattlePlanFactory,
		reward_value: RewardService,
		resolver_value: EventResolver,
		floor_config_value: RunFloorConfig,
		random_value: RunRandomSource,
		gateway_value: BattleGateway
	) -> bool:
		configure_calls += 1
		return scope_value != null and factory_value != null and reward_value != null \
			and resolver_value != null and floor_config_value != null \
			and random_value != null and gateway_value != null

	func start_run() -> bool:
		start_calls += 1
		return true


func before_each() -> void:
	FailingRunFlowController.configure_calls = 0
	TrackingRunFlowController.configure_calls = 0
	TrackingRunFlowController.start_calls = 0


func test_p3a_composition_shares_scope_random_configs_and_main_runtime_ports_without_start() -> void:
	var main: Node = autofree(MainScene.instantiate())
	var stats: Node = autofree(_stats())
	var effect_manager: Node = autofree(EffectManagerScript.new())
	assert_true(main.call("_setup_run_flow_composition", stats, effect_manager))
	var scope: RunScope = main.get("run_scope") as RunScope
	var spawner: BattleSpawner = main.get("battle_spawner") as BattleSpawner
	var enemies: Node2D = main.get("base_enemies") as Node2D
	var gateway: BattleGateway = main.get("battle_gateway") as BattleGateway
	var reward: RewardService = main.get("reward_service") as RewardService
	var resolver: EventResolver = main.get("event_resolver") as EventResolver
	var factory: BattlePlanFactory = main.get("battle_plan_factory") as BattlePlanFactory
	var controller: RunFlowController = main.get("run_flow_controller") as RunFlowController
	var random: RunRandomSource = main.get("run_random_source") as RunRandomSource

	assert_not_null(scope)
	assert_true(scope.is_initialized())
	assert_eq(spawner.get_parent(), main)
	assert_eq(enemies.get_parent(), main)
	assert_eq(gateway.get_parent(), main)
	assert_eq(controller.get_parent(), main)
	assert_eq(spawner.enemy_container, enemies)
	assert_eq(gateway.get("_spawner"), spawner)
	assert_eq(gateway.get("_base_enemy_container"), enemies)
	assert_eq(gateway.get("_level_parent"), main)

	assert_eq(reward.get("_loadout"), scope.loadout)
	assert_eq(reward.get("_progression"), scope.progression)
	assert_eq(reward.get("_wallet"), scope.wallet)
	assert_eq(resolver.get("_wallet"), scope.wallet)
	assert_eq(controller.get("_run_scope"), scope)
	assert_eq(controller.get("_factory"), factory)
	assert_eq(controller.get("_health"), scope.health)
	assert_eq(controller.get("_battle_flow").get("_gateway"), gateway)

	assert_eq(reward.get("_random_source"), random)
	assert_eq(resolver.get("_random_source"), random)
	assert_eq(controller.get("_random"), random)
	assert_eq(controller.get("_node_policy").get("_random"), random)
	assert_eq(controller.get("_event_flow").get("_random"), random)
	assert_eq(controller.get("_event_flow").get("_factory"), factory)
	assert_eq(
		(main.get("battle_reward_config") as Resource).resource_path,
		"res://Run/data/default_battle_reward_config.tres"
	)
	assert_eq(
		(main.get("run_floor_config") as Resource).resource_path,
		"res://Run/data/default_run_floor_config.tres"
	)

	assert_true((main.get("reset_battle_callable") as Callable).is_valid())
	assert_true((main.get("release_floating_texts_callable") as Callable).is_valid())
	assert_true((main.get("read_stat_callable") as Callable).is_valid())
	assert_eq(controller.current_state().phase, RunState.Phase.IDLE)
	assert_eq(controller.current_state().run_id, 0, "P3-A must not call start_run")
	assert_true(main.get_node_or_null("CanvasLayer/NodeChoicePanel") is NodeChoicePanel)
	assert_null(main.get("node_choice_panel"), "P3-A 不配置预置 UI")
	var original_random_id: int = random.get_instance_id()
	assert_true(main.call("_setup_run_flow_composition", stats, effect_manager))
	assert_eq(
		(main.get("run_random_source") as RunRandomSource).get_instance_id(),
		original_random_id,
		"idempotent setup must not create a second RNG"
	)

	main.call("_dispose_run_flow_composition")
	_assert_composition_cleared(main)
	main.call("_dispose_run_flow_composition")
	_assert_composition_cleared(main)


func test_p3b_production_wires_all_typed_adapters_and_starts_only_new_flow() -> void:
	var main: Node = autofree(MainScene.instantiate())
	main.set("skill_controller", main.get_node("SkillController") as SkillController)
	main.set("active_skill_slot", main.get_node("CanvasLayer/SkillSlot") as ActiveSkillSlot)
	var stats: Node = autofree(_stats())
	var effect_manager: Node = autofree(EffectManagerScript.new())
	var controller := TrackingRunFlowController.new()
	var pre_node_panel := main.get_node("CanvasLayer/NodeChoicePanel")
	var pre_reward_panel := main.get_node("CanvasLayer/DraftRewardPanel")
	var pre_event_panel := main.get_node("CanvasLayer/RunEventPanel")
	var pre_devil_shop := main.get_node("CanvasLayer/DevilShop")
	var pre_inventory := main.get_node("InventoryPanel")
	var pre_shop := main.get_node("Shop")

	assert_true(main.call(
		"_setup_run_flow",
		stats,
		effect_manager,
		{&"run_flow_controller": controller}
	))
	assert_eq(TrackingRunFlowController.configure_calls, 1)
	assert_eq(TrackingRunFlowController.start_calls, 1)
	assert_eq(main.get_node_or_null("RunFlowController"), controller)
	assert_null(main.get_node_or_null("RunController"))

	var scope: RunScope = main.get("run_scope") as RunScope
	var adapter: RunFlowUIAdapter = main.get("run_ui_adapter") as RunFlowUIAdapter
	var node_panel: NodeChoicePanel = main.get("node_choice_panel") as NodeChoicePanel
	var reward_panel: DraftRewardPanel = main.get("draft_reward_panel") as DraftRewardPanel
	var event_panel: RunEventPanel = main.get("run_event_panel") as RunEventPanel
	var inventory: InventoryPanel = main.get("inventory_panel") as InventoryPanel
	var normal_shop: Node = main.get("normal_shop") as Node
	var devil_shop: DevilShop = main.get("devil_shop") as DevilShop
	assert_not_null(adapter)
	assert_true(adapter.is_configured())
	assert_eq(node_panel, pre_node_panel)
	assert_eq(reward_panel, pre_reward_panel)
	assert_eq(event_panel, pre_event_panel)
	assert_eq(devil_shop, pre_devil_shop)
	assert_eq(inventory, pre_inventory)
	assert_eq(normal_shop, pre_shop)
	assert_eq(reward_panel.get("_loadout"), scope.loadout)
	assert_eq(event_panel.get("_wallet"), scope.wallet)
	assert_eq(inventory.get("_loadout"), scope.loadout)
	assert_eq(inventory.get("_progression"), scope.progression)
	assert_eq(normal_shop.get("_loadout"), scope.loadout)
	assert_eq(normal_shop.get("_progression"), scope.progression)
	assert_eq(normal_shop.get("_wallet"), scope.wallet)
	assert_eq(devil_shop.get("_loadout"), scope.loadout)
	assert_eq(devil_shop.get("_progression"), scope.progression)
	assert_eq(devil_shop.get("_wallet"), scope.wallet)
	assert_eq(devil_shop.get("_health"), scope.health)

	assert_true(controller.is_connected(
		&"node_options_presented", Callable(adapter, "_on_node_options_presented")
	))
	assert_true(controller.is_connected(
		&"reward_presented", Callable(adapter, "_on_reward_presented")
	))
	assert_true(controller.is_connected(
		&"event_presented", Callable(adapter, "_on_event_presented")
	))
	assert_true(controller.is_connected(
		&"upgrade_presented", Callable(adapter, "_on_upgrade_presented")
	))
	assert_true(controller.is_connected(&"shop_opened", Callable(adapter, "_on_shop_opened")))
	assert_true(controller.is_connected(&"health_changed", Callable(adapter, "_on_health_changed")))
	assert_true(controller.is_connected(&"floor_changed", Callable(adapter, "_on_floor_changed")))
	assert_true(controller.is_connected(&"run_failed", Callable(adapter, "_on_run_failed")))
	assert_true(node_panel.is_connected(
		&"node_choice_intent", Callable(adapter, "_on_node_choice_intent")
	))
	assert_true(reward_panel.is_connected(
		&"reward_intent", Callable(adapter, "_on_reward_intent")
	))
	assert_true(event_panel.is_connected(&"event_intent", Callable(adapter, "_on_event_intent")))
	assert_true(inventory.is_connected(&"upgrade_intent", Callable(adapter, "_on_upgrade_intent")))
	assert_true(normal_shop.is_connected(
		&"shop_close_intent", Callable(adapter, "_on_shop_close_intent")
	))
	assert_true(devil_shop.is_connected(
		&"shop_close_intent", Callable(adapter, "_on_shop_close_intent")
	))

	main.call("_dispose_run_flow_composition")
	_assert_composition_cleared(main)
	assert_eq(main.get_node_or_null("CanvasLayer/NodeChoicePanel"), pre_node_panel)
	assert_eq(main.get_node_or_null("CanvasLayer/DraftRewardPanel"), pre_reward_panel)
	assert_eq(main.get_node_or_null("CanvasLayer/RunEventPanel"), pre_event_panel)
	assert_eq(main.get_node_or_null("CanvasLayer/DevilShop"), pre_devil_shop)
	assert_eq(main.get_node_or_null("InventoryPanel"), pre_inventory)
	assert_eq(main.get_node_or_null("Shop"), pre_shop)
	assert_null(reward_panel.get("_loadout"))
	assert_null(event_panel.get("_wallet"))
	assert_null(inventory.get("_loadout"))
	assert_null(normal_shop.get("_wallet"))
	assert_null(devil_shop.get("_health"))


func test_dispose_then_second_run_reuses_preplaced_ui_without_old_bindings() -> void:
	var main: Node = autofree(MainScene.instantiate())
	main.set("skill_controller", main.get_node("SkillController") as SkillController)
	main.set("active_skill_slot", main.get_node("CanvasLayer/SkillSlot") as ActiveSkillSlot)
	var stats: Node = autofree(_stats())
	var effect_manager: Node = autofree(EffectManagerScript.new())
	var ui_paths: Array[NodePath] = [
		^"CanvasLayer/NodeChoicePanel", ^"CanvasLayer/DraftRewardPanel",
		^"CanvasLayer/RunEventPanel", ^"CanvasLayer/DevilShop",
		^"Shop", ^"InventoryPanel",
	]
	var original_ids: Array[int] = []
	for path: NodePath in ui_paths:
		original_ids.append(main.get_node(path).get_instance_id())

	assert_true(main.call(
		"_setup_run_flow", stats, effect_manager,
		{&"run_flow_controller": TrackingRunFlowController.new()}
	))
	var inventory := main.get("inventory_panel") as InventoryPanel
	var upgrade_dialog := main.get_node(
		"InventoryPanel/UI/SkillReplaceDialog"
	) as SkillReplaceDialog
	assert_eq(inventory.get("_upgrade_dialog"), upgrade_dialog)
	var stale_item := Item.new()
	watch_signals(upgrade_dialog)
	upgrade_dialog.set("_pending_skill", stale_item)
	upgrade_dialog.set("_pending_upgrade", stale_item)
	upgrade_dialog.set("_upgrade_notice_active", true)
	upgrade_dialog.show()
	main.call("_dispose_run_flow_composition")
	assert_null(upgrade_dialog.get("_pending_skill"))
	assert_null(upgrade_dialog.get("_pending_upgrade"))
	assert_false(bool(upgrade_dialog.get("_upgrade_notice_active")))
	assert_false(upgrade_dialog.visible)
	upgrade_dialog.call("_on_confirm_pressed")
	assert_signal_not_emitted(upgrade_dialog, &"confirmed")
	assert_signal_not_emitted(upgrade_dialog, &"upgrade_confirmed")
	assert_signal_not_emitted(upgrade_dialog, &"upgrade_notice_dismissed")
	assert_true(main.call(
		"_setup_run_flow", stats, effect_manager,
		{&"run_flow_controller": TrackingRunFlowController.new()}
	))
	for index: int in range(ui_paths.size()):
		assert_eq(main.get_node(ui_paths[index]).get_instance_id(), original_ids[index])
	var scope: RunScope = main.get("run_scope") as RunScope
	assert_eq((main.get("draft_reward_panel") as DraftRewardPanel).get("_loadout"), scope.loadout)
	assert_eq((main.get("run_event_panel") as RunEventPanel).get("_wallet"), scope.wallet)
	assert_eq((main.get("inventory_panel") as InventoryPanel).get("_progression"), scope.progression)


func test_controller_configure_failure_rolls_back_every_owned_component_and_created_scope() -> void:
	var main: Node = autofree(MainScene.instantiate())
	var stats: Node = autofree(_stats())
	var effect_manager: Node = autofree(EffectManagerScript.new())
	var failing_controller := FailingRunFlowController.new()

	assert_false(main.call(
		"_setup_run_flow_composition",
		stats,
		effect_manager,
		{&"run_flow_controller": failing_controller}
	))
	assert_eq(FailingRunFlowController.configure_calls, 1)
	assert_null(main.get("run_scope"), "scope created by a failed composition must be discarded")
	_assert_composition_cleared(main)
	assert_null(main.get_node_or_null("BattleSpawner"))
	assert_null(main.get_node_or_null("Enemies"))
	assert_null(main.get_node_or_null("BattleGateway"))
	assert_null(main.get_node_or_null("RunFlowController"))

	main.call("_dispose_run_flow_composition")
	_assert_composition_cleared(main)


func test_reward_panel_emits_typed_identity_once_without_settling_reward() -> void:
	var panel: DraftRewardPanel = autofree(RewardPanelScene.instantiate()) as DraftRewardPanel
	var token := RunFlowToken.new(4, 2, 7)
	var option := RewardOption.gold(&"gold-offer", 25)
	var offer := RewardOffer.new(
		token,
		BattlePlan.RewardPolicy.NORMAL,
		&"normal-battle",
		[option] as Array[RewardOption],
		&"draft-identity",
		RewardOffer.Mode.NORMAL_EXCLUSIVE
	)
	assert_true(panel.configure(ReadOnlyLoadout.new()))
	assert_true(panel.present_offer(offer))
	watch_signals(panel)

	panel.call("_on_button_pressed", 0)
	panel.call("_on_button_pressed", 0)
	assert_signal_emit_count(panel, "reward_intent", 1)
	assert_signal_emitted_with_parameters(panel, "reward_intent", [
		token,
		&"draft-identity",
		&"gold-offer",
	])
	assert_false(option.consumed, "presentation must not settle or mutate the reward")
	assert_false(offer.consumed)


func test_setup_uses_preplaced_scene_bootstrap_nodes_not_new_instances() -> void:
	var main: Node = autofree(MainScene.instantiate())
	var stats: Node = autofree(_stats())
	var effect_manager: Node = autofree(EffectManagerScript.new())
	var pre_spawner := main.get_node("BattleSpawner")
	var pre_enemies := main.get_node("Enemies")
	var pre_gateway := main.get_node("BattleGateway")
	var pre_controller := main.get_node("RunFlowController")

	assert_true(main.call("_setup_run_flow_composition", stats, effect_manager))
	assert_eq(main.get("battle_spawner"), pre_spawner, "pre-placed BattleSpawner used")
	assert_eq(main.get("base_enemies"), pre_enemies, "pre-placed Enemies used")
	assert_eq(main.get("battle_gateway"), pre_gateway, "pre-placed BattleGateway used")
	assert_eq(main.get("run_flow_controller"), pre_controller, "pre-placed RunFlowController used")


func test_valid_override_replaces_the_preplaced_slot() -> void:
	var main: Node = autofree(MainScene.instantiate())
	var stats: Node = autofree(_stats())
	var effect_manager: Node = autofree(EffectManagerScript.new())
	var pre_spawner: Node = main.get_node("BattleSpawner")
	var override_spawner := BattleSpawner.new()

	assert_true(main.call(
		"_setup_run_flow_composition", stats, effect_manager,
		{&"battle_spawner": override_spawner}
	))
	assert_eq(main.get("battle_spawner"), override_spawner)
	assert_eq(override_spawner.name, "BattleSpawner")
	assert_eq(override_spawner.get_parent(), main)
	assert_false(is_instance_valid(pre_spawner), "replaced pre-placed node is freed")


func test_wrong_type_override_is_rejected_and_preplaced_node_kept() -> void:
	var main: Node = autofree(MainScene.instantiate())
	var stats: Node = autofree(_stats())
	var effect_manager: Node = autofree(EffectManagerScript.new())
	var pre_spawner: Node = main.get_node("BattleSpawner")
	var wrong_type := Node.new()
	autofree(wrong_type)

	assert_true(main.call(
		"_setup_run_flow_composition", stats, effect_manager,
		{&"battle_spawner": wrong_type}
	))
	assert_eq(main.get("battle_spawner"), pre_spawner, "wrong-typed override treated as none")
	assert_true(is_instance_valid(pre_spawner), "pre-placed node not disturbed")


func test_externally_parented_override_is_rejected_without_releasing_anything() -> void:
	var main: Node = autofree(MainScene.instantiate())
	var stats: Node = autofree(_stats())
	var effect_manager: Node = autofree(EffectManagerScript.new())
	var pre_spawner: Node = main.get_node("BattleSpawner")
	var external_parent := Node.new()
	autofree(external_parent)
	var override_spawner := BattleSpawner.new()
	external_parent.add_child(override_spawner)

	assert_true(main.call(
		"_setup_run_flow_composition", stats, effect_manager,
		{&"battle_spawner": override_spawner}
	))
	assert_eq(main.get("battle_spawner"), pre_spawner, "externally owned override rejected")
	assert_true(is_instance_valid(pre_spawner))
	assert_eq(override_spawner.get_parent(), external_parent, "external node untouched")


func test_dispose_then_resetup_recreates_dynamic_bootstrap_slots() -> void:
	var main: Node = autofree(MainScene.instantiate())
	var stats: Node = autofree(_stats())
	var effect_manager: Node = autofree(EffectManagerScript.new())
	assert_true(main.call("_setup_run_flow_composition", stats, effect_manager))
	main.call("_dispose_run_flow_composition")
	assert_null(main.get_node_or_null("BattleSpawner"))

	assert_true(main.call("_setup_run_flow_composition", stats, effect_manager))
	var spawner: Node = main.get_node_or_null("BattleSpawner")
	assert_not_null(spawner)
	assert_true(spawner is BattleSpawner)
	assert_eq(spawner.get_parent(), main)
	assert_true(main.get_node_or_null("Enemies") is Node2D)
	assert_true(main.get_node_or_null("BattleGateway") is BattleGateway)
	assert_true(main.get_node_or_null("RunFlowController") is RunFlowController)


func _assert_composition_cleared(main: Node) -> void:
	for property_name: StringName in [
		&"battle_spawner",
		&"base_enemies",
		&"battle_gateway",
		&"reward_service",
		&"event_resolver",
		&"battle_plan_factory",
		&"run_flow_controller",
		&"run_random_source",
		&"battle_reward_config",
		&"run_floor_config",
		&"run_ui_adapter",
	]:
		assert_null(main.get(property_name), "%s should be cleared" % property_name)
	assert_false((main.get("reset_battle_callable") as Callable).is_valid())
	assert_false((main.get("release_floating_texts_callable") as Callable).is_valid())
	assert_false((main.get("read_stat_callable") as Callable).is_valid())


func _stats() -> Node:
	var stats: Node = FakeStatSystemScript.new()
	stats.set("values", {
		"marble_slot_count": 3,
		"relic_slot_count": 3,
		"buy_price_multiplier": 1.0,
		"sell_price_multiplier": 0.5,
	})
	return stats
