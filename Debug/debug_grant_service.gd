class_name DebugGrantService
extends RefCounted

const RewardTransactionScript: GDScript = preload("res://Run/domain/reward_transaction.gd")

enum Result {
	GRANTED,
	UNKNOWN_ID,
	DUPLICATE,
	CAPACITY_REACHED,
	COMMIT_FAILED,
}

const ITEM_PATHS: PackedStringArray = [
	"res://Resources/dark_marble.tres",
	"res://Resources/brown_marble.tres",
	"res://Resources/bomb_marble.tres",
	"res://Resources/green_marble.tres",
	"res://Resources/blue_marble.tres",
	"res://Resources/fire_marble.tres",
	"res://Resources/lightning.tres",
	"res://Resources/fire_bellows.tres",
	"res://Resources/poison_culture.tres",
	"res://Resources/ice_hammer.tres",
	"res://Resources/dash_skill.tres",
	"res://Resources/magic_missile_skill.tres",
]

var _loadout: RefCounted = null
var _progression: RefCounted = null
var _items_by_id: Dictionary[StringName, Item] = {}


func configure(loadout: RefCounted, progression: RefCounted) -> bool:
	if loadout == null or progression == null:
		return false
	_loadout = loadout
	_progression = progression
	_items_by_id.clear()
	for path: String in ITEM_PATHS:
		var item := load(path) as Item
		if item != null and not item.id.is_empty():
			_items_by_id[item.id] = item
	return not _items_by_id.is_empty()


func item_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for id: StringName in _items_by_id:
		ids.append(String(id))
	ids.sort()
	return ids


func grant(item_id: StringName) -> Result:
	var item: Item = _items_by_id.get(item_id) as Item
	if item == null:
		return Result.UNKNOWN_ID
	if _loadout == null or _progression == null:
		return Result.COMMIT_FAILED
	if _loadout.call("find_owned", item) != null:
		return Result.DUPLICATE
	if item.type != Item.ItemType.SKILL:
		return Result.GRANTED if bool(_loadout.call("add", item)) else Result.CAPACITY_REACHED
	var previous_skill := _loadout.call("current_skill") as Item
	if previous_skill == null:
		return Result.GRANTED if bool(_loadout.call("add", item)) else Result.CAPACITY_REACHED
	var transaction: RefCounted = RewardTransactionScript.new([_loadout, _progression])
	var steps: Array[Callable] = [
		Callable(_loadout, "replace_skill").bind(item),
		Callable(_progression, "reset_skill").bind(previous_skill.id),
	]
	return Result.GRANTED if bool(transaction.call("execute", steps)) else Result.COMMIT_FAILED
