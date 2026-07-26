extends Node
class_name RunSaveStore

enum StartIntent {
	NONE,
	NEW_RUN,
	CONTINUE_RUN,
}

const RunSaveDataScript: GDScript = preload("res://Run/save/run_save_data.gd")
const DEFAULT_SAVE_PATH: String = "user://saves/run_save.tres"

var _save_path: String = DEFAULT_SAVE_PATH
var _temporary_path: String = "user://saves/run_save.tmp.tres"
var _backup_path: String = "user://saves/run_save.bak.tres"
var _start_intent: StartIntent = StartIntent.NONE
var _content_registry_override: Node = null


func has_valid_save() -> bool:
	return load_save() != null


func load_save() -> RunSaveData:
	var primary := _load_valid(_save_path)
	if primary != null:
		return primary
	return _load_valid(_backup_path)


func write_checkpoint(checkpoint: Dictionary) -> bool:
	var data := RunSaveDataScript.new() as RunSaveData
	data.saved_at_unix = int(Time.get_unix_time_from_system())
	data.checkpoint = checkpoint.duplicate(true)
	if not _validate(data):
		return false
	var directory := _save_path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK:
		return false
	_remove_if_exists(_temporary_path)
	if ResourceSaver.save(data, _temporary_path) != OK:
		_remove_if_exists(_temporary_path)
		return false
	var loaded_temporary := _load_valid(_temporary_path)
	if loaded_temporary == null:
		_remove_if_exists(_temporary_path)
		return false
	_remove_if_exists(_backup_path)
	if FileAccess.file_exists(_save_path):
		if not _rename(_save_path, _backup_path):
			_remove_if_exists(_temporary_path)
			return false
	if not _rename(_temporary_path, _save_path):
		if FileAccess.file_exists(_backup_path):
			_rename(_backup_path, _save_path)
		_remove_if_exists(_temporary_path)
		return false
	return true


func delete_save() -> void:
	_remove_if_exists(_temporary_path)
	_remove_if_exists(_backup_path)
	_remove_if_exists(_save_path)


func request_new_run() -> void:
	_start_intent = StartIntent.NEW_RUN


func request_continue_run() -> bool:
	if not has_valid_save():
		return false
	_start_intent = StartIntent.CONTINUE_RUN
	return true


func consume_start_intent() -> StartIntent:
	var result := _start_intent
	_start_intent = StartIntent.NONE
	return result


func set_paths_for_test(save_path: String) -> void:
	_save_path = save_path
	var base_path := save_path.trim_suffix(".tres")
	_temporary_path = base_path + ".tmp.tres"
	_backup_path = base_path + ".bak.tres"


func reset_paths() -> void:
	_save_path = DEFAULT_SAVE_PATH
	_temporary_path = "user://saves/run_save.tmp.tres"
	_backup_path = "user://saves/run_save.bak.tres"


func set_content_registry_for_test(registry: Node) -> void:
	_content_registry_override = registry


func _load_valid(path: String) -> RunSaveData:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or not file.get_line().strip_edges().begins_with("[gd_resource"):
		return null
	file = null
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as RunSaveData
	return loaded if _validate(loaded) else null


func _validate(data: RunSaveData) -> bool:
	if data == null or not data.is_structurally_valid():
		return false
	var registry := _content_registry()
	if registry == null or not registry.has_method(&"by_id"):
		return false
	var seen: Dictionary[StringName, bool] = {}
	for value: Variant in data.checkpoint[&"content_ids"] as Array:
		var item_id := StringName(value)
		if item_id.is_empty() or seen.has(item_id) or registry.call(&"by_id", item_id) == null:
			return false
		seen[item_id] = true
	return not seen.is_empty()


func _content_registry() -> Node:
	if _content_registry_override != null and is_instance_valid(_content_registry_override):
		return _content_registry_override
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(^"ContentRegistry") if tree != null else null


func _rename(from_path: String, to_path: String) -> bool:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(from_path),
		ProjectSettings.globalize_path(to_path)
	) == OK


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
