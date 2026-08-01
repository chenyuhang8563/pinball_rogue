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


class FakeContentRegistry extends Node:
	var _items: Array[Item] = []

	func _init(items: Array) -> void:
		for value: Variant in items:
			var item := value as Item
			if item != null:
				_items.append(item)

	func query(type: Item.ItemType) -> Array[Item]:
		var result: Array[Item] = []
		for item: Item in _items:
			if item.type == type:
				result.append(item)
		return result

	func by_id(item_id: StringName) -> Item:
		for item: Item in _items:
			if StringName(item.id) == item_id:
				return item
		return null


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


func test_node_draft_includes_upgradable_owned_items_with_stable_identities() -> void:
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
	assert_true(identities.any(func(value: String) -> bool: return value.contains("marble:0")))
	assert_true(identities.any(func(value: String) -> bool: return value.contains("blocked-relic")))
	assert_eq(_item_offer(draft).resolution, RewardOption.Resolution.UPGRADE_ITEM)
	assert_eq(_item_offer(draft).target_level, 2)
	assert_true(_item_offer(draft).is_upgrade)


func test_node_draft_falls_back_to_compensation_when_every_candidate_is_ineligible() -> void:
	var loadout: RefCounted = LoadoutScript.new(func(_type: int, _fallback: int) -> int: return 0)
	var progression: RefCounted = ProgressionScript.new(loadout)
	var wallet: RefCounted = WalletScript.new()
	var service: RefCounted = _service(loadout, progression, wallet)

	var draft: RewardOffer = service.create_node_draft(
		_token, &"blocked-node", [_item("full", Item.ItemType.RELIC)]
	)

	assert_eq(draft.options().size(), 1)
	assert_eq(draft.options()[0].kind, RewardOption.Kind.ITEM)
	assert_eq(draft.options()[0].resolution, RewardOption.Resolution.REPLACE_RELIC)


func test_normal_draft_builds_fixed_gold_and_three_unique_marble_choices() -> void:
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
		[
			_item("brown", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.BROWN),
			_item("green", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.GREEN),
			_item("bomb", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.BOMB),
		],
		[_item("dash", Item.ItemType.SKILL)]
	)

	assert_eq(draft.mode, RewardOffer.Mode.NORMAL_CLAIM_ALL_MARBLE_CHOICE)
	assert_eq(draft.options().size(), 4)
	assert_eq(draft.options()[0].kind, RewardOption.Kind.GOLD)
	assert_eq(draft.options()[0].gold_amount, 17)
	var marble_ids: Array[String] = []
	for option: RewardOption in draft.options():
		if option.kind == RewardOption.Kind.ITEM:
			assert_eq(option.item.type, Item.ItemType.MARBLE)
			assert_eq(option.target_level, 1)
			assert_false(option.is_upgrade)
			assert_false(marble_ids.has(option.item.id))
			marble_ids.append(option.item.id)
	assert_eq(marble_ids.size(), 3)


func test_normal_draft_always_includes_gold_even_when_item_weights_are_higher() -> void:
	# 问题来源：玩家反馈普通战斗会出现两个物品奖励，消耗了应有的金币选择。
	# 修复方式：金币作为普通奖励的固定选项，第二个选项才从物品类别按权重抽取。
	# 边界：物品权重大于金币时，仍必须保留一个金币选项。
	_config.marble_weight = 100
	_config.skill_weight = 100
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var wallet: RefCounted = WalletScript.new()
	var service: RefCounted = _service(loadout, progression, wallet)

	var draft: RewardOffer = service.create_normal_draft(
		_token,
		&"normal-gold-guarantee",
		[_item("brown", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.BROWN)],
		[_item("dash", Item.ItemType.SKILL)]
	)

	assert_eq(draft.options().size(), 2, "explicit one-marble fixture exposes one selectable marble")
	assert_not_null(_gold_offer(draft), "normal rewards must always include gold")
	assert_not_null(_item_offer(draft), "normal rewards retain one item choice")


