extends RefCounted
class_name RewardService

signal changed
signal draft_completed(draft_id: StringName)

const RewardOfferScript: GDScript = preload("res://Run/domain/reward_offer.gd")
const RewardOptionScript: GDScript = preload("res://Run/domain/reward_option.gd")
const RewardResultScript: GDScript = preload("res://Run/domain/reward_result.gd")
const RewardTransactionScript: GDScript = preload("res://Run/domain/reward_transaction.gd")

const COMPENSATION_GOLD: int = 15
const ELITE_GOLD_MIN: int = 35
const ELITE_GOLD_MAX: int = 40
const DEFAULT_NODE_ITEM_PATHS: PackedStringArray = [
	"res://Content/data/brown_marble.tres",
	"res://Content/data/green_marble.tres",
	"res://Content/data/bomb_marble.tres",
	"res://Content/data/fire_marble.tres",
	"res://Content/data/lightning.tres",
	"res://Content/data/fire_bellows.tres",
	"res://Content/data/poison_culture.tres",
	"res://Content/data/ice_hammer.tres",
]
const DEFAULT_RELIC_PATHS: PackedStringArray = [
	"res://Content/data/lightning.tres",
	"res://Content/data/fire_bellows.tres",
	"res://Content/data/poison_culture.tres",
	"res://Content/data/ice_hammer.tres",
]
const DEFAULT_NORMAL_MARBLE_PATHS: PackedStringArray = [
	"res://Content/data/brown_marble.tres",
	"res://Content/data/green_marble.tres",
	"res://Content/data/bomb_marble.tres",
	"res://Content/data/fire_marble.tres",
]
const DEFAULT_NORMAL_SKILL_PATHS: PackedStringArray = [
	"res://Content/data/dash_skill.tres",
	"res://Content/data/magic_missile_skill.tres",
]

var _loadout: Variant = null
var _progression: Variant = null
var _wallet: Variant = null
var _config: BattleRewardConfig = null
var _random_source: RunRandomSource = null
var _content_registry: Node = null
var _configured: bool = false
var _active_draft: RewardOffer = null
var _pending_replacement: Dictionary = {}
var _draft_nonce: int = 0
var _offer_nonce: int = 0
var _replacement_nonce: int = 0
var _settling: bool = false
var _validation_detail: String = ""


func configure(
	loadout: Variant,
	progression: Variant,
	wallet: Variant,
	config: BattleRewardConfig,
	random_source: RunRandomSource,
	content_registry: Node = null
) -> bool:
	if _settling:
		return false
	_active_draft = null
	_pending_replacement.clear()
	_loadout = loadout
	_progression = progression
	_wallet = wallet
	_config = config
	_random_source = random_source
	_content_registry = content_registry
	_configured = _has_api(_loadout, [
		&"find_owned", &"can_add", &"add", &"replace_skill", &"current_skill",
		&"revision", &"snapshot", &"restore",
	]) and _has_api(_progression, [
		&"level_of", &"can_upgrade", &"upgrade_one", &"reset_skill",
		&"revision", &"snapshot", &"restore",
	]) and _has_api(_wallet, [
		&"balance", &"credit", &"revision", &"snapshot", &"restore",
	]) and _config != null and _random_source != null
	if not _configured:
		_active_draft = null
		_pending_replacement.clear()
	return _configured


func active_draft() -> RewardOffer:
	return _active_draft


func pending_replacement_token() -> StringName:
	return StringName(_pending_replacement.get(&"token", &""))


