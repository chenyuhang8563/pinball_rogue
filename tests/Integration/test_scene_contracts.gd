extends GutTest


const MAIN_SCENE: PackedScene = preload("res://Main/main.tscn")
const LEVEL_SCENES: Array[PackedScene] = [
	preload("res://Levels/level_001_weak.tscn"),
	preload("res://Levels/level_strong_normal.tscn"),
	preload("res://Levels/level_elite.tscn"),
	preload("res://Levels/level_boss.tscn"),
]


# 固化 project.godot 使用的主场景 UID 可由当前导入缓存解析。
func test_main_scene_uid_resolves() -> void:
	var main_by_uid := ResourceLoader.load("uid://cbbk5l2e1na0y") as PackedScene

	assert_not_null(main_by_uid)
	if main_by_uid != null:
		assert_eq(main_by_uid.resource_path, "res://Main/main.tscn")


# 固化迁移期间 Main 入口所依赖的静态场景节点。
func test_main_scene_exposes_required_composition_nodes() -> void:
	var main := MAIN_SCENE.instantiate()
	autofree(main)

	assert_not_null(main.get_node_or_null("Marbles"))
	assert_not_null(main.get_node_or_null("SkillController"))
	assert_not_null(main.get_node_or_null("CanvasLayer/SkillSlot"))
	assert_not_null(main.get_node_or_null("CanvasLayer/BattleHealthHud"))
	assert_not_null(main.get_node_or_null("CanvasLayer/PausePanel"))
	assert_not_null(main.get_node_or_null("CanvasLayer/RunFailurePanel"))
	# Phase 6：Bootstrap 组合节点可视化预置于主场景，且脚本基类匹配。
	assert_true(main.get_node_or_null("BattleSpawner") is BattleSpawner)
	assert_true(main.get_node_or_null("Enemies") is Node2D)
	assert_true(main.get_node_or_null("BattleGateway") is BattleGateway)
	assert_true(main.get_node_or_null("RunFlowController") is RunFlowController)


# 固化关卡读取与战斗实例化共同依赖的容器命名。
func test_level_scenes_expose_spawn_and_enemy_containers() -> void:
	for level_scene in LEVEL_SCENES:
		var level := level_scene.instantiate()
		autofree(level)
		var spawn_container := level.get_node_or_null("EnemySpawns")
		var enemy_container := level.get_node_or_null("Enemies")

		assert_not_null(spawn_container, "%s 缺少 EnemySpawns" % level_scene.resource_path)
		assert_not_null(enemy_container, "%s 缺少 Enemies" % level_scene.resource_path)
		if spawn_container == null or enemy_container == null:
			continue
		assert_true(enemy_container is Node2D, "%s 的 Enemies 必须是 Node2D" % level_scene.resource_path)
		assert_true(spawn_container.get_child_count() > 0)
		for spawn in spawn_container.get_children():
			assert_true(spawn is LevelEnemySpawn)
