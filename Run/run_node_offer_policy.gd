extends RefCounted
class_name RunNodeOfferPolicy

const RunNodeChoiceScript: GDScript = preload("res://Run/domain/run_node_choice.gd")
const RunNodeOfferScript: GDScript = preload("res://Run/domain/run_node_offer.gd")

const WEIGHTED_KINDS: PackedInt32Array = [
	RunNodeOption.Kind.BATTLE,
	RunNodeOption.Kind.EVENT,
	RunNodeOption.Kind.ELITE,
	RunNodeOption.Kind.UPGRADE,
]
const WEIGHTS: PackedInt32Array = [30, 30, 20, 20]

var choice_wave_index: int:
	get:
		return _choice_wave_index

var _factory: BattlePlanFactory = null
var _floor_config: RunFloorConfig = null
var _random: RunRandomSource = null
var _choice_wave_index: int = 0
var _error_detail: String = ""


func configure(
	factory: BattlePlanFactory,
	floor_config: RunFloorConfig,
	random: RunRandomSource
) -> bool:
	_factory = factory
	_floor_config = floor_config
	_random = random
	_choice_wave_index = 0
	return _factory != null and _floor_config != null and _random != null


func reset() -> void:
	_choice_wave_index = 0
	_error_detail = ""


func error_detail() -> String:
	return _error_detail


## Pure offer policy: guaranteed rules first, then weighted sampling without
## replacement. Every battle choice receives its prebuilt typed plan.
func build(state: RunState) -> RunNodeOffer:
	_error_detail = ""
	if state == null or state.phase != RunState.Phase.CHOOSING_NODE \
			or state.floor_number < 2:
		return _fail("node policy requires CHOOSING_NODE")
	_choice_wave_index += 1
	var kinds: Array[int] = _guaranteed_kinds(state.floor_number)
	while kinds.size() < 3:
		var weights := PackedInt32Array()
		for index: int in range(WEIGHTED_KINDS.size()):
			weights.append(0 if kinds.has(WEIGHTED_KINDS[index]) else WEIGHTS[index])
		var selected_index := _random.weighted_index(weights)
		if selected_index < 0 or selected_index >= WEIGHTED_KINDS.size():
			return _fail("weighted node selection has no eligible kind")
		kinds.append(WEIGHTED_KINDS[selected_index])
	var choices: Array[RunNodeChoice] = []
	for raw_kind: int in kinds:
		var choice := _build_choice(state, raw_kind as RunNodeOption.Kind)
		if choice == null:
			return _fail("node choice or battle plan could not be built")
		choices.append(choice)
	var token := state.token()
	var offer: RunNodeOffer = RunNodeOfferScript.new(
		token,
		StringName("node-offer:%d:%d:%d" % [token.run_id, token.node_id, _choice_wave_index]),
		state.floor_number,
		_choice_wave_index,
		choices
	)
	if not offer.is_valid():
		return _fail("node offer violates unique three-choice contract")
	return offer


func _guaranteed_kinds(floor_number: int) -> Array[int]:
	var kinds: Array[int] = []
	for rule: RunFloorNodeRule in _floor_config.guaranteed_node_rules:
		if kinds.size() >= 3:
			break
		if rule == null or rule.floor_number != floor_number:
			continue
		var kind := int(rule.node_kind)
		if not kinds.has(kind):
			kinds.append(kind)
	return kinds


func _build_choice(state: RunState, kind: RunNodeOption.Kind) -> RunNodeChoice:
	var kind_id := _kind_id(kind)
	if kind_id.is_empty():
		return null
	var plan: BattlePlan = null
	if kind == RunNodeOption.Kind.BATTLE or kind == RunNodeOption.Kind.ELITE:
		var origin := BattlePlanOrigin.elite_node() \
			if kind == RunNodeOption.Kind.ELITE else BattlePlanOrigin.normal_node()
		var result: BattlePlanResult = _factory.create(
			state.floor_number, origin, _floor_config, _random
		)
		if result == null or not result.is_ok():
			return null
		plan = result.plan
	return RunNodeChoiceScript.new(
		StringName("node-option:%d:%d:%s" % [state.node_id, _choice_wave_index, kind_id]),
		kind,
		kind_id,
		_kind_title(kind),
		"",
		plan
	)


func _kind_id(kind: RunNodeOption.Kind) -> StringName:
	match kind:
		RunNodeOption.Kind.BATTLE:
			return &"battle"
		RunNodeOption.Kind.EVENT:
			return &"event"
		RunNodeOption.Kind.REWARD:
			return &"reward"
		RunNodeOption.Kind.ELITE:
			return &"elite"
		RunNodeOption.Kind.UPGRADE:
			return &"upgrade"
		RunNodeOption.Kind.SHOP:
			return &"shop"
		RunNodeOption.Kind.DEVIL_SHOP:
			return &"devil_shop"
	return &""


func _kind_title(kind: RunNodeOption.Kind) -> String:
	match kind:
		RunNodeOption.Kind.BATTLE:
			return "RUN_BATTLE_TITLE"
		RunNodeOption.Kind.EVENT:
			return "RUN_EVENT_TITLE"
		RunNodeOption.Kind.REWARD:
			return "RUN_REWARD_TITLE"
		RunNodeOption.Kind.ELITE:
			return "RUN_ELITE_FIGHT_TITLE"
		RunNodeOption.Kind.UPGRADE:
			return "RUN_UPGRADE_TITLE"
		RunNodeOption.Kind.SHOP:
			return "RUN_SHOP_TITLE"
		RunNodeOption.Kind.DEVIL_SHOP:
			return "RUN_DEVIL_SHOP_TITLE"
	return ""


func _fail(detail: String) -> RunNodeOffer:
	_error_detail = detail
	return null