func create_node_draft(
	token: RunFlowToken,
	source_id: StringName,
	candidates: Array = []
) -> RewardOffer:
	if not _can_draft(token, source_id):
		return null
	var source_items: Array[Item] = _items_from(candidates)
	if candidates.is_empty():
		source_items = _registry_all_items()
		if source_items.is_empty():
			source_items = _load_items(DEFAULT_NODE_ITEM_PATHS)
	var eligible: Array[Item] = []
	for item: Item in source_items:
		if _contains_identity(eligible, item):
			continue
		var resolution := _eligible_resolution(item, false)
		if resolution >= 0:
			eligible.append(item)
	var options: Array[RewardOption] = []
	while options.size() < 3 and not eligible.is_empty():
		var item := _take_weighted(eligible)
		options.append(_make_item_option(item, _resolution_for_item(item, false)))
	if options.is_empty():
		options.append(_make_gold_option(COMPENSATION_GOLD))
	return _install_draft(
		token, BattlePlan.RewardPolicy.NONE, source_id,
		RewardOfferScript.Mode.NODE_EXCLUSIVE, options
	)


func draft_node_rewards(
	token: RunFlowToken,
	source_id: StringName,
	candidates: Array = []
) -> RewardOffer:
	return create_node_draft(token, source_id, candidates)


func draft_node(token: RunFlowToken, source_id: StringName, candidates: Array = []) -> RewardOffer:
	return create_node_draft(token, source_id, candidates)


func create_normal_draft(
	token: RunFlowToken,
	source_id: StringName,
	marble_candidates: Array = [],
	skill_candidates: Array = []
) -> RewardOffer:
	if not _can_draft(token, source_id):
		return null
	var marbles := _items_from(marble_candidates)
	var skills := _items_from(skill_candidates)
	if marble_candidates.is_empty():
		marbles = _registry_query(Item.ItemType.MARBLE)
		if marbles.is_empty():
			marbles = _load_items(
				_config.marble_item_paths if not _config.marble_item_paths.is_empty() \
				else DEFAULT_NORMAL_MARBLE_PATHS
			)
	if skill_candidates.is_empty():
		skills = _registry_query(Item.ItemType.SKILL)
		if skills.is_empty():
			skills = _load_items(
				_config.skill_item_paths if not _config.skill_item_paths.is_empty() \
				else DEFAULT_NORMAL_SKILL_PATHS
			)
	marbles = _eligible_pool(marbles, Item.ItemType.MARBLE, false)
	skills = _eligible_pool(skills, Item.ItemType.SKILL, false)
	var categories: Array[Dictionary] = [{
		&"kind": &"gold",
		&"weight": _config.gold_weight,
		&"items": [],
	}]
	if not marbles.is_empty():
		categories.append({&"kind": &"marble", &"weight": _config.marble_weight, &"items": marbles})
	if not skills.is_empty():
		categories.append({&"kind": &"skill", &"weight": _config.skill_weight, &"items": skills})
	var options: Array[RewardOption] = []
	while options.size() < 2 and not categories.is_empty():
		var category_index := _weighted_category_index(categories)
		if category_index < 0:
			category_index = 0
		var category: Dictionary = categories.pop_at(category_index)
		if StringName(category[&"kind"]) == &"gold":
			options.append(_make_gold_option(_normal_gold_amount()))
		else:
			var category_items: Array[Item] = category[&"items"]
			var item := _take_weighted(category_items)
			options.append(_make_item_option(item, _resolution_for_item(item, false)))
	return _install_draft(
		token, BattlePlan.RewardPolicy.NORMAL, source_id,
		RewardOfferScript.Mode.NORMAL_EXCLUSIVE, options
	)


func draft_normal_rewards(
	token: RunFlowToken,
	source_id: StringName,
	marble_candidates: Array = [],
	skill_candidates: Array = []
) -> RewardOffer:
	return create_normal_draft(token, source_id, marble_candidates, skill_candidates)


func draft_normal(
	token: RunFlowToken,
	source_id: StringName,
	marble_candidates: Array = [],
	skill_candidates: Array = []
) -> RewardOffer:
	return create_normal_draft(token, source_id, marble_candidates, skill_candidates)


