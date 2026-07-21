extends RefCounted
class_name UpgradeCandidate

var candidate_id: StringName:
	get:
		return _candidate_id
var item: Item:
	get:
		return _item
var item_identity: String:
	get:
		return _item_identity
var owned_instance_id: int:
	get:
		return _owned_instance_id
var loadout_revision: int:
	get:
		return _loadout_revision
var progression_revision: int:
	get:
		return _progression_revision
var expected_level: int:
	get:
		return _expected_level

var _candidate_id: StringName = &""
var _item: Item = null
var _item_identity: String = ""
var _owned_instance_id: int = 0
var _loadout_revision: int = 0
var _progression_revision: int = 0
var _expected_level: int = 0


func _init(
	value_candidate_id: StringName,
	value_item: Item,
	value_item_identity: String,
	value_owned_instance_id: int,
	value_loadout_revision: int,
	value_progression_revision: int,
	value_expected_level: int
) -> void:
	_candidate_id = value_candidate_id
	_item = value_item
	_item_identity = value_item_identity
	_owned_instance_id = value_owned_instance_id
	_loadout_revision = value_loadout_revision
	_progression_revision = value_progression_revision
	_expected_level = value_expected_level


func is_valid() -> bool:
	return not _candidate_id.is_empty() and _item != null and not _item_identity.is_empty() \
		and _owned_instance_id != 0 and _expected_level > 0
