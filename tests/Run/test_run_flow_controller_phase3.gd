extends GutTest

const ControllerScript: GDScript = preload("res://Run/run_flow_controller.gd")
const RewardServiceScript: GDScript = preload("res://Run/reward_service.gd")
const EventResolverScript: GDScript = preload("res://Run/event_resolver.gd")


class ControlledRandom extends RunRandomSource:
	var queued_ranges: Array[int] = []

	func push_range(value: int) -> void:
		queued_ranges.append(value)

	func range_int(minimum: int, maximum: int) -> int:
		if queued_ranges.is_empty():
			return minimum
		return clampi(queued_ranges.pop_front(), minimum, maximum)

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


class FakeGateway extends BattleGateway:
	var started_plans: Array[BattlePlan] = []
	var active_plan: BattlePlan = null
	var active_token: RunFlowToken = null
	var clear_count: int = 0
	var fail_start: bool = false
	var complete_synchronously: bool = false

	func start(plan: BattlePlan, token: RunFlowToken) -> bool:
		started_plans.append(plan)
		if fail_start:
			return false
		active_plan = plan
		active_token = token
		if complete_synchronously:
			complete_active()
		return true

	func clear(_restart: bool = false) -> void:
		clear_count += 1
		active_plan = null
		active_token = null

	func force_complete_current_battle() -> bool:
		if active_plan == null or active_token == null:
			return false
		complete_active()
		return true

	func complete_active() -> void:
		if active_plan == null or active_token == null:
			return
		var plan := active_plan
		var token := active_token
		active_plan = null
		active_token = null
		battle_completed.emit(token, plan.battle_id, plan)

	func emit_marble_fall(marble: RigidBody2D) -> void:
		if active_token != null:
			marble_fell.emit(active_token, marble)


func test_first_weak_and_node_offer_policy_are_typed_unique_and_guaranteed() -> void:
	var fixture := _fixture(RunNodeOption.Kind.ELITE)
	var controller := fixture.controller as RunFlowController
	var gateway := fixture.gateway as FakeGateway

	assert_true(controller.start_run())
	assert_eq(gateway.started_plans.size(), 1)
	assert_eq(gateway.started_plans[0].origin, BattlePlan.Origin.RUN_START)
	assert_eq(gateway.started_plans[0].group.kind, BattleGroupDef.Kind.WEAK_NORMAL)
	assert_eq(controller.current_state().floor_number, 1)

	gateway.complete_active()
	var normal := controller.current_reward_offer()
	assert_not_null(normal)
	assert_eq(normal.policy, BattlePlan.RewardPolicy.NORMAL)
	assert_true(_claim_one_reward(controller))

	var offer := controller.current_node_offer()
	assert_not_null(offer)
	assert_eq(offer.floor_number, 2)
	assert_eq(offer.choice_wave_index, 1)
	assert_eq(offer.choices().size(), 3)
	var kinds: Array[int] = []
	for choice: RunNodeChoice in offer.choices():
		assert_false(kinds.has(choice.kind))
		kinds.append(choice.kind)
		if choice.kind in [RunNodeOption.Kind.BATTLE, RunNodeOption.Kind.ELITE]:
			assert_not_null(choice.battle_plan, "battle choices are prebuilt")
	assert_has(kinds, RunNodeOption.Kind.ELITE)


func test_normal_and_elite_battles_route_by_plan_reward_policy() -> void:
	var fixture := _fixture(RunNodeOption.Kind.ELITE)
	var controller := fixture.controller as RunFlowController
	var gateway := fixture.gateway as FakeGateway
	_reach_floor_two_choices(fixture)

	var elite := _choice(controller.current_node_offer(), RunNodeOption.Kind.ELITE)
	assert_true(controller.select_node(
		controller.current_node_offer().token,
		controller.current_node_offer().offer_id,
		elite.option_id
	))
	assert_eq(controller.current_state().battle_plan.reward_policy, BattlePlan.RewardPolicy.ELITE)
	gateway.complete_active()
	var elite_reward := controller.current_reward_offer()
	assert_eq(elite_reward.policy, BattlePlan.RewardPolicy.ELITE)
	assert_eq(elite_reward.mode, RewardOffer.Mode.ELITE_CLAIM_ALL)
	assert_true(_claim_all_rewards(controller))
	assert_eq(controller.current_state().phase, RunState.Phase.CHOOSING_NODE)
	assert_eq(controller.current_state().floor_number, 3)