func create_elite_draft(
	token: RunFlowToken,
	source_id: StringName,
	relic_candidates: Array = []
) -> RewardOffer:
	if not _can_draft(token, source_id):
		return null
	var relics := _items_from(relic_candidates)
	if relic_candidates.is_empty():
		relics = _registry_query(Item.ItemType.RELIC)
		if relics.is_empty():
			relics = _load_items(DEFAULT_RELIC_PATHS)
	relics = _eligible_pool(relics, Item.ItemType.RELIC, true)
	var options: Array[RewardOption] = []
	if not relics.is_empty():
		var relic := _take_weighted(relics)
		options.append(_make_item_option(relic, _resolution_for_item(relic, true)))
	options.append(_make_gold_option(_random_source.range_int(ELITE_GOLD_MIN, ELITE_GOLD_MAX)))
	return _install_draft(
		token, BattlePlan.RewardPolicy.ELITE, source_id,
		RewardOfferScript.Mode.ELITE_CLAIM_ALL, options
	)


func draft_elite_rewards(
	token: RunFlowToken,
	source_id: StringName,
	relic_candidates: Array = []
) -> RewardOffer:
	return create_elite_draft(token, source_id, relic_candidates)


func draft_elite(
	token: RunFlowToken,
	source_id: StringName,
	relic_candidates: Array = []
) -> RewardOffer:
	return create_elite_draft(token, source_id, relic_candidates)


func claim(token: RunFlowToken, draft_id: StringName, offer_id: StringName) -> RewardResult:
	var validation := _validate_intent(token, draft_id, offer_id)
	if validation != null:
		return validation
	var option := _active_draft.offer_by_id(offer_id)
	var state_validation := _validate_option_state(option)
	if state_validation != RewardResult.Code.GRANTED:
		return _failure(state_validation, option, _validation_detail)
	if option.resolution == RewardOptionScript.Resolution.REPLACE_SKILL:
		return _request_replacement(option)
	return _commit_option(option)


func claim_reward(token: RunFlowToken, draft_id: StringName, offer_id: StringName) -> RewardResult:
	return claim(token, draft_id, offer_id)


func settle(token: RunFlowToken, draft_id: StringName, offer_id: StringName) -> RewardResult:
	return claim(token, draft_id, offer_id)


func confirm_replacement(token: RunFlowToken, replacement_token: StringName) -> RewardResult:
	var validation := _validate_replacement(token, replacement_token)
	if validation != null:
		return validation
	var offer_id := StringName(_pending_replacement[&"offer_id"])
	var option := _active_draft.offer_by_id(offer_id)
	var state_validation := _validate_option_state(option)
	if state_validation != RewardResult.Code.GRANTED:
		return _failure(state_validation, option, _validation_detail)
	var previous_skill := _loadout.call("current_skill") as Item
	_settling = true
	var transaction: RefCounted = RewardTransactionScript.new([_loadout, _progression, _wallet])
	var replacement_steps: Array[Callable] = [
		Callable(_loadout, "replace_skill").bind(option.item),
		Callable(_progression, "reset_skill").bind(previous_skill.id),
	]
	var committed := bool(transaction.call("execute", replacement_steps))
	if not committed:
		_settling = false
		return _transaction_failure(option, transaction, "skill replacement commit failed")
	_pending_replacement.clear()
	return _finalize_success(option, 0)


func confirm_skill_replacement(token: RunFlowToken, replacement_token: StringName) -> RewardResult:
	return confirm_replacement(token, replacement_token)


func cancel_replacement(token: RunFlowToken, replacement_token: StringName) -> RewardResult:
	var validation := _validate_replacement(token, replacement_token)
	if validation != null:
		return validation
	var option := _active_draft.offer_by_id(StringName(_pending_replacement[&"offer_id"]))
	_pending_replacement.clear()
	return RewardResultScript.new(
		token, RewardResult.Code.DECLINED, option, "replacement cancelled",
		_active_draft.draft_id, option.offer_id
	)


func cancel_skill_replacement(token: RunFlowToken, replacement_token: StringName) -> RewardResult:
	return cancel_replacement(token, replacement_token)