func test_normal_draft_upgrades_duplicate_marble_without_adding_quantity() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var wallet: RefCounted = WalletScript.new()
	var owned := _item("owned-brown", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.BROWN)
	var duplicate := _item("reward-brown", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.BROWN)
	var green := _item("green", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.GREEN)
	assert_true(loadout.call("add", owned))
	var service: RefCounted = _service(loadout, progression, wallet)

	var draft: RewardOffer = service.create_normal_draft(
		_token, &"normal-duplicate-marble", [duplicate, green]
	)
	var upgrade_offer := _marble_offer(draft, Marble.MARBLE_TYPE.BROWN)
	var new_offer := _marble_offer(draft, Marble.MARBLE_TYPE.GREEN)
	assert_not_null(upgrade_offer)
	assert_not_null(new_offer)
	if upgrade_offer == null or new_offer == null:
		return
	assert_eq(upgrade_offer.resolution, RewardOption.Resolution.UPGRADE_ITEM)
	assert_eq(upgrade_offer.expected_owned_instance_id, int(owned.get_instance_id()))
	assert_eq(upgrade_offer.expected_owned_identity, upgrade_offer.item_identity)
	assert_eq(upgrade_offer.expected_level, 1)
	assert_eq(upgrade_offer.target_level, 2)
	assert_true(upgrade_offer.is_upgrade)
	assert_eq(new_offer.target_level, 1)
	assert_false(new_offer.is_upgrade)

	var marble_count := (loadout.call("marbles") as Array).size()
	var result: RewardResult = service.claim(_token, draft.draft_id, upgrade_offer.offer_id)
	assert_true(result.was_granted(), result.detail)
	assert_eq(progression.call("level_of", owned), 2)
	assert_eq((loadout.call("marbles") as Array).size(), marble_count)
	assert_eq(loadout.call("find_owned", duplicate), owned)


func test_normal_draft_filters_full_level_duplicate_marble() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var wallet: RefCounted = WalletScript.new()
	var owned := _item("owned-brown", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.BROWN)
	var duplicate := _item("reward-brown", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.BROWN)
	var green := _item("green", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.GREEN)
	assert_true(loadout.call("add", owned))
	for _upgrade: int in range(3):
		assert_true(progression.call("upgrade_one", owned))
	var service: RefCounted = _service(loadout, progression, wallet)

	var draft: RewardOffer = service.create_normal_draft(
		_token, &"normal-full-marble", [duplicate, green]
	)
	assert_null(_marble_offer(draft, Marble.MARBLE_TYPE.BROWN))
	var new_offer := _marble_offer(draft, Marble.MARBLE_TYPE.GREEN)
	assert_not_null(new_offer)
	if new_offer != null:
		assert_eq(new_offer.target_level, 1)
		assert_false(new_offer.is_upgrade)


