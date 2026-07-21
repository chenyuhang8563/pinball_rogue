extends Node
class_name RunFlowController

## Phase 3 application orchestrator. Selection, draft, event, upgrade, and
## gateway-session policies live in dedicated RefCounted collaborators below.
signal command_rejected(command: StringName, reason: String)
signal node_options_presented(offer: RunNodeOffer)
signal node_selected(token: RunFlowToken, choice: RunNodeChoice)
signal battle_plan_committed(token: RunFlowToken, plan: BattlePlan)
signal battle_started(token: RunFlowToken, plan: BattlePlan)
signal battle_completed(token: RunFlowToken, battle_id: StringName, plan: BattlePlan)
signal battle_start_failed(token: RunFlowToken, plan: BattlePlan)
signal reward_presented(offer: RewardOffer)
signal reward_resolved(result: RewardResult)
signal reward_replacement_requested(result: RewardResult)
signal event_presented(presentation: EventPresentation)
signal event_resolved(resolution: EventResolution)
signal event_result_presented(presentation: EventPresentation)
signal upgrade_presented(offer: UpgradeOffer)
signal upgrade_resolved(result: UpgradeResult)
signal shop_opened(token: RunFlowToken, shop_kind: StringName)
signal shop_closed(token: RunFlowToken, shop_kind: StringName)
signal floor_changed(floor_number: int)
signal health_changed(value: int)
signal run_failed(token: RunFlowToken, reason: StringName)
signal run_completed(token: RunFlowToken)
signal terminal_acknowledged(token: RunFlowToken, phase: RunState.Phase)

const RunStateScript: GDScript = preload("res://Run/domain/run_state.gd")
const NodePolicyScript: GDScript = preload("res://Run/run_node_offer_policy.gd")
const RewardFlowScript: GDScript = preload("res://Run/run_reward_flow.gd")
const EventFlowScript: GDScript = preload("res://Run/run_event_flow.gd")
const UpgradeServiceScript: GDScript = preload("res://Run/run_upgrade_service.gd")
const BattleFlowScript: GDScript = preload("res://Run/run_battle_flow.gd")

const START: StringName = &"start"
const RESTART: StringName = &"restart"
const SELECT_NODE: StringName = &"select_node"
const SKIP_CURRENT_BATTLE: StringName = &"skip_current_battle"
const BATTLE_COMPLETE: StringName = &"battle_complete"
const MARBLE_FALL: StringName = &"marble_fall"
const SELECT_REWARD: StringName = &"select_reward"
const CONFIRM_REPLACEMENT: StringName = &"confirm_reward_replacement"
const CANCEL_REPLACEMENT: StringName = &"cancel_reward_replacement"
const EVENT_INTENT: StringName = &"event_intent"
const EVENT_ACKNOWLEDGE: StringName = &"event_result_acknowledge"
const SELECT_UPGRADE: StringName = &"select_upgrade"
const UPGRADE_UNAVAILABLE: StringName = &"upgrade_unavailable_acknowledge"
const CLOSE_SHOP: StringName = &"close_shop"
const TERMINAL_ACKNOWLEDGE: StringName = &"terminal_acknowledge"

var choice_wave_index: int:
	get:
		return _node_policy.choice_wave_index

var _state: RunState = RunStateScript.new()
var _node_policy: RunNodeOfferPolicy = NodePolicyScript.new()
var _reward_flow: RunRewardFlow = RewardFlowScript.new()
var _event_flow: RunEventFlow = EventFlowScript.new()
var _upgrade_service: RunUpgradeService = UpgradeServiceScript.new()
var _battle_flow: RunBattleFlow = BattleFlowScript.new()

var _run_scope: RunScope = null
var _factory: BattlePlanFactory = null
var _floor_config: RunFloorConfig = null
var _random: RunRandomSource = null
var _health: RefCounted = null
var _active_node_offer: RunNodeOffer = null
var _active_shop_kind: StringName = &""
var _configured: bool = false
var _command_guard: bool = false
var _terminal_acknowledged: bool = false


