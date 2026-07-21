extends GutTest

const RewardServiceScript: GDScript = preload("res://Run/application/reward_service.gd")
const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")
const WalletScript: GDScript = preload("res://Commerce/application/run_wallet.gd")
const TokenScript: GDScript = preload("res://Run/domain/run_flow_token.gd")


class DeterministicRandom extends RunRandomSource:
	var weighted_calls: Array[PackedInt32Array] = []

	func range_int(minimum: int, _maximum: int) -> int:
		return minimum

	func weighted_index(weights: PackedInt32Array) -> int:
		weighted_calls.append(weights.duplicate())
		var best_index := -1
		var best_weight := 0
		for index: int in range(weights.size()):
			if weights[index] > best_weight:
				best_weight = weights[index]
				best_index = index
		return best_index


class FailingWallet extends RefCounted:
	var amount: int = 0
	var restore_should_fail: bool = false

	func balance() -> int:
		return amount

	func credit(value: int) -> bool:
		amount += value
		return false

	func revision() -> int:
		return {&"balance": amount}.hash()

	func snapshot() -> Dictionary:
		return {&"balance": amount, &"revision": revision()}

	func restore(state: Dictionary) -> bool:
		if restore_should_fail:
			return false
		amount = int(state[&"balance"])
		return revision() == int(state[&"revision"])


var _token: RunFlowToken
var _config: BattleRewardConfig
var _random: DeterministicRandom


func before_each() -> void:
	_token = TokenScript.new(1, 2, 3)
	_config = BattleRewardConfig.new()
	_random = DeterministicRandom.new()


func test_node_draft_is_three_stable_identity_offers_and_filters_owned_or_full_items() -> void:
	var loadout: RefCounted = LoadoutScript.new(Callable(self, "_node_capacity"))
	var progression: RefCounted = ProgressionScript.new(loadout)
	var wallet: RefCounted = WalletScript.new()
	var dark := _item("dark-owned", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.DEFAULT)
	assert_true(loadout.call("add", dark))
	var duplicate_dark := _item("different-id", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.DEFAULT)
	var blocked_relic := _item("blocked-relic", Item.ItemType.RELIC)
	var brown := _item("brown", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.BROWN)
	var green := _item("green", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.GREEN)
	var dash := _item("dash", Item.ItemType.SKILL)
	var service: RefCounted = _service(loadout, progression, wallet)

	var draft: RewardOffer = service.create_node_draft(
		_token, &"node-reward", [duplicate_dark, blocked_relic, brown, green, dash]
	)

	assert_not_null(draft)
	assert_eq(draft.options().size(), 3)
	assert_ne(draft.draft_id, &"")
	var identities: Array[String] = []
	for option: RewardOption in draft.options():
		assert_ne(option.offer_id, &"")
		assert_false(identities.has(option.item_identity))
		identities.append(option.item_identity)
	assert_false(identities.any(func(value: String) -> bool: return value.contains("marble:0")))
	assert_false(identities.any(func(value: String) -> bool: return value.contains("blocked-relic")))


func test_node_draft_falls_back_to_compensation_when_every_candidate_is_ineligible() -> void:
	var loadout: RefCounted = LoadoutScript.new(func(_type: int, _fallback: int) -> int: return 0)
	var progression: RefCounted = ProgressionScript.new(loadout)
	var wallet: RefCounted = WalletScript.new()
	var service: RefCounted = _service(loadout, progression, wallet)

	var draft: RewardOffer = service.create_node_draft(
		_token, &"blocked-node", [_item("full", Item.ItemType.RELIC)]
	)

	assert_eq(draft.options().size(), 1)
	assert_eq(draft.options()[0].kind, RewardOption.Kind.GOLD)
	assert_eq(draft.options()[0].gold_amount, RewardServiceScript.COMPENSATION_GOLD)


