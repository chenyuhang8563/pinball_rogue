extends GutTest

const StoreScript: GDScript = preload("res://Run/save/run_save_repository.gd")
const SaveDataScript: GDScript = preload("res://Run/save/run_save_data.gd")

var _save_path: String = "user://saves/test_run_save_repository.tres"
var _store: RunSaveStore = null


func before_each() -> void:
	_store = autofree(StoreScript.new()) as RunSaveStore
	_store.set_paths_for_test(_save_path)
	_store.set_content_registry_for_test(get_tree().root.get_node_or_null(^"ContentRegistry"))
	_store.delete_save()


func after_each() -> void:
	if _store != null:
		_store.delete_save()


func test_disk_round_trip_atomic_replace_and_backup_recovery() -> void:
	var first := _checkpoint(100)
	var second := _checkpoint(250)
	assert_true(_store.write_checkpoint(first))
	assert_eq(_store.load_save().checkpoint[&"scope"][&"gold"], 100)
	assert_true(_store.write_checkpoint(second))
	assert_eq(_store.load_save().checkpoint[&"scope"][&"gold"], 250)

	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string("this is not a Godot resource")
	file = null
	var recovered := _store.load_save()
	assert_not_null(recovered, "主文件损坏时应读取上一份原子备份")
	assert_eq(recovered.checkpoint[&"scope"][&"gold"], 100)


func test_corruption_unknown_schema_and_missing_content_disable_continue() -> void:
	var invalid_version := SaveDataScript.new() as RunSaveData
	invalid_version.schema_version = 99
	invalid_version.saved_at_unix = 1
	invalid_version.checkpoint = _checkpoint(10)
	assert_eq(ResourceSaver.save(invalid_version, _save_path), OK)
	assert_false(_store.has_valid_save())

	_store.delete_save()
	var missing := _checkpoint(10)
	missing[&"content_ids"] = [&"content_that_does_not_exist"]
	assert_false(_store.write_checkpoint(missing))
	assert_false(_store.has_valid_save())


func test_start_intent_is_one_shot_and_new_game_delete_removes_all_files() -> void:
	assert_true(_store.write_checkpoint(_checkpoint(30)))
	assert_true(_store.request_continue_run())
	assert_eq(_store.consume_start_intent(), RunSaveStore.StartIntent.CONTINUE_RUN)
	assert_eq(_store.consume_start_intent(), RunSaveStore.StartIntent.NONE)
	_store.request_new_run()
	assert_eq(_store.consume_start_intent(), RunSaveStore.StartIntent.NEW_RUN)
	_store.delete_save()
	assert_false(_store.has_valid_save())
	var base_path := _save_path.trim_suffix(".tres")
	assert_false(FileAccess.file_exists(base_path + ".tmp.tres"))
	assert_false(FileAccess.file_exists(base_path + ".bak.tres"))


func _checkpoint(gold: int) -> Dictionary:
	return {
		&"scope": {&"gold": gold},
		&"random": {&"state": 123},
		&"flow": {&"state": {}, &"payload": {}},
		&"content_ids": [&"dark_marble"],
	}