func _init() -> void:
	_battle_flow.completed.connect(_on_battle_completed)
	_battle_flow.marble_fell.connect(_on_marble_fell)
	_battle_flow.callback_rejected.connect(_on_battle_callback_rejected)


func configure(
	run_scope: RunScope,
	battle_plan_factory: BattlePlanFactory,
	reward_service: RewardService,
	event_resolver: EventResolver,
	floor_config: RunFloorConfig,
	random_source: RunRandomSource,
	battle_gateway: BattleGateway
) -> bool:
	if _command_guard or run_scope == null or not is_instance_valid(run_scope) \
			or not run_scope.is_initialized() or battle_plan_factory == null \
			or reward_service == null or event_resolver == null or floor_config == null \
			or floor_config.boss_floor < 2 or random_source == null \
			or battle_gateway == null or not is_instance_valid(battle_gateway):
		return false
	if run_scope.loadout == null or run_scope.progression == null \
			or run_scope.wallet == null or run_scope.health == null:
		return false
	_disconnect_health()
	_run_scope = run_scope
	_factory = battle_plan_factory
	_floor_config = floor_config
	_random = random_source
	_health = run_scope.health
	_configured = _node_policy.configure(_factory, _floor_config, _random) \
		and _reward_flow.configure(reward_service) \
		and _event_flow.configure(event_resolver, _factory, _floor_config, _random) \
		and _upgrade_service.configure(run_scope.loadout, run_scope.progression) \
		and _battle_flow.configure(battle_gateway)
	if not _configured or not _health.has_signal(&"changed"):
		_configured = false
		return false
	var health_callable := Callable(self, "_on_health_changed")
	if not _health.is_connected(&"changed", health_callable):
		_health.connect(&"changed", health_callable)
	return true


func _exit_tree() -> void:
	_disconnect_health()
	_battle_flow.dispose()


func current_state() -> RunState:
	return _state


func current_node_offer() -> RunNodeOffer:
	return _active_node_offer


func current_reward_offer() -> RewardOffer:
	return _reward_flow.active_offer()


func current_event() -> EventPresentation:
	return _event_flow.active_presentation()


func current_upgrade_offer() -> UpgradeOffer:
	return _upgrade_service.active_offer()


func start_run() -> bool:
	if not _begin_command(START):
		return false
	if _state.run_id != 0 or _state.phase != RunState.Phase.IDLE:
		return _finish_rejected(START, "start requires pristine IDLE state")
	var result := _start_new_run(START)
	return _finish_command(result)


func restart_run(token: RunFlowToken) -> bool:
	if not _begin_command(RESTART):
		return false
	if not _state.is_terminal():
		return _finish_rejected(RESTART, "restart requires terminal state")
	if token == null or not _state.matches(token):
		return _finish_rejected(RESTART, "restart token is stale")
	var result := _start_new_run(RESTART)
	return _finish_command(result)


func select_node(token: RunFlowToken, offer_id: StringName, option_id: StringName) -> bool:
	if not _begin_command(SELECT_NODE):
		return false
	if not _validate_source(SELECT_NODE, token, RunState.Phase.CHOOSING_NODE):
		return _finish_command(false)
	if _active_node_offer == null or _active_node_offer.consumed \
			or offer_id != _active_node_offer.offer_id \
			or not _active_node_offer.token.matches(token):
		return _finish_rejected(SELECT_NODE, "node offer identity is not active")
	var choice: RunNodeChoice = _active_node_offer.choice_by_id(option_id)
	if choice == null or not choice.is_valid():
		return _finish_rejected(SELECT_NODE, "node option does not belong to offer")
	var result := _commit_node_choice(choice)
	return _finish_command(result)


func choose_node(token: RunFlowToken, offer_id: StringName, option_id: StringName) -> bool:
	return select_node(token, offer_id, option_id)


func skip_current_battle() -> bool:
	if not _begin_command(SKIP_CURRENT_BATTLE):
		return false
	if _state.phase != RunState.Phase.BATTLE_ACTIVE:
		return _finish_rejected(SKIP_CURRENT_BATTLE, "skip requires an active battle")
	var result := _battle_flow.force_complete_current_battle()
	return _finish_command(result)


