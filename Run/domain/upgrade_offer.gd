extends RefCounted
class_name UpgradeOffer

var token: RunFlowToken:
	get:
		return _token
var offer_id: StringName:
	get:
		return _offer_id
var loadout_revision: int:
	get:
		return _loadout_revision
var progression_revision: int:
	get:
		return _progression_revision
var unavailable: bool:
	get:
		return _candidates.is_empty()
var consumed: bool:
	get:
		return _consumed

var _token: RunFlowToken = null
var _offer_id: StringName = &""
var _loadout_revision: int = 0
var _progression_revision: int = 0
var _candidates: Array[UpgradeCandidate] = []
var _consumed: bool = false


func _init(
	value_token: RunFlowToken,
	value_offer_id: StringName,
	value_loadout_revision: int,
	value_progression_revision: int,
	value_candidates: Array[UpgradeCandidate]
) -> void:
	_token = value_token
	_offer_id = value_offer_id
	_loadout_revision = value_loadout_revision
	_progression_revision = value_progression_revision
	_candidates = value_candidates.duplicate()


func candidates() -> Array[UpgradeCandidate]:
	return _candidates.duplicate()


func candidate_by_id(candidate_id: StringName) -> UpgradeCandidate:
	for candidate: UpgradeCandidate in _candidates:
		if candidate != null and candidate.candidate_id == candidate_id:
			return candidate
	return null


func is_valid() -> bool:
	if _token == null or not _token.is_valid() or _offer_id.is_empty():
		return false
	var identities: Array[String] = []
	for candidate: UpgradeCandidate in _candidates:
		if candidate == null or not candidate.is_valid() \
				or identities.has(candidate.item_identity):
			return false
		identities.append(candidate.item_identity)
	return true


func _consume() -> void:
	_consumed = true