func test_normal_draft_uses_configured_category_weights_and_builds_two_exclusive_offers() -> void:
	_config.gold_weight = 0
	_config.marble_weight = 100
	_config.skill_weight = 0
	_config.gold_min = 17
	_config.gold_max = 17
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var wallet: RefCounted = WalletScript.new()
	var service: RefCounted = _service(loadout, progression, wallet)

	var draft: RewardOffer = service.create_normal_draft(
		_token,
		&"normal-battle",
		[_item("brown", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.BROWN)],
		[_item("dash", Item.ItemType.SKILL)]
	)

	assert_eq(draft.mode, RewardOffer.Mode.NORMAL_EXCLUSIVE)
	assert_eq(draft.options().size(), 2)
	assert_eq(draft.options()[0].item.type, Item.ItemType.MARBLE)
	assert_eq(_random.weighted_calls[0], PackedInt32Array([0, 100, 0]))
	assert_eq(draft.options()[1].kind, RewardOption.Kind.GOLD)
	assert_eq(draft.options()[1].gold_amount, 17)


func test_duplicate_relic_upgrades_owned_instance_then_full_level_compensates() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var wallet: RefCounted = WalletScript.new()
	var owned := _item("growth-relic", Item.ItemType.RELIC)
	assert_true(loadout.call("add", owned))
	var service: RefCounted = _service(loadout, progression, wallet)
	var candidate := _item("growth-relic", Item.ItemType.RELIC)

	for expected_level: int in [2, 3, 4]:
		var draft: RewardOffer = service.create_elite_draft(_token, &"elite", [candidate])
		var item_offer := _item_offer(draft)
		assert_eq(item_offer.resolution, RewardOption.Resolution.UPGRADE_RELIC)
		var result: RewardResult = service.claim(_token, draft.draft_id, item_offer.offer_id)
		assert_true(result.was_granted())
		assert_eq(progression.call("level_of", owned), expected_level)
		assert_eq(loadout.call("find_owned", candidate), owned)
		# Elite drafts claim-all; settle the abandoned gold so the next draft is legal.
		assert_true(service.clear_active())

	var full_draft: RewardOffer = service.create_elite_draft(_token, &"elite-full", [candidate])
	var compensation := _item_offer(full_draft)
	assert_eq(compensation.resolution, RewardOption.Resolution.COMPENSATE)
	assert_eq(loadout.call("find_owned", compensation.item), owned)
	assert_eq(compensation.item_identity, "type:%d:id:growth-relic" % Item.ItemType.RELIC)
	assert_eq(compensation.expected_owned_instance_id, int(owned.get_instance_id()))
	assert_eq(compensation.expected_owned_identity, compensation.item_identity)
	assert_eq(progression.call("level_of", owned), compensation.expected_level)
	assert_false(progression.call("can_upgrade", owned))
	var compensated: RewardResult = service.claim(_token, full_draft.draft_id, compensation.offer_id)
	assert_eq(compensated.code, RewardResult.Code.GRANTED, compensated.detail)
	assert_true(compensated.was_granted())
	assert_eq(compensated.granted_gold, RewardServiceScript.COMPENSATION_GOLD)
	assert_eq(wallet.call("balance"), RewardServiceScript.COMPENSATION_GOLD)
	assert_eq(progression.call("level_of", owned), 4)