func select_reward(token: RunFlowToken, draft_id: StringName, offer_id: StringName) -> bool:
	if not _begin_command(SELECT_REWARD):
		return false
	if not _validate_source(SELECT_REWARD, token, RunState.Phase.REWARD_ACTIVE):
		return _finish_command(false)
	var result: RewardResult = _reward_flow.select(token, draft_id, offer_id)
	var handled := _handle_reward_result(SELECT_REWARD, result)
	return _finish_command(handled)


func confirm_reward_replacement(token: RunFlowToken, replacement_token: StringName) -> bool:
	if not _begin_command(CONFIRM_REPLACEMENT):
		return false
	if not _validate_source(CONFIRM_REPLACEMENT, token, RunState.Phase.REWARD_ACTIVE):
		return _finish_command(false)
	var result: RewardResult = _reward_flow.confirm_replacement(token, replacement_token)
	var handled := _handle_reward_result(CONFIRM_REPLACEMENT, result)
	return _finish_command(handled)


func cancel_reward_replacement(token: RunFlowToken, replacement_token: StringName) -> bool:
	if not _begin_command(CANCEL_REPLACEMENT):
		return false
	if not _validate_source(CANCEL_REPLACEMENT, token, RunState.Phase.REWARD_ACTIVE):
		return _finish_command(false)
	var result: RewardResult = _reward_flow.cancel_replacement(token, replacement_token)
	if result == null or result.code != RewardResult.Code.DECLINED:
		return _finish_rejected(CANCEL_REPLACEMENT, _reward_error(result))
	reward_resolved.emit(result)
	return _finish_command(true)


func submit_event_intent(
	token: RunFlowToken,
	event_id: StringName,
	option_id: StringName,
	intent: EventResolver.EventIntent
) -> bool:
	if not _begin_command(EVENT_INTENT):
		return false
	var result := _resolve_event(EVENT_INTENT, token, event_id, option_id, intent)
	return _finish_command(result)


func acknowledge_event_result(
	token: RunFlowToken,
	event_id: StringName,
	option_id: StringName = EventResolver.RESULT_CONTINUE
) -> bool:
	if not _begin_command(EVENT_ACKNOWLEDGE):
		return false
	var result := _resolve_event(
		EVENT_ACKNOWLEDGE, token, event_id, option_id,
		EventResolver.EventIntent.ACKNOWLEDGE_RESULT
	)
	return _finish_command(result)


func select_upgrade(token: RunFlowToken, offer_id: StringName, candidate_id: StringName) -> bool:
	if not _begin_command(SELECT_UPGRADE):
		return false
	if not _validate_source(SELECT_UPGRADE, token, RunState.Phase.UPGRADE_ACTIVE):
		return _finish_command(false)
	var result: UpgradeResult = _upgrade_service.select(token, offer_id, candidate_id)
	if result == null or not result.succeeded():
		return _finish_rejected(SELECT_UPGRADE, _upgrade_error(result))
	upgrade_resolved.emit(result)
	return _finish_command(_advance_flow())


func acknowledge_upgrade_unavailable(token: RunFlowToken, offer_id: StringName) -> bool:
	if not _begin_command(UPGRADE_UNAVAILABLE):
		return false
	if not _validate_source(UPGRADE_UNAVAILABLE, token, RunState.Phase.UPGRADE_ACTIVE):
		return _finish_command(false)
	var result: UpgradeResult = _upgrade_service.acknowledge_unavailable(token, offer_id)
	if result == null or not result.succeeded():
		return _finish_rejected(UPGRADE_UNAVAILABLE, _upgrade_error(result))
	upgrade_resolved.emit(result)
	return _finish_command(_advance_flow())


func close_shop(token: RunFlowToken, shop_kind: StringName) -> bool:
	if not _begin_command(CLOSE_SHOP):
		return false
	if shop_kind != &"shop" and shop_kind != &"devil_shop":
		return _finish_rejected(CLOSE_SHOP, "unknown shop kind")
	var phase := RunState.Phase.NORMAL_SHOP_ACTIVE \
		if shop_kind == &"shop" else RunState.Phase.DEVIL_SHOP_ACTIVE
	if not _validate_source(CLOSE_SHOP, token, phase):
		return _finish_command(false)
	if _active_shop_kind.is_empty() or _active_shop_kind != shop_kind:
		return _finish_rejected(CLOSE_SHOP, "shop was already closed or kind changed")
	_active_shop_kind = &""
	shop_closed.emit(token, shop_kind)
	return _finish_command(_advance_flow())