func test_skip_current_battle_routes_through_normal_reward_once() -> void:
	var fixture := _fixture()
	var controller := fixture.controller as RunFlowController
	var gateway := fixture.gateway as FakeGateway
	var completed_ids: Array[StringName] = []
	controller.battle_completed.connect(func(_token: RunFlowToken, _id: StringName, _plan: BattlePlan) -> void:
		completed_ids.append(_id)
	)

	assert_true(controller.start_run())
	assert_true(controller.skip_current_battle())
	assert_eq(completed_ids.size(), 1)
	assert_eq(controller.current_state().phase, RunState.Phase.REWARD_ACTIVE)
	assert_not_null(controller.current_reward_offer())
	assert_false(controller.skip_current_battle())
	assert_eq(completed_ids.size(), 1)
	assert_null(gateway.active_plan)


func test_event_escape_fight_and_result_routes_are_table_driven() -> void:
	var cases: Array[Dictionary] = [
		{&"route": &"escape", &"event_roll": 1},
		{&"route": &"fight", &"event_roll": 1},
		{&"route": &"result", &"event_roll": 0},
	]
	for case: Dictionary in cases:
		var fixture := _fixture(RunNodeOption.Kind.EVENT)
		var controller := fixture.controller as RunFlowController
		var gateway := fixture.gateway as FakeGateway
		var random := fixture.random as ControlledRandom
		_reach_floor_two_choices(fixture)
		random.push_range(int(case[&"event_roll"]))
		var event_choice := _choice(controller.current_node_offer(), RunNodeOption.Kind.EVENT)
		assert_true(controller.select_node(
			controller.current_node_offer().token,
			controller.current_node_offer().offer_id,
			event_choice.option_id
		), String(case[&"route"]))
		var event := controller.current_event()
		assert_not_null(event)
		match StringName(case[&"route"]):
			&"escape":
				assert_eq(event.event_id, EventResolverScript.EVENT_CROSSROADS)
				assert_true(controller.submit_event_intent(
					event.token, event.event_id,
					EventResolverScript.CROSSROADS_ESCAPE,
					EventResolver.EventIntent.CROSSROADS_ESCAPE
				))
				assert_eq(controller.current_state().floor_number, 3)
				assert_eq(controller.current_state().phase, RunState.Phase.CHOOSING_NODE)
			&"fight":
				assert_true(controller.submit_event_intent(
					event.token, event.event_id,
					EventResolverScript.CROSSROADS_FIGHT,
					EventResolver.EventIntent.CROSSROADS_FIGHT
				))
				assert_eq(controller.current_state().battle_origin, BattlePlan.Origin.EVENT)
				assert_eq(controller.current_state().reward_policy, BattlePlan.RewardPolicy.ELITE)
				gateway.complete_active()
				assert_eq(controller.current_reward_offer().policy, BattlePlan.RewardPolicy.ELITE)
			&"result":
				random.push_range(4)
				assert_true(controller.submit_event_intent(
					event.token, event.event_id,
					EventResolverScript.DICE_WAGER_20,
					EventResolver.EventIntent.DICE_WAGER_SMALL
				))
				var result_event := controller.current_event()
				assert_eq(controller.current_state().phase, RunState.Phase.EVENT_RESULT_ACTIVE)
				assert_true(result_event.token.matches(controller.current_state().token()))
				assert_true(controller.acknowledge_event_result(
					result_event.token, result_event.event_id
				))
				assert_eq(controller.current_state().floor_number, 3)