func test_skill_replacement_cancel_is_non_consuming_and_confirm_atomically_resets_old_skill() -> void:
	_config.gold_weight = 0
	_config.marble_weight = 0
	_config.skill_weight = 100
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var wallet: RefCounted = WalletScript.new()
	var old_skill := _item("dash", Item.ItemType.SKILL)
	var new_skill := _item("magic_missile", Item.ItemType.SKILL)
	assert_true(loadout.call("add", old_skill))
	assert_true(progression.call("upgrade_one", old_skill))
	assert_true(progression.call("upgrade_one", old_skill))
	assert_eq(progression.call("level_of", old_skill), 3)
	var service: RefCounted = _service(loadout, progression, wallet)
	var draft: RewardOffer = service.create_normal_draft(_token, &"skill", [], [new_skill])
	var skill_offer := _item_offer(draft)

	var required: RewardResult = service.claim(_token, draft.draft_id, skill_offer.offer_id)
	assert_eq(required.code, RewardResult.Code.SKILL_REPLACEMENT_REQUIRED)
	assert_true(required.replacement_required())
	var cancelled: RewardResult = service.cancel_replacement(_token, required.replacement_token)
	assert_eq(cancelled.code, RewardResult.Code.DECLINED)
	assert_false(skill_offer.consumed)
	assert_false(draft.consumed)
	assert_eq(loadout.call("current_skill"), old_skill)
	assert_eq(progression.call("level_of", old_skill), 3)

	var required_again: RewardResult = service.claim(_token, draft.draft_id, skill_offer.offer_id)
	var confirmed: RewardResult = service.confirm_replacement(_token, required_again.replacement_token)
	assert_true(confirmed.was_granted())
	assert_true(skill_offer.consumed)
	assert_true(draft.consumed)
	assert_eq(loadout.call("current_skill"), new_skill)
	assert_eq(progression.call("level_of", old_skill), 1)
	assert_true(service.clear_active())
	assert_null(service.active_draft())


func test_claim_rejects_illegal_stale_and_consumed_intents_with_typed_codes() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var wallet: RefCounted = WalletScript.new()
	var service: RefCounted = _service(loadout, progression, wallet)
	var draft: RewardOffer = service.create_normal_draft(_token, &"normal")
	assert_eq(draft.options().size(), 2, "default production pools preserve normal two-choice mode")
	var gold := draft.options()[0]

	assert_eq(
		service.claim(TokenScript.new(1, 2, 4), draft.draft_id, gold.offer_id).code,
		RewardResult.Code.STALE_TOKEN
	)
	assert_eq(
		service.claim(_token, draft.draft_id, &"not-an-offer").code,
		RewardResult.Code.UNKNOWN_OFFER
	)
	assert_true(wallet.call("credit", 1))
	assert_eq(
		service.claim(_token, draft.draft_id, gold.offer_id).code,
		RewardResult.Code.STALE_DRAFT
	)

	var fresh: RewardOffer
	# The stale draft was never consumed; settle it before requesting a new one.
	assert_true(service.clear_active())
	fresh = service.create_normal_draft(_token, &"normal-fresh")
	var fresh_gold := fresh.options()[0]
	assert_true(service.claim(_token, fresh.draft_id, fresh_gold.offer_id).was_granted())
	assert_eq(
		service.claim(_token, fresh.draft_id, fresh_gold.offer_id).code,
		RewardResult.Code.DRAFT_CONSUMED
	)


func test_elite_refreshes_all_remaining_revisions_in_both_claim_orders_and_only_completes_once() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var wallet: RefCounted = WalletScript.new()
	var service: RefCounted = _service(loadout, progression, wallet)
	var completed_ids: Array[StringName] = []
	service.draft_completed.connect(func(draft_id: StringName) -> void: completed_ids.append(draft_id))

	var first: RewardOffer = service.create_elite_draft(
		_token, &"item-then-gold", [_item("first-relic", Item.ItemType.RELIC)]
	)
	var first_item := _item_offer(first)
	var first_gold := _gold_offer(first)
	assert_true(service.claim(_token, first.draft_id, first_item.offer_id).was_granted())
	assert_true(service.claim(_token, first.draft_id, first_gold.offer_id).was_granted())
	assert_true(first.completed)
	assert_eq(completed_ids.count(first.draft_id), 1)
	assert_eq(service.claim(_token, first.draft_id, first_gold.offer_id).code, RewardResult.Code.DRAFT_CONSUMED)
	assert_eq(completed_ids.count(first.draft_id), 1)

	var second: RewardOffer = service.create_elite_draft(
		_token, &"gold-then-item", [_item("second-relic", Item.ItemType.RELIC)]
	)
	assert_true(service.claim(_token, second.draft_id, _gold_offer(second).offer_id).was_granted())
	assert_true(service.claim(_token, second.draft_id, _item_offer(second).offer_id).was_granted())
	assert_true(second.completed)

	var third: RewardOffer = service.create_elite_draft(
		_token, &"external-after-gold", [_item("third-relic", Item.ItemType.RELIC)]
	)
	assert_true(service.claim(_token, third.draft_id, _gold_offer(third).offer_id).was_granted())
	assert_true(wallet.call("credit", 1), "mutation after the most recent service claim must stale the remainder")
	assert_eq(
		service.claim(_token, third.draft_id, _item_offer(third).offer_id).code,
		RewardResult.Code.STALE_DRAFT
	)


