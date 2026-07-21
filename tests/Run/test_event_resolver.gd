extends GutTest

const ResolverScript: GDScript = preload("res://Run/application/event_resolver.gd")
const TokenScript: GDScript = preload("res://Run/domain/run_flow_token.gd")


class ControlledRandom extends RunRandomSource:
	var values: Array[int] = []

	func _init(initial_values: Array[int] = []) -> void:
		values = initial_values.duplicate()

	func range_int(_minimum: int, _maximum: int) -> int:
		return values.pop_front() if not values.is_empty() else _minimum


class TestWallet extends RefCounted:
	signal changed(value: int)

	const NONE := 0
	const BEFORE_MUTATION := 1
	const AFTER_MUTATION := 2

	var amount: int
	var debit_failure: int = NONE
	var credit_failure: int = NONE
	var restore_fails: bool = false

	func _init(starting_amount: int) -> void:
		amount = starting_amount

	func balance() -> int:
		return amount

	func can_debit(value: int) -> bool:
		return value >= 0 and amount >= value

	func debit(value: int) -> bool:
		if debit_failure == BEFORE_MUTATION:
			return false
		amount -= value
		changed.emit(amount)
		return debit_failure != AFTER_MUTATION

	func credit(value: int) -> bool:
		if credit_failure == BEFORE_MUTATION:
			return false
		amount += value
		changed.emit(amount)
		return credit_failure != AFTER_MUTATION

	func revision() -> int:
		return {&"amount": amount}.hash()

	func snapshot() -> Dictionary:
		return {&"amount": amount}

	func restore(state: Dictionary) -> bool:
		if restore_fails:
			return false
		amount = int(state[&"amount"])
		changed.emit(amount)
		return true


var _token: RunFlowToken


func before_each() -> void:
	_token = TokenScript.new(7, 11, 13)


func test_controlled_event_selection_returns_stable_typed_presentations() -> void:
	var wallet := TestWallet.new(100)
	var random := ControlledRandom.new([0, 1])
	var resolver: EventResolver = ResolverScript.new()
	assert_true(resolver.configure(wallet, random))

	var dice: EventPresentation = resolver.present(_token)
	assert_eq(dice.event_id, ResolverScript.EVENT_DICE)
	var dice_options := dice.option_ids()
	assert_eq(dice_options.size(), 3)
	assert_eq(dice_options[0], ResolverScript.DICE_WAGER_20)
	assert_eq(dice_options[1], ResolverScript.DICE_WAGER_60)
	assert_eq(dice_options[2], ResolverScript.DICE_LEAVE)
	assert_null(resolver.present(_token), "an active session cannot be replaced")
	assert_true(resolver.clear_active_session())
	var crossroads: EventPresentation = resolver.present(_token)
	assert_eq(crossroads.event_id, ResolverScript.EVENT_CROSSROADS)
	var crossroads_options := crossroads.option_ids()
	assert_eq(crossroads_options.size(), 2)
	assert_eq(crossroads_options[0], ResolverScript.CROSSROADS_FIGHT)
	assert_eq(crossroads_options[1], ResolverScript.CROSSROADS_ESCAPE)


func test_wager_balance_boundaries_and_ui_cannot_supply_economy_values() -> void:
	for case: Dictionary in [
		{&"balance": 19, &"option": ResolverScript.DICE_WAGER_20, &"intent": ResolverScript.EventIntent.DICE_WAGER_SMALL},
		{&"balance": 59, &"option": ResolverScript.DICE_WAGER_60, &"intent": ResolverScript.EventIntent.DICE_WAGER_LARGE},
	]:
		var wallet := TestWallet.new(int(case[&"balance"]))
		var resolver := _resolver(wallet, ControlledRandom.new([6]))
		var presentation := resolver.present_event(_token, ResolverScript.EVENT_DICE)
		var result: EventResolution = resolver.resolve(
			presentation.token, presentation.event_id, case[&"option"], case[&"intent"]
		)
		assert_eq(result.code, EventResolution.Code.INSUFFICIENT_FUNDS)
		assert_eq(wallet.amount, int(case[&"balance"]))
		assert_false(presentation.consumed)

	for case: Dictionary in [
		{&"balance": 20, &"option": ResolverScript.DICE_WAGER_20, &"intent": ResolverScript.EventIntent.DICE_WAGER_SMALL, &"expected": 30},
		{&"balance": 60, &"option": ResolverScript.DICE_WAGER_60, &"intent": ResolverScript.EventIntent.DICE_WAGER_LARGE, &"expected": 120},
	]:
		var wallet := TestWallet.new(int(case[&"balance"]))
		var resolver := _resolver(wallet, ControlledRandom.new([6]))
		var presentation := resolver.present_event(_token, ResolverScript.EVENT_DICE)
		var result: EventResolution = resolver.resolve(
			presentation.token, presentation.event_id, case[&"option"], case[&"intent"]
		)
		assert_true(result.was_resolved())
		assert_eq(wallet.amount, int(case[&"expected"]))


