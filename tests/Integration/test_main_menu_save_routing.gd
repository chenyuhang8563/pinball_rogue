extends GutTest

const MainMenuScene: PackedScene = preload("res://UI/MainMenu/main_menu.tscn")
const MainScene: PackedScene = preload("res://Game/Bootstrap/main.tscn")
const TEST_SAVE_PATH: String = "user://saves/test_main_menu_save.tres"

var _repository: Node = null


func before_each() -> void:
	_repository = get_tree().root.get_node_or_null(^"RunSaveRepository")
	_repository.call("set_paths_for_test", TEST_SAVE_PATH)
	_repository.call("delete_save")


func after_each() -> void:
	_repository.call("delete_save")
	_repository.call("reset_paths")


func test_continue_button_state_and_one_shot_routes_follow_valid_save() -> void:
	var without_save := add_child_autofree(MainMenuScene.instantiate()) as Control
	assert_true((without_save.get_node("ResumeButton") as Button).disabled)
	remove_child(without_save)
	without_save.free()

	assert_true(_repository.call("write_checkpoint", {
		&"scope": {&"gold": 100},
		&"random": {&"state": 1},
		&"flow": {&"state": {}, &"payload": {}},
		&"content_ids": [&"dark_marble"],
	}))
	var with_save := add_child_autofree(MainMenuScene.instantiate()) as Control
	assert_false((with_save.get_node("ResumeButton") as Button).disabled)
	assert_true(with_save.call("_prepare_continue_run"))
	assert_eq(_repository.call("consume_start_intent"), RunSaveStore.StartIntent.CONTINUE_RUN)
	assert_true(with_save.call("_prepare_new_run"))
	assert_eq(_repository.call("consume_start_intent"), RunSaveStore.StartIntent.NEW_RUN)
	assert_false(_repository.call("has_valid_save"), "新游戏路由必须先删除旧单槽")


func test_failed_and_completed_handlers_delete_in_progress_save_immediately() -> void:
	var main: Node = autofree(MainScene.instantiate())
	assert_true(_repository.call("write_checkpoint", _checkpoint()))
	main.call("_on_run_completed", null)
	assert_false(_repository.call("has_valid_save"))
	assert_true(_repository.call("write_checkpoint", _checkpoint()))
	main.call("_on_run_failed", null, &"test")
	assert_false(_repository.call("has_valid_save"))


func _checkpoint() -> Dictionary:
	return {
		&"scope": {&"gold": 100},
		&"random": {&"state": 1},
		&"flow": {&"state": {}, &"payload": {}},
		&"content_ids": [&"dark_marble"],
	}