func test_transaction_reports_commit_and_rollback_failure_without_consuming_offer() -> void:
	for rollback_fails: bool in [false, true]:
		var loadout: RefCounted = LoadoutScript.new()
		var progression: RefCounted = ProgressionScript.new(loadout)
		var wallet := FailingWallet.new()
		wallet.restore_should_fail = rollback_fails
		var service: RefCounted = _service(loadout, progression, wallet)
		var draft: RewardOffer = service.create_normal_draft(_token, &"transaction")
		var gold := draft.options()[0]

		var result: RewardResult = service.claim(_token, draft.draft_id, gold.offer_id)

		assert_eq(
			result.code,
			RewardResult.Code.ROLLBACK_FAILED if rollback_fails else RewardResult.Code.COMMIT_FAILED
		)
		assert_eq(result.rollback_completed, not rollback_fails)
		assert_false(gold.consumed)
		assert_false(draft.consumed)
		assert_eq(wallet.amount, gold.gold_amount if rollback_fails else 0)


func test_changed_signal_synchronous_reentry_is_guarded_before_double_settlement() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var wallet: RefCounted = WalletScript.new()
	var service: RefCounted = _service(loadout, progression, wallet)
	var draft: RewardOffer = service.create_normal_draft(_token, &"reentrant")
	var gold := draft.options()[0]
	var reentrant_results: Array[RewardResult] = []
	service.changed.connect(func() -> void:
		reentrant_results.append(service.claim(_token, draft.draft_id, gold.offer_id))
	)

	var result: RewardResult = service.claim(_token, draft.draft_id, gold.offer_id)

	assert_true(result.was_granted())
	assert_eq(reentrant_results.size(), 1)
	assert_eq(reentrant_results[0].code, RewardResult.Code.REENTRANT)
	assert_eq(wallet.call("balance"), gold.gold_amount)


func _service(loadout: Variant, progression: Variant, wallet: Variant) -> RefCounted:
	var service: RefCounted = RewardServiceScript.new()
	assert_true(service.configure(loadout, progression, wallet, _config, _random))
	return service


func _item(
	id: String,
	type: Item.ItemType,
	marble_type: Marble.MARBLE_TYPE = Marble.MARBLE_TYPE.DEFAULT
) -> Item:
	var item := Item.new()
	item.id = id
	item.type = type
	item.marble_type = marble_type
	return item


func _item_offer(draft: RewardOffer) -> RewardOption:
	for option: RewardOption in draft.options():
		if option.kind == RewardOption.Kind.ITEM:
			return option
	return null


func _gold_offer(draft: RewardOffer) -> RewardOption:
	for option: RewardOption in draft.options():
		if option.kind == RewardOption.Kind.GOLD:
			return option
	return null


func _node_capacity(item_type: Item.ItemType, fallback: int) -> int:
	if item_type == Item.ItemType.MARBLE:
		return 3
	if item_type == Item.ItemType.RELIC:
		return 0
	return fallback