func clear_pending_replacement() -> bool:
	if _settling:
		return false
	_pending_replacement.clear()
	return true


func clear_active() -> bool:
	if _settling:
		return false
	var had_active := _active_draft != null or not _pending_replacement.is_empty()
	_active_draft = null
	_pending_replacement.clear()
	if had_active:
		changed.emit()
	return true


func clear() -> bool:
	return clear_active()


func clear_active_session() -> bool:
	return clear_active()


func _can_draft(token: RunFlowToken, source_id: StringName) -> bool:
	var active_is_open := _active_draft != null and not _active_draft.consumed
	return _configured and token != null and token.is_valid() and not source_id.is_empty() \
		and not _settling and not active_is_open and _pending_replacement.is_empty()


func _install_draft(
	token: RunFlowToken,
	policy: BattlePlan.RewardPolicy,
	source_id: StringName,
	mode: int,
	options: Array[RewardOption]
) -> RewardOffer:
	if options.is_empty():
		return null
	_draft_nonce += 1
	var draft_id := StringName("reward:%d:%d:%d:%d" % [
		token.run_id, token.node_id, token.phase_id, _draft_nonce,
	])
	var inventory_revision := int(_loadout.call("revision"))
	var progression_revision := int(_progression.call("revision"))
	var wallet_revision := int(_wallet.call("revision"))
	for option: RewardOption in options:
		_capture_option_state(option, inventory_revision, progression_revision, wallet_revision)
	_pending_replacement.clear()
	_active_draft = RewardOfferScript.new(
		token, policy, source_id, options, draft_id, mode,
		inventory_revision, progression_revision, wallet_revision
	)
	changed.emit()
	return _active_draft


func _make_gold_option(amount: int) -> RewardOption:
	_offer_nonce += 1
	return RewardOptionScript.new(
		StringName("reward-offer:%d" % _offer_nonce),
		RewardOptionScript.Kind.GOLD,
		null,
		maxi(1, amount),
		"gold",
		RewardOptionScript.Resolution.CREDIT_GOLD
	)


func _make_item_option(item: Item, resolution: int) -> RewardOption:
	_offer_nonce += 1
	return RewardOptionScript.new(
		StringName("reward-offer:%d" % _offer_nonce),
		RewardOptionScript.Kind.ITEM,
		item,
		0,
		_identity_key(item),
		resolution,
		COMPENSATION_GOLD
	)


func _capture_option_state(
	option: RewardOption,
	inventory_revision: int,
	progression_revision: int,
	wallet_revision: int
) -> void:
	var owned: Item = null
	var owned_instance_id := 0
	var owned_identity := ""
	var expected_level := 0
	if option.kind == RewardOptionScript.Kind.ITEM:
		owned = _loadout.call("find_owned", option.item) as Item
		if option.resolution == RewardOptionScript.Resolution.REPLACE_SKILL:
			owned = _loadout.call("current_skill") as Item
		if owned != null:
			owned_instance_id = int(owned.get_instance_id())
			owned_identity = _identity_key(owned)
			expected_level = int(_progression.call("level_of", owned))
	option.call(
		"_configure_settlement",
		option.item_identity,
		option.resolution,
		option.compensation_amount,
		inventory_revision,
		progression_revision,
		wallet_revision,
		owned_instance_id,
		owned_identity,
		expected_level
	)