func test_upgrade_available_and_unavailable_routes_use_typed_revisions() -> void:
	for has_candidate: bool in [true, false]:
		var fixture := _fixture(RunNodeOption.Kind.UPGRADE)
		var scope := fixture.scope as RunScope
		var controller := fixture.controller as RunFlowController
		var failure_reasons: Array[StringName] = []
		controller.run_failed.connect(func(_token: RunFlowToken, reason: StringName) -> void:
			failure_reasons.append(reason)
		)
		var item: Item = null
		if has_candidate:
			item = _marble("upgrade-dark")
			assert_true(bool(scope.loadout.call("add", item)))
		_reach_floor_two_choices(fixture)
		var choice := _choice(controller.current_node_offer(), RunNodeOption.Kind.UPGRADE)
		var selected := controller.select_node(
			controller.current_node_offer().token,
			controller.current_node_offer().offer_id,
			choice.option_id
		)
		assert_true(selected, "upgrade selection failed: %s" % [failure_reasons])
		var offer := controller.current_upgrade_offer()
		assert_not_null(offer)
		if offer == null:
			continue
		assert_eq(offer.unavailable, not has_candidate)
		if has_candidate:
			var candidate := offer.candidates()[0]
			assert_eq(candidate.loadout_revision, int(scope.loadout.call("revision")))
			assert_eq(candidate.progression_revision, int(scope.progression.call("revision")))
			assert_true(controller.select_upgrade(offer.token, offer.offer_id, candidate.candidate_id))
			assert_eq(int(scope.progression.call("level_of", item)), 2)
		else:
			assert_true(controller.acknowledge_upgrade_unavailable(offer.token, offer.offer_id))
		assert_eq(controller.current_state().floor_number, 3)


func test_normal_and_devil_shop_tokens_close_exactly_once() -> void:
	var cases: Array[Dictionary] = [
		{&"kind": RunNodeOption.Kind.SHOP, &"id": &"shop"},
		{&"kind": RunNodeOption.Kind.DEVIL_SHOP, &"id": &"devil_shop"},
	]
	for case: Dictionary in cases:
		var fixture := _fixture(int(case[&"kind"]))
		var controller := fixture.controller as RunFlowController
		var rejected: Array[StringName] = []
		controller.command_rejected.connect(func(command: StringName, _reason: String) -> void:
			rejected.append(command)
		)
		_reach_floor_two_choices(fixture)
		var choice := _choice(controller.current_node_offer(), int(case[&"kind"]) as RunNodeOption.Kind)
		assert_true(controller.select_node(
			controller.current_node_offer().token,
			controller.current_node_offer().offer_id,
			choice.option_id
		))
		var shop_token := controller.current_state().token()
		assert_true(controller.close_shop(shop_token, StringName(case[&"id"])))
		assert_false(controller.close_shop(shop_token, StringName(case[&"id"])))
		assert_has(rejected, ControllerScript.CLOSE_SHOP)


func test_boss_bypasses_choices_and_none_policy_completes_only_boss() -> void:
	var fixture := _fixture(-1, 2)
	var controller := fixture.controller as RunFlowController
	var gateway := fixture.gateway as FakeGateway
	assert_true(controller.start_run())
	gateway.complete_active()
	assert_true(_claim_one_reward(controller))
	assert_eq(controller.current_state().floor_number, 2)
	assert_eq(controller.current_state().phase, RunState.Phase.BATTLE_ACTIVE)
	assert_eq(controller.current_state().battle_origin, BattlePlan.Origin.BOSS)
	assert_eq(controller.current_state().reward_policy, BattlePlan.RewardPolicy.NONE)
	assert_null(controller.current_node_offer())
	gateway.complete_active()
	assert_eq(controller.current_state().phase, RunState.Phase.COMPLETED)
	assert_true(controller.acknowledge_terminal(controller.current_state().token()))


func test_failure_restart_stale_and_marble_health_zero_are_guarded() -> void:
	var fixture := _fixture(-1, 6, 1)
	var controller := fixture.controller as RunFlowController
	var gateway := fixture.gateway as FakeGateway
	var rejected: Array[StringName] = []
	controller.command_rejected.connect(func(command: StringName, _reason: String) -> void:
		rejected.append(command)
	)
	gateway.fail_start = true
	assert_false(controller.start_run())
	assert_eq(controller.current_state().phase, RunState.Phase.FAILED)
	var failed_token := controller.current_state().token()
	gateway.fail_start = false
	assert_true(controller.restart_run(failed_token))
	assert_eq(controller.current_state().run_id, 2)
	assert_false(controller.restart_run(failed_token), "old terminal token cannot restart a live run")
	assert_has(rejected, ControllerScript.RESTART)

	var marble := RigidBody2D.new()
	add_child_autofree(marble)
	marble.add_to_group("marbles")
	gateway.emit_marble_fall(marble)
	assert_eq(controller.current_state().phase, RunState.Phase.FAILED)
	assert_eq(int((fixture.scope as RunScope).health.call("current")), 0)


