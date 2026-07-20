extends GutTest

const RunStateScript: GDScript = preload("res://Run/domain/run_state.gd")
const BattlePlanScript: GDScript = preload("res://Run/domain/battle_plan.gd")
const RewardOptionScript: GDScript = preload("res://Run/domain/reward_option.gd")
const RewardOfferScript: GDScript = preload("res://Run/domain/reward_offer.gd")
const EventChoiceScript: GDScript = preload("res://Run/domain/event_choice.gd")
const EventOfferScript: GDScript = preload("res://Run/domain/event_offer.gd")
const RandomSourceScript: GDScript = preload("res://Run/run_random_source.gd")


func test_begin_run_is_only_run_identity_increment_and_node_advance_is_atomic() -> void:
	var state: RunState = RunStateScript.new()
	assert_eq(state.phase, RunState.Phase.IDLE)
	assert_false(state.advance_to_node(&"battle"))
	assert_true(state.begin_run())
	assert_eq(state.run_id, 1)
	assert_eq(state.floor_number, 0)
	assert_eq(state.node_id, 0)
	assert_eq(state.phase_id, 0)

	assert_true(state.begin_first_battle(_run_start_plan()))
	assert_eq(state.run_id, 1)
	assert_eq(state.floor_number, 1)
	assert_eq(state.node_id, 1)
	assert_eq(state.node_kind, &"battle")
	assert_eq(state.phase, RunState.Phase.BATTLE_ACTIVE)
	assert_eq(state.phase_id, 1)
	assert_true(state.token().is_valid())
	assert_false(state.begin_run(), "活跃 run 不得重置 identity")

	assert_true(state.present_reward())
	assert_true(state.advance_to_node())
	assert_eq(state.run_id, 1)
	assert_eq(state.floor_number, 2)
	assert_eq(state.node_id, 2)
	assert_eq(state.node_kind, &"")
	assert_eq(state.phase, RunState.Phase.CHOOSING_NODE)


func test_each_presentation_changes_phase_identity_and_rejects_stale_token() -> void:
	var state: RunState = _state_at_choice(&"event")
	var choice_token: RunFlowToken = state.token()
	assert_true(state.accepts(choice_token))

	assert_true(state.present_event())
	assert_eq(state.phase, RunState.Phase.EVENT_ACTIVE)
	assert_eq(state.phase_id, choice_token.phase_id + 1)
	assert_false(state.accepts(choice_token))
	var event_token: RunFlowToken = state.token()

	assert_true(state.present_event_result())
	assert_eq(state.phase, RunState.Phase.EVENT_RESULT_ACTIVE)
	assert_eq(state.phase_id, event_token.phase_id + 1)


func test_battle_plan_origin_and_reward_policy_survive_into_reward_phase() -> void:
	var state: RunState = _state_at_choice(&"event_battle")
	assert_true(state.present_event())
	assert_eq(state.phase, RunState.Phase.EVENT_ACTIVE)
	var group := BattleGroupDef.new()
	group.id = "event_strong"
	var plan: BattlePlan = BattlePlanScript.new(
		&"event_strong",
		group,
		BattlePlan.Origin.EVENT,
		BattlePlan.RewardPolicy.ELITE
	)

	assert_true(state.begin_battle(plan))
	assert_eq(state.battle_origin, BattlePlan.Origin.EVENT)
	assert_eq(state.reward_policy, BattlePlan.RewardPolicy.ELITE)
	assert_eq(state.battle_plan, plan)
	assert_true(state.present_reward())
	assert_eq(state.battle_origin, BattlePlan.Origin.EVENT)
	assert_eq(state.reward_policy, BattlePlan.RewardPolicy.ELITE)
	assert_eq(state.battle_plan, plan)