func _validate_intent(
	token: RunFlowToken,
	draft_id: StringName,
	offer_id: StringName
) -> RewardResult:
	if not _configured:
		return _failure(RewardResult.Code.NOT_CONFIGURED, null, "reward service is not configured", token, draft_id, offer_id)
	if _settling:
		return _failure(RewardResult.Code.REENTRANT, null, "reward settlement is already active", token, draft_id, offer_id)
	if _active_draft == null or draft_id.is_empty() or draft_id != _active_draft.draft_id:
		return _failure(RewardResult.Code.INVALID_DRAFT, null, "draft is not active", token, draft_id, offer_id)
	if token == null or _active_draft.token == null or not _active_draft.token.matches(token):
		return _failure(RewardResult.Code.STALE_TOKEN, null, "flow token is stale", token, draft_id, offer_id)
	if _active_draft.consumed:
		return _failure(RewardResult.Code.DRAFT_CONSUMED, null, "draft is consumed", token, draft_id, offer_id)
	var option := _active_draft.offer_by_id(offer_id)
	if option == null:
		return _failure(RewardResult.Code.UNKNOWN_OFFER, null, "offer does not belong to draft", token, draft_id, offer_id)
	if option.consumed:
		return _failure(RewardResult.Code.OFFER_CONSUMED, option, "offer is consumed")
	return null


func _validate_option_state(option: RewardOption) -> RewardResult.Code:
	_validation_detail = ""
	if option == null or not option.is_valid():
		return _invalid_option(RewardResult.Code.REJECTED, "reward option is invalid")
	if int(_loadout.call("revision")) != option.inventory_revision \
			or int(_progression.call("revision")) != option.progression_revision \
			or int(_wallet.call("revision")) != option.wallet_revision:
		return _invalid_option(RewardResult.Code.STALE_DRAFT, "reward revisions are stale")
	if option.kind == RewardOptionScript.Kind.GOLD:
		return RewardResult.Code.GRANTED
	if _identity_key(option.item) != option.item_identity:
		return _invalid_option(RewardResult.Code.OWNERSHIP_CHANGED, "offered item identity changed")
	var owned := _loadout.call("find_owned", option.item) as Item
	if option.resolution == RewardOptionScript.Resolution.ADD_ITEM:
		if owned != null:
			return _invalid_option(RewardResult.Code.OWNERSHIP_CHANGED, "new reward is now owned")
		if not bool(_loadout.call("can_add", option.item)):
			return RewardResult.Code.CAPACITY_CHANGED
	elif option.resolution == RewardOptionScript.Resolution.UPGRADE_RELIC:
		if not _matches_expected_owned(owned, option):
			return _invalid_option(RewardResult.Code.OWNERSHIP_CHANGED, "upgrade target ownership changed")
		if int(_progression.call("level_of", owned)) != option.expected_level \
				or not bool(_progression.call("can_upgrade", owned)):
			return RewardResult.Code.LEVEL_CHANGED
	elif option.resolution == RewardOptionScript.Resolution.COMPENSATE:
		if not option.expected_owned_identity.is_empty():
			if not _matches_expected_owned(owned, option):
				return _invalid_option(RewardResult.Code.OWNERSHIP_CHANGED, "compensation target ownership changed")
			if int(_progression.call("level_of", owned)) != option.expected_level \
					or bool(_progression.call("can_upgrade", owned)):
				return RewardResult.Code.LEVEL_CHANGED
		elif owned != null:
			return _invalid_option(RewardResult.Code.OWNERSHIP_CHANGED, "blocked reward is now owned")
		elif bool(_loadout.call("can_add", option.item)):
			return RewardResult.Code.CAPACITY_CHANGED
	elif option.resolution == RewardOptionScript.Resolution.REPLACE_SKILL:
		if owned != null:
			return _invalid_option(RewardResult.Code.OWNERSHIP_CHANGED, "replacement reward is now owned")
		var current_skill := _loadout.call("current_skill") as Item
		if current_skill == null or _identity_key(current_skill) != option.expected_owned_identity:
			return _invalid_option(RewardResult.Code.OWNERSHIP_CHANGED, "current skill ownership changed")
	return RewardResult.Code.GRANTED


func _invalid_option(code: RewardResult.Code, detail: String) -> RewardResult.Code:
	_validation_detail = detail
	return code


