extends RefCounted
class_name RunUpgradeService

const UpgradeCandidateScript: GDScript = preload("res://Run/domain/upgrade_candidate.gd")
const UpgradeOfferScript: GDScript = preload("res://Run/domain/upgrade_offer.gd")
const UpgradeResultScript: GDScript = preload("res://Run/domain/upgrade_result.gd")

var _loadout: RefCounted = null
var _progression: RefCounted = null
var _active: UpgradeOffer = null
var _error_detail: String = ""
var _settling: bool = false


func configure(loadout: RefCounted, progression: RefCounted) -> bool:
	_loadout = loadout
	_progression = progression
	_active = null
	return _has_api(_loadout, [&"find_owned", &"revision"]) and _has_api(_progression, [
		&"upgradable_owned_items", &"level_of", &"can_upgrade", &"upgrade_one", &"revision",
	])


func active_offer() -> UpgradeOffer:
	return _active


func error_detail() -> String:
	return _error_detail


func present(token: RunFlowToken, node_id: int) -> UpgradeOffer:
	_error_detail = ""
	if _settling or token == null or not token.is_valid() or node_id < 1:
		return _fail("upgrade presentation request is invalid")
	var loadout_revision := int(_loadout.call("revision"))
	var progression_revision := int(_progression.call("revision"))
	var candidates: Array[UpgradeCandidate] = []
	var items: Array = _progression.call("upgradable_owned_items") as Array
	for index: int in range(items.size()):
		var item: Item = items[index] as Item
		var identity := _item_identity(item)
		if identity.is_empty():
			continue
		candidates.append(UpgradeCandidateScript.new(
			StringName("upgrade-candidate:%d:%d" % [node_id, index]),
			item,
			identity,
			int(item.get_instance_id()),
			loadout_revision,
			progression_revision,
			int(_progression.call("level_of", item))
		))
	_active = UpgradeOfferScript.new(
		token,
		StringName("upgrade:%d:%d:%d" % [token.run_id, token.node_id, token.phase_id]),
		loadout_revision,
		progression_revision,
		candidates
	)
	if not _active.is_valid():
		var invalid_detail := "constructed upgrade offer is invalid"
		for candidate: UpgradeCandidate in candidates:
			if not candidate.is_valid():
				invalid_detail = "invalid candidate id=%s identity=%s instance=%d level=%d" % [
					candidate.candidate_id,
					candidate.item_identity,
					candidate.owned_instance_id,
					candidate.expected_level,
				]
				break
		return _fail(invalid_detail)
	return _active


func select(token: RunFlowToken, offer_id: StringName, candidate_id: StringName) -> UpgradeResult:
	_error_detail = ""
	if not _valid_offer(token, offer_id, false):
		return null
	var candidate: UpgradeCandidate = _active.candidate_by_id(candidate_id)
	if candidate == null:
		return _result_failure(
			token, UpgradeResult.Code.UNKNOWN_CANDIDATE, offer_id, candidate_id,
			"upgrade candidate does not belong to offer"
		)
	var owned: Item = _validate_candidate(candidate)
	if owned == null:
		return _result_failure(
			token, UpgradeResult.Code.OWNERSHIP_CHANGED, offer_id, candidate_id,
			"upgrade candidate identity or revisions changed"
		)
	# Recheck immediately before mutation, not merely when the offer was built.
	if not bool(_progression.call("can_upgrade", owned)):
		return _result_failure(
			token, UpgradeResult.Code.LEVEL_CHANGED, offer_id, candidate_id,
			"upgrade target is no longer eligible"
		)
	var previous_level := int(_progression.call("level_of", owned))
	_settling = true
	var committed := bool(_progression.call("upgrade_one", owned))
	_settling = false
	if not committed:
		return _result_failure(
			token, UpgradeResult.Code.COMMIT_FAILED, offer_id, candidate_id,
			"upgrade commit failed"
		)
	_active.call("_consume")
	var result: UpgradeResult = UpgradeResultScript.new(
		token, UpgradeResult.Code.UPGRADED, offer_id, candidate_id, owned,
		previous_level, int(_progression.call("level_of", owned))
	)
	_active = null
	return result


func acknowledge_unavailable(token: RunFlowToken, offer_id: StringName) -> UpgradeResult:
	_error_detail = ""
	if not _valid_offer(token, offer_id, true):
		return null
	_active.call("_consume")
	_active = null
	return UpgradeResultScript.new(
		token, UpgradeResult.Code.UNAVAILABLE_ACKNOWLEDGED, offer_id
	)


func clear() -> bool:
	if _settling:
		return false
	_active = null
	return true


func _valid_offer(token: RunFlowToken, offer_id: StringName, unavailable: bool) -> bool:
	if _settling or _active == null or _active.consumed or _active.token == null \
			or token == null or not _active.token.matches(token) \
			or offer_id.is_empty() or offer_id != _active.offer_id:
		_error_detail = "upgrade offer identity is not active"
		return false
	if unavailable != _active.unavailable:
		_error_detail = "upgrade availability does not match command"
		return false
	return true


func _validate_candidate(candidate: UpgradeCandidate) -> Item:
	if int(_loadout.call("revision")) != candidate.loadout_revision \
			or int(_progression.call("revision")) != candidate.progression_revision:
		return null
	var owned: Item = _loadout.call("find_owned", candidate.item) as Item
	if owned == null or int(owned.get_instance_id()) != candidate.owned_instance_id \
			or _item_identity(owned) != candidate.item_identity \
			or int(_progression.call("level_of", owned)) != candidate.expected_level:
		return null
	return owned


func _result_failure(
	token: RunFlowToken,
	code: UpgradeResult.Code,
	offer_id: StringName,
	candidate_id: StringName,
	detail: String
) -> UpgradeResult:
	_error_detail = detail
	return UpgradeResultScript.new(token, code, offer_id, candidate_id, null, 0, 0, detail)


func _fail(detail: String) -> UpgradeOffer:
	_error_detail = detail
	_active = null
	return null


func _item_identity(item: Item) -> String:
	if item == null:
		return ""
	if item.type == Item.ItemType.MARBLE:
		return "type:%d:marble:%d" % [int(item.type), int(item.marble_type)]
	if not item.id.is_empty():
		return "type:%d:id:%s" % [int(item.type), item.id]
	return "type:%d:effect:%d" % [int(item.type), int(item.effect_type)]


func _has_api(value: Variant, methods: Array[StringName]) -> bool:
	if value == null:
		return false
	for method: StringName in methods:
		if not value.has_method(method):
			return false
	return true