func test_terminal_phase_blocks_every_transition_until_a_new_run_begins() -> void:
	var state: RunState = _state_at_reward()
	var boss_group := BattleGroupDef.new()
	boss_group.id = "boss"
	var boss_plan: BattlePlan = BattlePlanScript.new(
		&"boss", boss_group, BattlePlan.Origin.BOSS, BattlePlan.RewardPolicy.NONE
	)
	assert_true(state.advance_to_battle(&"boss", boss_plan))
	assert_eq(state.phase, RunState.Phase.BATTLE_ACTIVE)
	assert_true(state.complete())
	var terminal_token: RunFlowToken = state.token()
	assert_true(state.is_terminal())
	assert_false(state.present_reward())
	assert_false(state.present_event())
	assert_false(state.advance_to_node(&"battle"))
	assert_false(state.fail())
	assert_eq(state.token().phase_id, terminal_token.phase_id)

	assert_true(state.begin_run())
	assert_eq(state.run_id, 2)
	assert_eq(state.phase, RunState.Phase.IDLE)
	assert_eq(state.node_id, 0)
	assert_eq(state.phase_id, 0)


func test_reward_and_event_offers_defensively_copy_typed_options() -> void:
	var state: RunState = _state_at_choice(&"reward")
	var reward_options: Array[RewardOption] = [RewardOptionScript.gold(&"gold", 20)]
	var reward_offer: RewardOffer = RewardOfferScript.new(
		state.token(), BattlePlan.RewardPolicy.NORMAL, &"normal_battle", reward_options
	)
	reward_options.clear()
	var reward_view: Array[RewardOption] = reward_offer.options()
	reward_view.clear()
	assert_eq(reward_offer.options().size(), 1)
	assert_eq(reward_offer.option_by_id(&"gold").gold_amount, 20)

	var event_choices: Array[RunEventChoice] = [
		EventChoiceScript.new(&"leave", RunEventChoice.Kind.FINISH)
	]
	var event_offer: RunEventOffer = EventOfferScript.new(state.token(), &"crossroads", event_choices)
	event_choices.clear()
	var event_view: Array[RunEventChoice] = event_offer.choices()
	event_view.clear()
	assert_eq(event_offer.choices().size(), 1)
	assert_eq(event_offer.choice_by_id(&"leave").kind, RunEventChoice.Kind.FINISH)


func test_seeded_random_source_is_repeatable_and_weighted_index_handles_empty_weight() -> void:
	var first: RunRandomSource = RandomSourceScript.new(9876)
	var second: RunRandomSource = RandomSourceScript.new(9876)
	var first_values: Array[int] = []
	var second_values: Array[int] = []
	for index: int in range(8):
		first_values.append(first.range_int(1, 100))
		second_values.append(second.range_int(1, 100))
	assert_eq(first_values, second_values)
	assert_eq(first.weighted_index(PackedInt32Array([0, 10, 0])), 1)
	assert_eq(first.weighted_index(PackedInt32Array([0, -2, 0])), -1)


func _run_start_plan() -> BattlePlan:
	var group := BattleGroupDef.new()
	group.id = "run_start"
	return BattlePlanScript.new(
		&"run_start", group, BattlePlan.Origin.RUN_START, BattlePlan.RewardPolicy.NORMAL
	)


## Legal path to REWARD_ACTIVE: begin_run -> first normal-reward battle -> reward.
func _state_at_reward() -> RunState:
	var state: RunState = RunStateScript.new()
	assert_true(state.begin_run())
	assert_true(state.begin_first_battle(_run_start_plan()))
	assert_true(state.present_reward())
	assert_eq(state.phase, RunState.Phase.REWARD_ACTIVE)
	return state


## Legal path to CHOOSING_NODE: first battle -> reward -> advance. The kind
## argument is a Phase 2 compatibility shim; the current state machine commits
## node kind only through select_node()/advance_to_battle().
func _state_at_choice(_kind: StringName = &"") -> RunState:
	var state: RunState = _state_at_reward()
	assert_true(state.advance_to_node())
	assert_eq(state.phase, RunState.Phase.CHOOSING_NODE)
	return state