func _request_replacement(option: RewardOption) -> RewardResult:
	if not _pending_replacement.is_empty() \
			and StringName(_pending_replacement.get(&"offer_id", &"")) == option.offer_id:
		return _replacement_required_result(option, StringName(_pending_replacement[&"token"]))
	_replacement_nonce += 1
	var replacement_token := StringName("reward-replace:%d:%d" % [_draft_nonce, _replacement_nonce])
	_pending_replacement = {
		&"token": replacement_token,
		&"draft_id": _active_draft.draft_id,
		&"offer_id": option.offer_id,
	}
	return _replacement_required_result(option, replacement_token)


func _replacement_required_result(option: RewardOption, replacement_token: StringName) -> RewardResult:
	return RewardResultScript.new(
		_active_draft.token,
		RewardResult.Code.SKILL_REPLACEMENT_REQUIRED,
		option,
		"skill slot replacement must be confirmed",
		_active_draft.draft_id,
		option.offer_id,
		replacement_token
	)


func _validate_replacement(token: RunFlowToken, replacement_token: StringName) -> RewardResult:
	if not _configured:
		return _failure(RewardResult.Code.NOT_CONFIGURED, null, "reward service is not configured", token)
	if _settling:
		return _failure(RewardResult.Code.REENTRANT, null, "reward settlement is already active", token)
	if _active_draft == null or _pending_replacement.is_empty() \
			or replacement_token.is_empty() \
			or replacement_token != StringName(_pending_replacement.get(&"token", &"")) \
			or _active_draft.draft_id != StringName(_pending_replacement.get(&"draft_id", &"")):
		return _failure(RewardResult.Code.INVALID_REPLACEMENT_TOKEN, null, "replacement token is not pending", token)
	if token == null or not _active_draft.token.matches(token):
		return _failure(RewardResult.Code.STALE_TOKEN, null, "flow token is stale", token)
	if _active_draft.consumed:
		return _failure(RewardResult.Code.DRAFT_CONSUMED, null, "draft is consumed", token)
	var option := _active_draft.offer_by_id(StringName(_pending_replacement[&"offer_id"]))
	if option == null or option.consumed:
		return _failure(RewardResult.Code.OFFER_CONSUMED, option, "replacement offer is consumed", token)
	return null


func _commit_option(option: RewardOption) -> RewardResult:
	var steps: Array[Callable] = []
	var granted_gold := 0
	match option.resolution:
		RewardOptionScript.Resolution.CREDIT_GOLD:
			granted_gold = option.gold_amount
			steps.append(Callable(_wallet, "credit").bind(granted_gold))
		RewardOptionScript.Resolution.COMPENSATE:
			granted_gold = option.compensation_amount
			steps.append(Callable(_wallet, "credit").bind(granted_gold))
		RewardOptionScript.Resolution.ADD_ITEM:
			steps.append(Callable(_loadout, "add").bind(option.item))
		RewardOptionScript.Resolution.UPGRADE_RELIC:
			var owned := _loadout.call("find_owned", option.item) as Item
			steps.append(Callable(_progression, "upgrade_one").bind(owned))
		_:
			return _failure(RewardResult.Code.REJECTED, option, "unsupported reward resolution")
	_settling = true
	var transaction: RefCounted = RewardTransactionScript.new([_loadout, _progression, _wallet])
	if not bool(transaction.call("execute", steps)):
		_settling = false
		return _transaction_failure(option, transaction, "reward commit failed")
	return _finalize_success(option, granted_gold)


func _finalize_success(option: RewardOption, granted_gold: int) -> RewardResult:
	option.call("_mark_consumed")
	_pending_replacement.clear()
	var just_completed := false
	if _active_draft.mode != RewardOfferScript.Mode.ELITE_CLAIM_ALL:
		_active_draft.call("_mark_completed")
		just_completed = true
	else:
		_refresh_remaining_elite_revisions()
		if _active_draft.remaining_options().is_empty():
			_active_draft.call("_mark_completed")
			just_completed = true
	var result: RewardResult = RewardResultScript.new(
		_active_draft.token,
		RewardResult.Code.GRANTED,
		option,
		"reward granted",
		_active_draft.draft_id,
		option.offer_id,
		&"",
		true,
		true,
		granted_gold
	)
	changed.emit()
	if just_completed:
		draft_completed.emit(_active_draft.draft_id)
	_settling = false
	return result