func test_elite_duplicate_marble_restores_upgrade_target_and_filters_full_level() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var wallet: RefCounted = WalletScript.new()
	var owned := _item("owned-brown", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.BROWN)
	var duplicate := _item("reward-brown", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.BROWN)
	var green := _item("green", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.GREEN)
	var relic := _item("elite-relic", Item.ItemType.RELIC)
	assert_true(loadout.call("add", owned))
	var registry := add_child_autofree(FakeContentRegistry.new([duplicate, green, relic])) as Node
	var service: RefCounted = _service(loadout, progression, wallet, registry)
	var draft: RewardOffer = service.create_elite_draft(_token, &"elite-duplicate", [relic])
	var snapshot: Dictionary = service.call("snapshot_active")
	assert_true(service.call("clear_active"))

	service = _service(loadout, progression, wallet, registry)
	var restored: RewardOffer = service.call("restore_active", _token, snapshot, registry)
	assert_not_null(restored)
	if restored == null:
		return
	var upgrade_offer := _marble_offer(restored, Marble.MARBLE_TYPE.BROWN)
	assert_not_null(upgrade_offer)
	if upgrade_offer == null:
		return
	assert_eq(upgrade_offer.resolution, RewardOption.Resolution.UPGRADE_ITEM)
	assert_eq(upgrade_offer.expected_owned_instance_id, int(owned.get_instance_id()))
	assert_eq(upgrade_offer.target_level, 2)
	assert_true(upgrade_offer.is_upgrade)
	var marble_count := (loadout.call("marbles") as Array).size()
	var result: RewardResult = service.claim(_token, restored.draft_id, upgrade_offer.offer_id)
	assert_true(result.was_granted(), result.detail)
	assert_eq(progression.call("level_of", owned), 2)
	assert_eq((loadout.call("marbles") as Array).size(), marble_count)

	assert_true(service.call("clear_active"))
	for _upgrade: int in range(2):
		assert_true(progression.call("upgrade_one", owned))
	var full_draft: RewardOffer = service.create_elite_draft(_token, &"elite-full-marble", [relic])
	assert_null(_marble_offer(full_draft, Marble.MARBLE_TYPE.BROWN))
	assert_not_null(_marble_offer(full_draft, Marble.MARBLE_TYPE.GREEN))


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
		var item_offer := _relic_offer(draft)
		assert_eq(item_offer.resolution, RewardOption.Resolution.UPGRADE_ITEM)
		assert_eq(item_offer.target_level, expected_level)
		assert_true(item_offer.is_upgrade)
		var result: RewardResult = service.claim(_token, draft.draft_id, item_offer.offer_id)
		assert_true(result.was_granted())
		assert_eq(progression.call("level_of", owned), expected_level)
		assert_eq(loadout.call("find_owned", candidate), owned)
		# Elite drafts claim-all; settle the abandoned gold so the next draft is legal.
		assert_true(service.clear_active())

	var full_draft: RewardOffer = service.create_elite_draft(_token, &"elite-full", [candidate])
	var compensation := _relic_offer(full_draft)
	assert_eq(compensation.resolution, RewardOption.Resolution.COMPENSATE)
	assert_eq(compensation.target_level, 0)
	assert_false(compensation.is_upgrade)
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