func test_controlled_winning_and_losing_rolls_settle_20_to_30() -> void:
	for roll: int in [1, 3, 4, 6]:
		var wallet := TestWallet.new(100)
		var resolver := _resolver(wallet, ControlledRandom.new([roll]))
		var presentation := resolver.present_event(_token, ResolverScript.EVENT_DICE)
		var result: EventResolution = resolver.resolve(
			presentation.token, presentation.event_id,
			ResolverScript.DICE_WAGER_20, ResolverScript.EventIntent.DICE_WAGER_SMALL
		)
		var expected_delta := 10 if roll > 3 else -20
		assert_eq(result.action, EventResolution.Action.SHOW_RESULT)
		assert_eq(result.roll, roll)
		assert_eq(result.gold_delta, expected_delta)
		assert_eq(wallet.amount, 100 + expected_delta)


func test_invalid_roll_is_rejected_before_any_wallet_mutation() -> void:
	for roll: int in [0, 7]:
		var wallet := TestWallet.new(100)
		var resolver := _resolver(wallet, ControlledRandom.new([roll]))
		var presentation := resolver.present_event(_token, ResolverScript.EVENT_DICE)
		var result: EventResolution = resolver.resolve(
			presentation.token, presentation.event_id,
			ResolverScript.DICE_WAGER_20, ResolverScript.EventIntent.DICE_WAGER_SMALL
		)
		assert_eq(result.code, EventResolution.Code.INVALID_ROLL)
		assert_eq(wallet.amount, 100)
		assert_false(presentation.consumed)


func test_dice_leave_is_zero_mutation_consumes_and_advances() -> void:
	var wallet := TestWallet.new(9)
	var resolver := _resolver(wallet, ControlledRandom.new())
	var presentation := resolver.present_event(_token, ResolverScript.EVENT_DICE)

	var result: EventResolution = resolver.resolve(
		presentation.token, presentation.event_id,
		ResolverScript.DICE_LEAVE, ResolverScript.EventIntent.DICE_LEAVE
	)

	assert_true(result.was_resolved())
	assert_eq(result.action, EventResolution.Action.ADVANCE_NODE)
	assert_eq(wallet.amount, 9)
	assert_true(presentation.consumed)
	assert_null(resolver.active_presentation())


func test_wager_requires_new_result_token_before_acknowledging_advance() -> void:
	var wallet := TestWallet.new(100)
	var resolver := _resolver(wallet, ControlledRandom.new([4]))
	var choice := resolver.present_event(_token, ResolverScript.EVENT_DICE)
	var settled: EventResolution = resolver.resolve(
		choice.token, choice.event_id,
		ResolverScript.DICE_WAGER_20, ResolverScript.EventIntent.DICE_WAGER_SMALL
	)
	var result_phase: EventPresentation = settled.presentation
	assert_eq(result_phase.phase, EventPresentation.Phase.RESULT)
	assert_eq(result_phase.token.phase_id, choice.token.phase_id + 1)

	var stale: EventResolution = resolver.resolve(
		choice.token, choice.event_id,
		ResolverScript.RESULT_CONTINUE, ResolverScript.EventIntent.ACKNOWLEDGE_RESULT
	)
	assert_eq(stale.code, EventResolution.Code.STALE_TOKEN)
	var advanced: EventResolution = resolver.resolve(
		result_phase.token, result_phase.event_id,
		ResolverScript.RESULT_CONTINUE, ResolverScript.EventIntent.ACKNOWLEDGE_RESULT
	)
	assert_eq(advanced.action, EventResolution.Action.ADVANCE_NODE)
	assert_null(resolver.active_presentation())
	assert_eq(
		resolver.resolve(
			result_phase.token, result_phase.event_id,
			ResolverScript.RESULT_CONTINUE, ResolverScript.EventIntent.ACKNOWLEDGE_RESULT
		).code,
		EventResolution.Code.NO_ACTIVE_SESSION
	)


func test_crossroads_fight_and_escape_are_each_one_shot_and_cross_intents_reject() -> void:
	for intent: int in [
		ResolverScript.EventIntent.CROSSROADS_FIGHT,
		ResolverScript.EventIntent.CROSSROADS_ESCAPE,
	]:
		var wallet := TestWallet.new(100)
		var resolver := _resolver(wallet, ControlledRandom.new())
		var presentation := resolver.present_event(_token, ResolverScript.EVENT_CROSSROADS)
		var option: StringName = ResolverScript.CROSSROADS_FIGHT \
			if intent == ResolverScript.EventIntent.CROSSROADS_FIGHT \
			else ResolverScript.CROSSROADS_ESCAPE
		var wrong_intent: int = ResolverScript.EventIntent.CROSSROADS_ESCAPE \
			if intent == ResolverScript.EventIntent.CROSSROADS_FIGHT \
			else ResolverScript.EventIntent.CROSSROADS_FIGHT
		assert_eq(
			resolver.resolve(presentation.token, presentation.event_id, option, wrong_intent).code,
			EventResolution.Code.INTENT_MISMATCH
		)
		var result: EventResolution = resolver.resolve(
			presentation.token, presentation.event_id, option, intent
		)
		assert_eq(
			result.action,
			EventResolution.Action.START_EVENT_BATTLE \
			if intent == ResolverScript.EventIntent.CROSSROADS_FIGHT \
			else EventResolution.Action.ADVANCE_NODE
		)
		assert_eq(wallet.amount, 100)
		assert_eq(
			resolver.resolve(presentation.token, presentation.event_id, option, intent).code,
			EventResolution.Code.NO_ACTIVE_SESSION
		)