func _refresh_remaining_elite_revisions() -> void:
	var inventory_revision := int(_loadout.call("revision"))
	var progression_revision := int(_progression.call("revision"))
	var wallet_revision := int(_wallet.call("revision"))
	_active_draft.call("_refresh_revisions", inventory_revision, progression_revision, wallet_revision)
	for remaining: RewardOption in _active_draft.remaining_options():
		remaining.call("_refresh_revisions", inventory_revision, progression_revision, wallet_revision)


func _transaction_failure(option: RewardOption, transaction: RefCounted, detail: String) -> RewardResult:
	var rollback_completed := bool(transaction.get("rollback_completed"))
	return RewardResultScript.new(
		_active_draft.token,
		RewardResult.Code.COMMIT_FAILED if rollback_completed else RewardResult.Code.ROLLBACK_FAILED,
		option,
		"%s at step %d" % [detail, int(transaction.get("failed_step"))],
		_active_draft.draft_id,
		option.offer_id,
		&"",
		false,
		rollback_completed
	)


func _failure(
	code: RewardResult.Code,
	option: RewardOption,
	detail: String,
	token: RunFlowToken = null,
	draft_id: StringName = &"",
	offer_id: StringName = &""
) -> RewardResult:
	var result_token := token
	if result_token == null and _active_draft != null:
		result_token = _active_draft.token
	var result_draft_id := draft_id
	if result_draft_id.is_empty() and _active_draft != null:
		result_draft_id = _active_draft.draft_id
	var result_offer_id := offer_id
	if result_offer_id.is_empty() and option != null:
		result_offer_id = option.offer_id
	return RewardResultScript.new(
		result_token, code, option, detail, result_draft_id, result_offer_id
	)


func _resolution_for_item(item: Item, allow_compensation: bool) -> int:
	if item == null or item.type not in [Item.ItemType.MARBLE, Item.ItemType.RELIC, Item.ItemType.SKILL]:
		return -1
	var owned := _loadout.call("find_owned", item) as Item
	if owned != null:
		if owned.type != Item.ItemType.RELIC:
			return -1
		return RewardOptionScript.Resolution.UPGRADE_RELIC \
			if bool(_progression.call("can_upgrade", owned)) \
			else RewardOptionScript.Resolution.COMPENSATE
	if item.type == Item.ItemType.SKILL and _loadout.call("current_skill") != null:
		return RewardOptionScript.Resolution.REPLACE_SKILL
	if bool(_loadout.call("can_add", item)):
		return RewardOptionScript.Resolution.ADD_ITEM
	return RewardOptionScript.Resolution.COMPENSATE if allow_compensation else -1


func _eligible_pool(items: Array[Item], expected_type: Item.ItemType, allow_compensation: bool) -> Array[Item]:
	var result: Array[Item] = []
	for item: Item in items:
		if item == null or item.type != expected_type or _contains_identity(result, item):
			continue
		if _eligible_resolution(item, allow_compensation) >= 0:
			result.append(item)
	return result


func _eligible_resolution(item: Item, allow_compensation: bool) -> int:
	if item == null or item.weight <= 0.0 or not _requirements_met(item):
		return -1
	return _resolution_for_item(item, allow_compensation)


func _weighted_category_index(categories: Array[Dictionary]) -> int:
	var weights := PackedInt32Array()
	for category: Dictionary in categories:
		weights.append(maxi(0, int(category[&"weight"])))
	return _random_source.weighted_index(weights)


func _normal_gold_amount() -> int:
	var minimum := mini(_config.gold_min, _config.gold_max)
	var maximum := maxi(_config.gold_min, _config.gold_max)
	return maxi(1, _random_source.range_int(minimum, maximum))


