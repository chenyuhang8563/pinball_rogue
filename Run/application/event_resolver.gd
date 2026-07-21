extends RefCounted
class_name EventResolver

const EventPresentationScript: GDScript = preload("res://Run/domain/event_presentation.gd")
const EventResolutionScript: GDScript = preload("res://Run/domain/event_resolution.gd")
const RewardTransactionScript: GDScript = preload("res://Run/domain/reward_transaction.gd")

const EVENT_DICE: StringName = &"dice_gamble"
const EVENT_CROSSROADS: StringName = &"crossroads"

const DICE_WAGER_20: StringName = &"dice_wager_20"
const DICE_WAGER_60: StringName = &"dice_wager_60"
const DICE_LEAVE: StringName = &"dice_leave"
const CROSSROADS_FIGHT: StringName = &"crossroads_fight"
const CROSSROADS_ESCAPE: StringName = &"crossroads_escape"
const RESULT_CONTINUE: StringName = &"result_continue"

enum EventIntent {
	DICE_WAGER_SMALL,
	DICE_WAGER_LARGE,
	DICE_LEAVE,
	CROSSROADS_FIGHT,
	CROSSROADS_ESCAPE,
	ACKNOWLEDGE_RESULT,
}

var _wallet: Variant = null
var _random_source: RunRandomSource = null
var _configured: bool = false
var _active: EventPresentation = null
var _wallet_revision: int = 0
var _settling: bool = false


func configure(wallet: Variant, random_source: RunRandomSource) -> bool:
	if _settling:
		return false
	_active = null
	_wallet = wallet
	_random_source = random_source
	_configured = _has_wallet_api(wallet) and random_source != null
	return _configured


func active_presentation() -> EventPresentation:
	return _active


func present(token: RunFlowToken) -> EventPresentation:
	if not _can_present(token):
		return null
	var selection := _random_source.range_int(0, 1)
	if selection == 0:
		return present_event(token, EVENT_DICE)
	if selection == 1:
		return present_event(token, EVENT_CROSSROADS)
	return null


func create_presentation(token: RunFlowToken) -> EventPresentation:
	return present(token)


func present_event(token: RunFlowToken, event_id: StringName) -> EventPresentation:
	if not _can_present(token):
		return null
	var options: Array[StringName] = []
	match event_id:
		EVENT_DICE:
			options = [DICE_WAGER_20, DICE_WAGER_60, DICE_LEAVE]
		EVENT_CROSSROADS:
			options = [CROSSROADS_FIGHT, CROSSROADS_ESCAPE]
		_:
			return null
	_active = EventPresentationScript.new(token, event_id, EventPresentation.Phase.CHOICE, options)
	_wallet_revision = int(_wallet.call("revision"))
	return _active


func resolve(
	token: RunFlowToken,
	event_id: StringName,
	option_id: StringName,
	intent: EventIntent
) -> EventResolution:
	var validation := _validate(token, event_id, option_id, intent)
	if validation != null:
		return validation
	match intent:
		EventIntent.DICE_WAGER_SMALL:
			return _resolve_wager(option_id, 20, 30)
		EventIntent.DICE_WAGER_LARGE:
			return _resolve_wager(option_id, 60, 120)
		EventIntent.DICE_LEAVE, EventIntent.CROSSROADS_ESCAPE:
			return _complete(option_id, EventResolution.Action.ADVANCE_NODE)
		EventIntent.CROSSROADS_FIGHT:
			return _complete(option_id, EventResolution.Action.START_EVENT_BATTLE)
		EventIntent.ACKNOWLEDGE_RESULT:
			return _complete(option_id, EventResolution.Action.ADVANCE_NODE)
	return _failure(EventResolution.Code.INTENT_MISMATCH, token, event_id, option_id)


func submit(
	token: RunFlowToken,
	event_id: StringName,
	option_id: StringName,
	intent: EventIntent
) -> EventResolution:
	return resolve(token, event_id, option_id, intent)


func clear_active() -> bool:
	if _settling:
		return false
	_active = null
	_wallet_revision = 0
	return true


func clear_active_session() -> bool:
	return clear_active()