func acknowledge_terminal(token: RunFlowToken) -> bool:
	if not _begin_command(TERMINAL_ACKNOWLEDGE):
		return false
	if not _state.is_terminal() or token == null or not _state.matches(token):
		return _finish_rejected(TERMINAL_ACKNOWLEDGE, "terminal token or phase is invalid")
	if _terminal_acknowledged:
		return _finish_rejected(TERMINAL_ACKNOWLEDGE, "terminal token was already acknowledged")
	_terminal_acknowledged = true
	terminal_acknowledged.emit(token, _state.phase)
	return _finish_command(true)


func _start_new_run(command: StringName) -> bool:
	# Identity changes before any clear/reset signal can reenter the controller.
	if not _state.begin_run():
		return _reject(command, "RunState rejected begin_run")
	_terminal_acknowledged = false
	_active_node_offer = null
	_active_shop_kind = &""
	_node_policy.reset()
	if not _reward_flow.clear() or not _event_flow.clear() or not _upgrade_service.clear():
		return _fail_run(&"session_clear_failed")
	_battle_flow.clear()
	if not _run_scope.reset_for_run():
		return _fail_run(&"scope_reset_failed")
	health_changed.emit(int(_health.call("current")))
	var built: BattlePlanResult = _factory.create(
		1, BattlePlanOrigin.run_start(), _floor_config, _random
	)
	if built == null or not built.is_ok() or not _state.begin_first_battle(built.plan):
		return _fail_run(&"first_battle_failed")
	floor_changed.emit(1)
	return _start_battle(built.plan)


func _commit_node_choice(choice: RunNodeChoice) -> bool:
	var committed := false
	match choice.kind:
		RunNodeOption.Kind.BATTLE, RunNodeOption.Kind.ELITE:
			committed = _state.select_node(
				choice.kind_id, RunState.Phase.BATTLE_ACTIVE, choice.battle_plan
			)
		RunNodeOption.Kind.EVENT:
			committed = _state.select_node(choice.kind_id, RunState.Phase.EVENT_ACTIVE)
		RunNodeOption.Kind.REWARD:
			committed = _state.select_node(choice.kind_id, RunState.Phase.REWARD_ACTIVE)
		RunNodeOption.Kind.UPGRADE:
			committed = _state.select_node(choice.kind_id, RunState.Phase.UPGRADE_ACTIVE)
		RunNodeOption.Kind.SHOP:
			committed = _state.select_node(choice.kind_id, RunState.Phase.NORMAL_SHOP_ACTIVE)
		RunNodeOption.Kind.DEVIL_SHOP:
			committed = _state.select_node(choice.kind_id, RunState.Phase.DEVIL_SHOP_ACTIVE)
	if not committed:
		return _reject(SELECT_NODE, "RunState rejected kind + target phase")
	_active_node_offer.call("_consume")
	_active_node_offer = null
	var token := _state.token()
	node_selected.emit(token, choice)
	match choice.kind:
		RunNodeOption.Kind.BATTLE, RunNodeOption.Kind.ELITE:
			return _start_battle(choice.battle_plan)
		RunNodeOption.Kind.EVENT:
			var event: EventPresentation = _event_flow.present(token)
			if event == null:
				return _fail_run(&"event_presentation_failed")
			event_presented.emit(event)
			return true
		RunNodeOption.Kind.REWARD:
			var reward: RewardOffer = _reward_flow.present_node(token, choice.option_id)
			if reward == null:
				return _fail_run(&"node_reward_failed")
			reward_presented.emit(reward)
			return true
		RunNodeOption.Kind.UPGRADE:
			var upgrade: UpgradeOffer = _upgrade_service.present(token, _state.node_id)
			if upgrade == null:
				return _fail_run(StringName(
					"upgrade_offer_failed:%s" % _upgrade_service.error_detail()
				))
			upgrade_presented.emit(upgrade)
			return true
		RunNodeOption.Kind.SHOP, RunNodeOption.Kind.DEVIL_SHOP:
			_active_shop_kind = choice.kind_id
			shop_opened.emit(token, choice.kind_id)
			return true
	return _fail_run(&"unsupported_node_kind")