func _take_random(items: Array[Item]) -> Item:
	if items.is_empty():
		return null
	var index := _random_source.range_int(0, items.size() - 1)
	return items.pop_at(clampi(index, 0, items.size() - 1))


func _take_weighted(items: Array[Item]) -> Item:
	if items.is_empty():
		return null
	var weights := PackedFloat64Array()
	var first_weight := -1.0
	var equal_positive_weights := true
	for item: Item in items:
		var weight := maxf(0.0, item.weight) if item != null else 0.0
		weights.append(weight)
		if first_weight < 0.0:
			first_weight = weight
		elif not is_equal_approx(first_weight, weight):
			equal_positive_weights = false
	# Preserve the old deterministic explicit-candidate contract while registry
	# pools use their authored float weights.
	if equal_positive_weights and first_weight > 0.0:
		return _take_random(items)
	var index := _random_source.weighted_index_float(weights)
	if index < 0:
		return null
	return items.pop_at(index)


func _items_from(values: Array) -> Array[Item]:
	var result: Array[Item] = []
	for value: Variant in values:
		var item := value as Item
		if item != null:
			result.append(item)
	return result


func _load_items(paths: PackedStringArray) -> Array[Item]:
	var result: Array[Item] = []
	for path: String in paths:
		var item := load(path) as Item
		if item != null:
			result.append(item)
	return result


func _registry_all_items() -> Array[Item]:
	if _content_registry == null or not is_instance_valid(_content_registry) \
			or not _content_registry.has_method(&"query"):
		return []
	var result: Array[Item] = []
	for item_type: Item.ItemType in [
		Item.ItemType.MARBLE, Item.ItemType.RELIC, Item.ItemType.SKILL,
	]:
		result.append_array(_registry_query(item_type))
	return result


func _registry_query(item_type: Item.ItemType) -> Array[Item]:
	if _content_registry == null or not is_instance_valid(_content_registry) \
			or not _content_registry.has_method(&"query"):
		return []
	return _items_from(_content_registry.call(&"query", item_type) as Array)


func _requirements_met(item: Item) -> bool:
	if item == null or item.requires_tags.is_empty():
		return true
	var owned_tags: Array[StringName] = []
	if _loadout != null and _loadout.has_method(&"owned_items"):
		for value: Variant in _loadout.call(&"owned_items") as Array:
			var owned := value as Item
			if owned == null:
				continue
			for tag: StringName in owned.tags:
				if not owned_tags.has(tag):
					owned_tags.append(tag)
	for required: StringName in item.requires_tags:
		if not owned_tags.has(required):
			return false
	return true


func _contains_identity(items: Array[Item], candidate: Item) -> bool:
	var key := _identity_key(candidate)
	for item: Item in items:
		if _identity_key(item) == key:
			return true
	return false


func _identity_key(item: Item) -> String:
	if item == null:
		return ""
	if item.type == Item.ItemType.MARBLE:
		return "type:%d:marble:%d" % [int(item.type), int(item.marble_type)]
	if not item.id.is_empty():
		return "type:%d:id:%s" % [int(item.type), item.id]
	if not item.resource_path.is_empty():
		return "type:%d:path:%s" % [int(item.type), item.resource_path]
	if item.effect_type != Item.EffectType.NONE:
		return "type:%d:effect:%d" % [int(item.type), int(item.effect_type)]
	return "type:%d:instance:%d" % [int(item.type), item.get_instance_id()]


func _matches_expected_owned(owned: Item, option: RewardOption) -> bool:
	# Loadout revision already includes instance identity. Settlement follows the
	# domain identity contract so relic candidates always resolve to the owned
	# instance returned by Loadout.find_owned().
	return owned != null and _identity_key(owned) == option.expected_owned_identity


func _has_api(value: Variant, methods: Array[StringName]) -> bool:
	if value == null:
		return false
	for method: StringName in methods:
		if not value.has_method(method):
			return false
	return true