func _resolve_wager(option_id: StringName, cost: int, reward: int) -> EventResolution:
	if not bool(_wallet.call("can_debit", cost)):
		return _failure(
			EventResolution.Code.INSUFFICIENT_FUNDS,
			_active.token, _active.event_id, option_id
		)
	# Random sources are collaborators, not trusted input. Validate the complete
	# roll before opening the mutation transaction.
	var roll := _random_source.range_int(1, 6)
	if roll < 1 or roll > 6:
		return _failure(EventResolution.Code.INVALID_ROLL, _active.token, _active.event_id, option_id)
	var balance_before := int(_wallet.call("balance"))
	var steps: Array[Callable] = [Callable(_wallet, "debit").bind(cost)]
	if roll > 3:
		steps.append(Callable(_wallet, "credit").bind(reward))
	_settling = true
	var transaction: RefCounted = RewardTransactionScript.new([_wallet])
	var committed := bool(transaction.call("execute", steps))
	if not committed:
		_settling = false
		var rolled_back := bool(transaction.get("rollback_completed"))
		return _failure(
			EventResolution.Code.COMMIT_FAILED if rolled_back else EventResolution.Code.ROLLBACK_FAILED,
			_active.token, _active.event_id, option_id,
			rolled_back,
			"wallet transaction failed at step %d" % int(transaction.get("failed_step"))
		)
	var choice := _active
	choice.call("_consume")
	var result_token := RunFlowToken.new(
		choice.token.run_id, choice.token.node_id, choice.token.phase_id + 1
	)
	_active = EventPresentationScript.new(
		result_token,
		choice.event_id,
		EventPresentation.Phase.RESULT,
		[RESULT_CONTINUE] as Array[StringName]
	)
	_wallet_revision = int(_wallet.call("revision"))
	var gold_delta := int(_wallet.call("balance")) - balance_before
	_settling = false
	return EventResolutionScript.new(
		EventResolution.Code.RESOLVED,
		EventResolution.Action.SHOW_RESULT,
		choice.token,
		choice.event_id,
		option_id,
		roll,
		gold_delta,
		_active
	)


func _complete(option_id: StringName, action: EventResolution.Action) -> EventResolution:
	var completed := _active
	completed.call("_consume")
	_active = null
	_wallet_revision = 0
	return EventResolutionScript.new(
		EventResolution.Code.RESOLVED,
		action,
		completed.token,
		completed.event_id,
		option_id
	)


func _validate(
	token: RunFlowToken,
	event_id: StringName,
	option_id: StringName,
	intent: EventIntent
) -> EventResolution:
	if not _configured:
		return _failure(EventResolution.Code.NOT_CONFIGURED, token, event_id, option_id)
	if _settling:
		return _failure(EventResolution.Code.REENTRANT, token, event_id, option_id)
	if _active == null:
		return _failure(EventResolution.Code.NO_ACTIVE_SESSION, token, event_id, option_id)
	if token == null or _active.token == null or not _active.token.matches(token):
		return _failure(EventResolution.Code.STALE_TOKEN, token, event_id, option_id)
	if event_id != _active.event_id:
		return _failure(EventResolution.Code.UNKNOWN_EVENT, token, event_id, option_id)
	if _active.consumed:
		return _failure(EventResolution.Code.STALE_PRESENTATION, token, event_id, option_id)
	if not _active.has_option(option_id):
		return _failure(EventResolution.Code.UNKNOWN_OPTION, token, event_id, option_id)
	if not _intent_matches(option_id, intent):
		return _failure(EventResolution.Code.INTENT_MISMATCH, token, event_id, option_id)
	if int(_wallet.call("revision")) != _wallet_revision:
		return _failure(EventResolution.Code.STALE_PRESENTATION, token, event_id, option_id)
	return null


func _intent_matches(option_id: StringName, intent: EventIntent) -> bool:
	match intent:
		EventIntent.DICE_WAGER_SMALL:
			return option_id == DICE_WAGER_20 and _active.phase == EventPresentation.Phase.CHOICE
		EventIntent.DICE_WAGER_LARGE:
			return option_id == DICE_WAGER_60 and _active.phase == EventPresentation.Phase.CHOICE
		EventIntent.DICE_LEAVE:
			return option_id == DICE_LEAVE and _active.phase == EventPresentation.Phase.CHOICE
		EventIntent.CROSSROADS_FIGHT:
			return option_id == CROSSROADS_FIGHT and _active.phase == EventPresentation.Phase.CHOICE
		EventIntent.CROSSROADS_ESCAPE:
			return option_id == CROSSROADS_ESCAPE and _active.phase == EventPresentation.Phase.CHOICE
		EventIntent.ACKNOWLEDGE_RESULT:
			return option_id == RESULT_CONTINUE and _active.phase == EventPresentation.Phase.RESULT
	return false


func _failure(
	code: EventResolution.Code,
	token: RunFlowToken,
	event_id: StringName,
	option_id: StringName,
	rollback_completed: bool = true,
	detail: String = ""
) -> EventResolution:
	return EventResolutionScript.new(
		code, -1, token, event_id, option_id, 0, 0, null,
		rollback_completed, detail
	)


func _has_wallet_api(value: Variant) -> bool:
	if value == null:
		return false
	for method: StringName in [
		&"balance", &"can_debit", &"debit", &"credit", &"revision", &"snapshot", &"restore",
	]:
		if not value.has_method(method):
			return false
	return true


func _can_present(token: RunFlowToken) -> bool:
	return _configured and not _settling and _active == null \
		and token != null and token.is_valid()
