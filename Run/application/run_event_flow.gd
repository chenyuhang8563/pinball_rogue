extends RefCounted
class_name RunEventFlow

## Owns EventResolver presentation identity and event-battle plan construction.
var _resolver: EventResolver = null
var _factory: BattlePlanFactory = null
var _floor_config: RunFloorConfig = null
var _random: RunRandomSource = null
var _active: EventPresentation = null
var _error_detail: String = ""


func configure(
	resolver: EventResolver,
	factory: BattlePlanFactory,
	floor_config: RunFloorConfig,
	random: RunRandomSource
) -> bool:
	_resolver = resolver
	_factory = factory
	_floor_config = floor_config
	_random = random
	_active = null
	return _resolver != null and _factory != null and _floor_config != null and _random != null


func active_presentation() -> EventPresentation:
	return _active


func error_detail() -> String:
	return _error_detail


func present(token: RunFlowToken) -> EventPresentation:
	_error_detail = ""
	_active = _resolver.present(token) if _resolver != null else null
	if _active == null or not _active.is_valid() or _active.token == null \
			or token == null or not _active.token.matches(token):
		_error_detail = "event resolver returned a mismatched presentation"
		_active = null
	return _active


func resolve(
	token: RunFlowToken,
	event_id: StringName,
	option_id: StringName,
	intent: EventResolver.EventIntent
) -> EventResolution:
	_error_detail = ""
	if _active == null or _active.consumed or _active.token == null \
			or token == null or not _active.token.matches(token) \
			or event_id != _active.event_id or not _active.has_option(option_id):
		_error_detail = "event presentation identity is stale or unknown"
		return null
	var resolution: EventResolution = _resolver.resolve(token, event_id, option_id, intent)
	if resolution == null or not resolution.was_resolved():
		_error_detail = "event rejected" if resolution == null else \
			"event rejected (%d): %s" % [int(resolution.code), resolution.detail]
		return resolution
	if resolution.action == EventResolution.Action.SHOW_RESULT:
		_active = resolution.presentation
	else:
		_active = null
	return resolution


func create_crossroads_plan(floor_number: int) -> BattlePlan:
	_error_detail = ""
	var result: BattlePlanResult = _factory.create(
		floor_number, BattlePlanOrigin.crossroads(), _floor_config, _random
	)
	if result == null or not result.is_ok() \
			or result.plan.reward_policy != BattlePlan.RewardPolicy.ELITE:
		_error_detail = "crossroads battle plan must use ELITE reward policy"
		return null
	return result.plan


func clear() -> bool:
	_active = null
	return _resolver != null and _resolver.clear_active()