func _start_battle(plan: BattlePlan) -> bool:
	if plan == null or _state.phase != RunState.Phase.BATTLE_ACTIVE or _state.battle_plan != plan:
		return _fail_run(&"invalid_committed_battle")
	var token := _state.token()
	battle_plan_committed.emit(token, plan)
	battle_started.emit(token, plan)
	if _battle_flow.start(plan, token):
		return true
	battle_start_failed.emit(token, plan)
	return _fail_run(&"battle_start_failed")


func _on_battle_completed(token: RunFlowToken, battle_id: StringName, plan: BattlePlan) -> void:
	var owned_guard := not _command_guard
	_command_guard = true
	if not _configured or _state.is_terminal() or _state.phase != RunState.Phase.BATTLE_ACTIVE \
			or token == null or not _state.accepts(token) or plan == null \
			or battle_id != plan.battle_id or _state.battle_plan != plan:
		_reject(BATTLE_COMPLETE, "battle completion does not match active state")
		_release_internal_guard(owned_guard)
		return
	battle_completed.emit(token, battle_id, plan)
	var routed := false
	match plan.reward_policy:
		BattlePlan.RewardPolicy.NORMAL, BattlePlan.RewardPolicy.ELITE:
			routed = _state.present_reward()
			if routed:
				var reward: RewardOffer = _reward_flow.present_battle(_state.token(), plan)
				routed = reward != null
				if routed:
					reward_presented.emit(reward)
		BattlePlan.RewardPolicy.NONE:
			routed = plan.origin == BattlePlan.Origin.BOSS and _state.complete()
			if routed:
				run_completed.emit(_state.token())
	if not routed and not _state.is_terminal():
		_fail_run(&"battle_completion_route_failed")
	_release_internal_guard(owned_guard)


func _handle_reward_result(command: StringName, result: RewardResult) -> bool:
	if result == null:
		return _reject(command, _reward_flow.error_detail())
	if result.code == RewardResult.Code.SKILL_REPLACEMENT_REQUIRED:
		reward_replacement_requested.emit(result)
		return true
	if not result.was_granted():
		return _reject(command, _reward_error(result))
	reward_resolved.emit(result)
	if not _reward_flow.completed():
		return true
	if not _reward_flow.clear():
		return _fail_run(&"reward_clear_failed")
	return _advance_flow()


func _resolve_event(
	command: StringName,
	token: RunFlowToken,
	event_id: StringName,
	option_id: StringName,
	intent: EventResolver.EventIntent
) -> bool:
	var phase := RunState.Phase.EVENT_RESULT_ACTIVE \
		if intent == EventResolver.EventIntent.ACKNOWLEDGE_RESULT else RunState.Phase.EVENT_ACTIVE
	if not _validate_source(command, token, phase):
		return false
	var resolution: EventResolution = _event_flow.resolve(token, event_id, option_id, intent)
	if resolution == null or not resolution.was_resolved():
		return _reject(command, _event_flow.error_detail())
	match resolution.action:
		EventResolution.Action.SHOW_RESULT:
			var event := _event_flow.active_presentation()
			if not _state.present_event_result() or event == null \
					or not event.token.matches(_state.token()):
				return _fail_run(&"event_result_transition_failed")
			event_resolved.emit(resolution)
			event_result_presented.emit(event)
			event_presented.emit(event)
			return true
		EventResolution.Action.START_EVENT_BATTLE:
			var plan := _event_flow.create_crossroads_plan(_state.floor_number)
			if plan == null or not _state.begin_battle(plan):
				return _fail_run(&"event_battle_transition_failed")
			event_resolved.emit(resolution)
			return _start_battle(plan)
		EventResolution.Action.ADVANCE_NODE:
			event_resolved.emit(resolution)
			return _advance_flow()
	return _reject(command, "event action is unsupported")


