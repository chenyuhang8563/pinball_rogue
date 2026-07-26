extends GutTest


const MAIN_SCENE: PackedScene = preload("res://Game/Bootstrap/main.tscn")
const MAIN_MENU_SCENE: PackedScene = preload("res://UI/MainMenu/main_menu.tscn")
const LEVEL_SCENES: Array[PackedScene] = [
	preload("res://Combat/levels/level_001_weak.tscn"),
	preload("res://Combat/levels/level_strong_normal.tscn"),
	preload("res://Combat/levels/level_elite.tscn"),
	preload("res://Combat/levels/level_boss.tscn"),
]


# 固化 project.godot 使用的主场景 UID 可由当前导入缓存解析。
func test_main_scene_uid_resolves() -> void:
	var main_by_uid := ResourceLoader.load("uid://cbbk5l2e1na0y") as PackedScene

	assert_not_null(main_by_uid)
	if main_by_uid != null:
		assert_eq(main_by_uid.resource_path, "res://Game/Bootstrap/main.tscn")


# 固化迁移期间 Main 入口所依赖的静态场景节点。
func test_main_scene_exposes_required_composition_nodes() -> void:
	var main := MAIN_SCENE.instantiate()
	autofree(main)

	assert_not_null(main.get_node_or_null("Marbles"))
	assert_not_null(main.get_node_or_null("SkillController"))
	assert_not_null(main.get_node_or_null("CanvasLayer/SkillSlot"))
	assert_true(main.get_node_or_null("CanvasLayer/BattleHud") is BattleHud)
	assert_not_null(main.get_node_or_null("CanvasLayer/PausePanel"))
	assert_true(main.get_node_or_null("CanvasLayer/SettingsPanel") is SettingsPanel)
	assert_not_null(main.get_node_or_null("CanvasLayer/RunFailurePanel"))
	# Phase 7：固定运行 UI 由主场景预置，初始仅存在、不呈现。
	assert_true(main.get_node_or_null("CanvasLayer/NodeChoicePanel") is NodeChoicePanel)
	assert_true(main.get_node_or_null("CanvasLayer/DraftRewardPanel") is DraftRewardPanel)
	assert_true(main.get_node_or_null("CanvasLayer/RunEventPanel") is RunEventPanel)
	assert_true(main.get_node_or_null("CanvasLayer/DevilShop") is DevilShop)
	assert_true(main.get_node_or_null("InventoryPanel") is InventoryPanel)
	assert_not_null(main.get_node_or_null("Shop"))
	for path: NodePath in [
		^"CanvasLayer/NodeChoicePanel",
		^"CanvasLayer/DraftRewardPanel",
		^"CanvasLayer/RunEventPanel",
		^"CanvasLayer/DevilShop",
	]:
		assert_false((main.get_node(path) as CanvasItem).visible, "%s 应初始隐藏" % path)
	assert_not_null(main.get_node("Shop/UI") as CanvasLayer)
	assert_false((main.get_node("InventoryPanel/UI") as CanvasLayer).visible)
	assert_true(main.get_node_or_null("InventoryPanel/UI/SkillReplaceDialog") is SkillReplaceDialog)
	assert_not_null(main.get_node_or_null("DebugCanvasLayer/DebugGrantPanel"))
	assert_not_null(main.get_node_or_null("DebugCanvasLayer/DebugGrantPanel/VisibilityPlayer"))
	# Phase 6：Bootstrap 组合节点可视化预置于主场景，且脚本基类匹配。
	assert_true(main.get_node_or_null("BattleSpawner") is BattleSpawner)
	assert_true(main.get_node_or_null("Enemies") is Node2D)
	assert_true(main.get_node_or_null("BattleGateway") is BattleGateway)
	assert_true(main.get_node_or_null("RunFlowController") is RunFlowController)
	var shop_backdrop := main.get_node_or_null("Shop/UI/ShopBackdrop") as ColorRect
	assert_not_null(shop_backdrop)
	if shop_backdrop != null:
		assert_eq(shop_backdrop.color.a, 1.0)


func test_main_menu_keeps_continue_available_while_save_support_is_pending() -> void:
	var menu := MAIN_MENU_SCENE.instantiate()
	autofree(menu)
	assert_false((menu.get_node("ResumeButton") as Button).disabled)
	assert_true(menu.get_node_or_null("SettingsPanel") is SettingsPanel)


func test_phase7_font_sizes_fallbacks_and_black_style_contracts() -> void:
	var main := MAIN_SCENE.instantiate()
	autofree(main)
	var composite_10: Font = load("res://Themes/Fonts/quaver_fusion_10.tres") as Font
	var composite_12: Font = load("res://Themes/Fonts/quaver_fusion_12.tres") as Font

	var node_title := main.get_node(
		"CanvasLayer/NodeChoicePanel/Center/Panel/MarginContainer/Layout/TitleLabel"
	) as Label
	assert_eq(node_title.label_settings.font, composite_12)
	assert_eq(node_title.label_settings.font_size, 12)
	var inventory_title := main.get_node(
		"InventoryPanel/UI/Panel/MarginContainer/Layout/Header/TitleLabel"
	) as Label
	var skill_title := main.get_node(
		"InventoryPanel/UI/Panel/MarginContainer/Layout/Content/SkillLabel"
	) as Label
	assert_eq(inventory_title.label_settings.font, composite_12)
	assert_eq(skill_title.label_settings.font, composite_12)
	var relic_selection_hint := main.get_node(
		"InventoryPanel/UI/Panel/MarginContainer/Layout/RelicSelectionHint"
	) as Label
	assert_eq(relic_selection_hint.label_settings.font, composite_12)
	var relic_selection_player := main.get_node("InventoryPanel/RelicSelectionModePlayer") as AnimationPlayer
	assert_not_null(relic_selection_player)
	if relic_selection_player != null:
		assert_true(relic_selection_player.has_animation(&"normal"))
		assert_true(relic_selection_player.has_animation(&"relic_selection"))

	var charge := main.get_node("CanvasLayer/SkillSlot/ChargeLabel") as Label
	assert_eq(charge.label_settings.font, composite_10)
	assert_eq(charge.label_settings.font_size, 10)
	var devil_reward := main.get_node("CanvasLayer/DevilShop/BottomHUD/ConfirmButton") as Button
	assert_eq(devil_reward.get_theme_font_size(&"font_size"), 10, "Devil reward button uses the approved 10px composite font")
	assert_eq(devil_reward.get_theme_font(&"font"), composite_10)

	var event_button := main.get_node(
		"CanvasLayer/RunEventPanel/Center/Panel/MarginContainer/Layout/DiceChoiceRow/SmallWagerButton"
	) as Button
	assert_false(event_button.has_theme_stylebox_override(&"normal"), "事件按钮应使用普通黑色主题")
	var replace_panel := main.get_node(
		"InventoryPanel/UI/SkillReplaceDialog/Center/Panel"
	) as PanelContainer
	assert_false(replace_panel.has_theme_stylebox_override(&"panel"), "升级窗口不保留蓝框")


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