func test_stale_repeat_unknown_and_cross_phase_inputs_never_change_balance() -> void:
	var wallet := TestWallet.new(100)
	var resolver := _resolver(wallet, ControlledRandom.new([6]))
	var presentation := resolver.present_event(_token, ResolverScript.EVENT_DICE)
	var stale_token: RunFlowToken = TokenScript.new(
		_token.run_id, _token.node_id, _token.phase_id + 8
	)
	assert_eq(
		resolver.resolve(stale_token, presentation.event_id, ResolverScript.DICE_WAGER_20, ResolverScript.EventIntent.DICE_WAGER_SMALL).code,
		EventResolution.Code.STALE_TOKEN
	)
	assert_eq(
		resolver.resolve(presentation.token, &"crossroads", ResolverScript.DICE_WAGER_20, ResolverScript.EventIntent.DICE_WAGER_SMALL).code,
		EventResolution.Code.UNKNOWN_EVENT
	)
	assert_eq(
		resolver.resolve(presentation.token, presentation.event_id, ResolverScript.RESULT_CONTINUE, ResolverScript.EventIntent.ACKNOWLEDGE_RESULT).code,
		EventResolution.Code.UNKNOWN_OPTION
	)
	wallet.amount = 101
	assert_eq(
		resolver.resolve(presentation.token, presentation.event_id, ResolverScript.DICE_WAGER_20, ResolverScript.EventIntent.DICE_WAGER_SMALL).code,
		EventResolution.Code.STALE_PRESENTATION
	)
	assert_eq(wallet.amount, 101)
	assert_false(presentation.consumed)


func test_commit_and_rollback_failures_are_typed_and_do_not_consume() -> void:
	for rollback_fails: bool in [false, true]:
		var wallet := TestWallet.new(100)
		wallet.debit_failure = TestWallet.AFTER_MUTATION
		wallet.restore_fails = rollback_fails
		var resolver := _resolver(wallet, ControlledRandom.new([1]))
		var presentation := resolver.present_event(_token, ResolverScript.EVENT_DICE)
		var result: EventResolution = resolver.resolve(
			presentation.token, presentation.event_id,
			ResolverScript.DICE_WAGER_20, ResolverScript.EventIntent.DICE_WAGER_SMALL
		)
		assert_eq(
			result.code,
			EventResolution.Code.ROLLBACK_FAILED if rollback_fails else EventResolution.Code.COMMIT_FAILED
		)
		assert_eq(result.rollback_completed, not rollback_fails)
		assert_eq(wallet.amount, 80 if rollback_fails else 100)
		assert_false(presentation.consumed)


func test_wallet_changed_synchronous_reentry_cannot_double_settle() -> void:
	var wallet := TestWallet.new(100)
	var resolver := _resolver(wallet, ControlledRandom.new([6]))
	var presentation := resolver.present_event(_token, ResolverScript.EVENT_DICE)
	var reentrant: Array[EventResolution] = []
	# RefCounted signals retain their Callable. Keep and disconnect this closure:
	# it captures resolver, while resolver retains wallet, so leaving it connected
	# would create a reference-counting cycle that survives the test.
	var reentry_callable := func(_value: int) -> void:
		reentrant.append(resolver.resolve(
			presentation.token, presentation.event_id,
			ResolverScript.DICE_WAGER_20, ResolverScript.EventIntent.DICE_WAGER_SMALL
		))
	wallet.changed.connect(reentry_callable)

	var result: EventResolution = resolver.resolve(
		presentation.token, presentation.event_id,
		ResolverScript.DICE_WAGER_20, ResolverScript.EventIntent.DICE_WAGER_SMALL
	)

	assert_true(result.was_resolved())
	assert_eq(wallet.amount, 110)
	assert_eq(reentrant.size(), 2)
	for blocked: EventResolution in reentrant:
		assert_eq(blocked.code, EventResolution.Code.REENTRANT)

	wallet.changed.disconnect(reentry_callable)
	assert_false(wallet.changed.is_connected(reentry_callable))


func _resolver(wallet: TestWallet, random: ControlledRandom) -> EventResolver:
	var resolver: EventResolver = ResolverScript.new()
	assert_true(resolver.configure(wallet, random))
	return resolver
