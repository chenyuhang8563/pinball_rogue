extends Node

const DEFAULT_CONTENT_ROOT: String = "res://Content/data"

var _items: Array[Item] = []
var _items_by_id: Dictionary[StringName, Item] = {}
var _valid: bool = false
var _content_root: String = DEFAULT_CONTENT_ROOT


func _ready() -> void:
	rebuild()


func is_valid() -> bool:
	return _valid


func all_items() -> Array[Item]:
	return _items.duplicate()


func by_id(item_id: StringName) -> Item:
	return _items_by_id.get(item_id) as Item


func query(type: Item.ItemType, rarity: int = -1, tags: Array[StringName] = [], exclude_tags: Array[StringName] = [&"starting"]) -> Array[Item]:
	var result: Array[Item] = []
	for item: Item in _items:
		if item.type != type or (rarity >= 0 and int(item.rarity) != rarity):
			continue
		if not _has_all_tags(item.tags, tags) or _has_any_tag(item.tags, exclude_tags):
			continue
		result.append(item)
	return result


func weighted_pick(pool: Array[Item], random_source: RunRandomSource) -> Item:
	if random_source == null:
		return null
	var weights := PackedFloat64Array()
	for item: Item in pool:
		weights.append(maxf(0.0, item.weight) if item != null else 0.0)
	var index: int = random_source.weighted_index_float(weights)
	return pool[index] if index >= 0 and index < pool.size() else null


## Rebuilds from a sorted path list so identical content produces identical
## registry order on every platform. Item ids are the stable public key.
func rebuild(content_root: String = DEFAULT_CONTENT_ROOT) -> Error:
	_content_root = content_root.simplify_path()
	_items.clear()
	_items_by_id.clear()
	_valid = true
	var paths: PackedStringArray = []
	_collect_tres_paths(_content_root, paths)
	paths.sort()
	for path: String in paths:
		var item := load(path) as Item
		if item == null:
			continue
		var item_id := StringName(item.id.strip_edges())
		if item_id.is_empty() or _items_by_id.has(item_id):
			push_error("Missing or duplicate content item id at %s" % path)
			_valid = false
			continue
		# Negative weights remain authored data, but every local draw treats them
		# as zero so a malformed weight cannot invalidate unrelated content.
		_items.append(item)
		_items_by_id[item_id] = item
	return OK if _valid else FAILED


func _rebuild() -> Error:
	return rebuild(_content_root)


func _collect_tres_paths(path: String, paths: PackedStringArray) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if not name.begins_with("."):
			var child := path.path_join(name)
			if directory.current_is_dir():
				_collect_tres_paths(child, paths)
			elif name.ends_with(".tres"):
				paths.append(child)
		name = directory.get_next()
	directory.list_dir_end()


func _has_all_tags(item_tags: Array[StringName], required: Array[StringName]) -> bool:
	for tag: StringName in required:
		if not item_tags.has(tag):
			return false
	return true


func _has_any_tag(item_tags: Array[StringName], forbidden: Array[StringName]) -> bool:
	for tag: StringName in forbidden:
		if item_tags.has(tag):
			return true
	return false