func test_full_relic_slots_request_selection_without_consuming_then_replace_selected_relic() -> void:
	# 问题来源：玩家在遗物栏满时领取不同遗物，报价会被消耗但新遗物不会进入物品栏。
	# 修复方式：将满槽的不同遗物保留为待确认报价，确认所选旧遗物后原子替换。
	# 边界：取消不得消耗报价；确认只能替换当前持有的指定遗物。
	var loadout: RefCounted = LoadoutScript.new(func(item_type: Item.ItemType, fallback: int) -> int:
		return 1 if item_type == Item.ItemType.RELIC else fallback
	)
	var progression: RefCounted = ProgressionScript.new(loadout)
	var wallet: RefCounted = WalletScript.new()
	var old_relic := _item("old-relic", Item.ItemType.RELIC)
	var new_relic := _item("new-relic", Item.ItemType.RELIC)
	assert_true(loadout.call("add", old_relic))
	var service: RefCounted = _service(loadout, progression, wallet)
	var draft: RewardOffer = service.create_elite_draft(_token, &"relic-replacement", [new_relic])
	var relic_offer := _relic_offer(draft)

	var required: RewardResult = service.claim(_token, draft.draft_id, relic_offer.offer_id)

	assert_true(required.replacement_required(), "a full relic slot must request a replacement")
	assert_false(relic_offer.consumed)
	assert_false(draft.consumed)
	assert_eq(loadout.call("find_owned", old_relic), old_relic)
	if not required.replacement_required():
		return
	var cancelled: RewardResult = service.cancel_replacement(_token, required.replacement_token)
	assert_eq(cancelled.code, RewardResult.Code.DECLINED)
	assert_false(relic_offer.consumed)

	var required_again: RewardResult = service.claim(_token, draft.draft_id, relic_offer.offer_id)
	var confirmed: RewardResult = service.confirm_replacement(
		_token, required_again.replacement_token, old_relic
	)
	assert_true(confirmed.was_granted())
	assert_eq(loadout.call("find_owned", old_relic), null)
	assert_eq(loadout.call("find_owned", new_relic), new_relic)


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
	var draft: RewardOffer = service.create_node_draft(_token, &"skill", [new_skill])
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
	assert_eq(draft.options().size(), 4, "default production pools provide gold plus three marble choices")
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
	assert_true(service.claim(_token, fresh.draft_id, _item_offer(fresh).offer_id).was_granted())
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
	var first_item := _relic_offer(first)
	var first_gold := _gold_offer(first)
	assert_true(service.claim(_token, first.draft_id, first_item.offer_id).was_granted())
	assert_true(service.claim(_token, first.draft_id, first_gold.offer_id).was_granted())
	assert_true(_claim_first_marble(service, first).was_granted())
	assert_true(first.completed)
	assert_eq(completed_ids.count(first.draft_id), 1)
	assert_eq(service.claim(_token, first.draft_id, first_gold.offer_id).code, RewardResult.Code.DRAFT_CONSUMED)
	assert_eq(completed_ids.count(first.draft_id), 1)

	var second: RewardOffer = service.create_elite_draft(
		_token, &"gold-then-item", [_item("second-relic", Item.ItemType.RELIC)]
	)
	assert_true(service.claim(_token, second.draft_id, _gold_offer(second).offer_id).was_granted())
	assert_true(service.claim(_token, second.draft_id, _relic_offer(second).offer_id).was_granted())
	assert_true(_claim_first_marble(service, second).was_granted())
	assert_true(second.completed)

	var third: RewardOffer = service.create_elite_draft(
		_token, &"external-after-gold", [_item("third-relic", Item.ItemType.RELIC)]
	)
	assert_true(service.claim(_token, third.draft_id, _gold_offer(third).offer_id).was_granted())
	assert_true(wallet.call("credit", 1), "mutation after the most recent service claim must stale the remainder")
	assert_eq(
		service.claim(_token, third.draft_id, _relic_offer(third).offer_id).code,
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


func _service(
	loadout: Variant,
	progression: Variant,
	wallet: Variant,
	content_registry: Node = null
) -> RefCounted:
	var service: RefCounted = RewardServiceScript.new()
	assert_true(service.configure(
		loadout, progression, wallet, _config, _random, content_registry
	))
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


func _relic_offer(draft: RewardOffer) -> RewardOption:
	for option: RewardOption in draft.options():
		if option.kind == RewardOption.Kind.ITEM and option.item != null \
				and option.item.type == Item.ItemType.RELIC:
			return option
	return null


func _marble_offer(
	draft: RewardOffer,
	marble_type: Marble.MARBLE_TYPE
) -> RewardOption:
	if draft == null:
		return null
	for option: RewardOption in draft.options():
		if option.kind == RewardOption.Kind.ITEM and option.item != null \
				and option.item.type == Item.ItemType.MARBLE \
				and option.item.marble_type == marble_type:
			return option
	return null


func _gold_offer(draft: RewardOffer) -> RewardOption:
	for option: RewardOption in draft.options():
		if option.kind == RewardOption.Kind.GOLD:
			return option
	return null


func _claim_first_marble(service: RewardService, draft: RewardOffer) -> RewardResult:
	for option: RewardOption in draft.remaining_options():
		if option.kind == RewardOption.Kind.ITEM and option.item != null \
				and option.item.type == Item.ItemType.MARBLE:
			return service.claim(_token, draft.draft_id, option.offer_id)
	return RewardResult.new(_token, RewardResult.Code.REJECTED)


func _node_capacity(item_type: Item.ItemType, fallback: int) -> int:
	if item_type == Item.ItemType.MARBLE:
		return 3
	if item_type == Item.ItemType.RELIC:
		return 0
	return fallback