func _advance_flow() -> bool:
	var next_floor := _state.floor_number + 1
	if next_floor > _floor_config.boss_floor:
		return _fail_run(&"floor_exceeded_boss")
	if next_floor == _floor_config.boss_floor:
		var built: BattlePlanResult = _factory.create(
			next_floor, BattlePlanOrigin.boss(), _floor_config, _random
		)
		if built == null or not built.is_ok() \
				or built.plan.reward_policy != BattlePlan.RewardPolicy.NONE \
				or not _state.advance_to_battle(&"boss", built.plan):
			return _fail_run(&"boss_bypass_failed")
		floor_changed.emit(next_floor)
		return _start_battle(built.plan)
	if not _state.advance_to_node():
		return _fail_run(&"next_node_transition_failed")
	floor_changed.emit(next_floor)
	_active_node_offer = _node_policy.build(_state)
	if _active_node_offer == null:
		return _fail_run(&"node_offer_failed")
	node_options_presented.emit(_active_node_offer)
	return true


func _on_marble_fell(token: RunFlowToken, marble: RigidBody2D) -> void:
	var owned_guard := not _command_guard
	_command_guard = true
	if not _configured or _state.is_terminal() or _state.phase != RunState.Phase.BATTLE_ACTIVE \
			or token == null or not _state.accepts(token):
		_reject(MARBLE_FALL, "marble fall phase or token is stale")
		_release_internal_guard(owned_guard)
		return
	if marble == null or not is_instance_valid(marble) or not marble.is_in_group("marbles") \
			or int(_health.call("current")) <= 0 or not bool(_health.call("damage", 1)):
		_reject(MARBLE_FALL, "marble or current health is invalid")
		_release_internal_guard(owned_guard)
		return
	if int(_health.call("current")) == 0:
		_fail_run(&"health_depleted")
	_release_internal_guard(owned_guard)


func _on_battle_callback_rejected(command: StringName, reason: String) -> void:
	_reject(command, reason)


func _on_health_changed(value: int) -> void:
	if _configured:
		health_changed.emit(value)


func _validate_source(command: StringName, token: RunFlowToken, phase: RunState.Phase) -> bool:
	if _state.is_terminal():
		return _reject(command, "terminal state rejects command")
	if _state.phase != phase:
		return _reject(command, "command source phase does not match")
	if token == null or not _state.accepts(token):
		return _reject(command, "flow token is stale")
	return true


func _fail_run(reason: StringName) -> bool:
	_active_node_offer = null
	_active_shop_kind = &""
	_battle_flow.clear()
	_reward_flow.clear()
	_event_flow.clear()
	_upgrade_service.clear()
	if not _state.fail():
		return false
	run_failed.emit(_state.token(), reason)
	return false


func _begin_command(command: StringName) -> bool:
	if not _configured:
		return _reject(command, "controller is not configured")
	if _command_guard:
		return _reject(command, "controller command is reentrant")
	_command_guard = true
	return true


func _finish_rejected(command: StringName, reason: String) -> bool:
	_reject(command, reason)
	_command_guard = false
	return false


func _finish_command(result: bool) -> bool:
	_command_guard = false
	return result


func _release_internal_guard(owned_guard: bool) -> void:
	if owned_guard:
		_command_guard = false


func _reject(command: StringName, reason: String) -> bool:
	command_rejected.emit(command, reason)
	return false


func _reward_error(result: RewardResult) -> String:
	if result == null:
		return _reward_flow.error_detail()
	return "reward rejected (%d): %s" % [int(result.code), result.detail]


func _upgrade_error(result: UpgradeResult) -> String:
	if result == null:
		return _upgrade_service.error_detail()
	return "upgrade rejected (%d): %s" % [int(result.code), result.detail]


func _disconnect_health() -> void:
	if _health == null or not _health.has_signal(&"changed"):
		return
	var health_callable := Callable(self, "_on_health_changed")
	if _health.is_connected(&"changed", health_callable):
		_health.disconnect(&"changed", health_callable)