func test_reentrant_external_command_is_rejected_but_sync_completion_is_ordered() -> void:
	var fixture := _fixture()
	var controller := fixture.controller as RunFlowController
	var gateway := fixture.gateway as FakeGateway
	var order: Array[StringName] = []
	var reentrant_results: Array[bool] = []
	gateway.complete_synchronously = true
	controller.battle_started.connect(func(_token: RunFlowToken, _plan: BattlePlan) -> void:
		order.append(&"started")
		reentrant_results.append(controller.start_run())
	)
	controller.battle_completed.connect(func(
		_token: RunFlowToken, _battle_id: StringName, _plan: BattlePlan
	) -> void:
		order.append(&"completed")
	)
	controller.reward_presented.connect(func(_offer: RewardOffer) -> void:
		order.append(&"reward")
	)

	assert_true(controller.start_run())
	assert_eq(reentrant_results, [false])
	assert_eq(order, [&"started", &"completed", &"reward"])
	assert_eq(controller.current_state().phase, RunState.Phase.REWARD_ACTIVE)


func _fixture(
	guaranteed_kind: int = -1,
	boss_floor: int = 6,
	initial_health: int = 3
) -> Dictionary:
	var stat := FakeStatSystem.new()
	add_child_autofree(stat)
	var scope := RunScope.new()
	add_child_autofree(scope)
	assert_true(scope.initialize(stat, 100, initial_health))
	var random := ControlledRandom.new()
	var floor_config := RunFloorConfig.new()
	floor_config.boss_floor = boss_floor
	if guaranteed_kind >= 0:
		var rule := RunFloorNodeRule.new()
		rule.floor_number = 2
		rule.node_kind = guaranteed_kind as RunNodeOption.Kind
		floor_config.guaranteed_node_rules = [rule]
	var reward := RewardServiceScript.new() as RewardService
	assert_true(reward.configure(
		scope.loadout, scope.progression, scope.wallet,
		BattleRewardConfig.new(), random
	))
	var event := EventResolverScript.new() as EventResolver
	assert_true(event.configure(scope.wallet, random))
	var gateway := FakeGateway.new()
	add_child_autofree(gateway)
	var controller := ControllerScript.new() as RunFlowController
	add_child_autofree(controller)
	assert_true(controller.configure(
		scope, BattlePlanFactory.new(), reward, event,
		floor_config, random, gateway
	))
	return {
		&"controller": controller,
		&"gateway": gateway,
		&"scope": scope,
		&"random": random,
	}


func _reach_floor_two_choices(fixture: Dictionary) -> void:
	var controller := fixture.controller as RunFlowController
	var gateway := fixture.gateway as FakeGateway
	assert_true(controller.start_run())
	gateway.complete_active()
	assert_eq(controller.current_reward_offer().policy, BattlePlan.RewardPolicy.NORMAL)
	assert_true(_claim_one_reward(controller))
	assert_eq(controller.current_state().phase, RunState.Phase.CHOOSING_NODE)


func _claim_one_reward(controller: RunFlowController) -> bool:
	var offer := controller.current_reward_offer()
	if offer == null or offer.remaining_options().is_empty():
		return false
	var option := offer.remaining_options()[0]
	return controller.select_reward(offer.token, offer.draft_id, option.offer_id)


func _claim_all_rewards(controller: RunFlowController) -> bool:
	var offer := controller.current_reward_offer()
	if offer == null:
		return false
	for option: RewardOption in offer.options():
		if not option.consumed and not controller.select_reward(
			offer.token, offer.draft_id, option.offer_id
		):
			return false
	return true


func _choice(offer: RunNodeOffer, kind: RunNodeOption.Kind) -> RunNodeChoice:
	for choice: RunNodeChoice in offer.choices():
		if choice.kind == kind:
			return choice
	return null


func _marble(id: String) -> Item:
	var item := Item.new()
	item.id = id
	item.type = Item.ItemType.MARBLE
	item.marble_type = Marble.MARBLE_TYPE.DEFAULT
	return item
