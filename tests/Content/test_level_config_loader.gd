extends GutTest

const LevelConfigLoaderScript: GDScript = preload("res://Content/application/level_config_loader.gd")
const FIXTURE_ROOT: String = "res://tests/Content/fixtures/level_config/"


func test_default_loads_full_production_data() -> void:
	var result: Dictionary = LevelConfigLoaderScript.load_config()
	assert_true(bool(result.get(&"ok", false)), "生产 CSV 应加载成功")
	var config: Dictionary = result[&"config"] as Dictionary
	var marble_modifiers: Dictionary = config[&"marble_modifiers"] as Dictionary
	var skill_level_values: Dictionary = config[&"skill_level_values"] as Dictionary

	assert_eq(marble_modifiers.size(), 8, "8 种弹珠")
	assert_eq(skill_level_values.size(), 3, "3 个技能")

	var total_rows := 0
	for stats_by_id: Dictionary in marble_modifiers.values():
		for stat_id: Variant in stats_by_id:
			total_rows += (stats_by_id[stat_id] as Array).size()
	assert_eq(total_rows, 37, "marble CSV 共 37 行数据")

	var by_id: Dictionary = LevelConfigLoaderScript.MARBLE_TYPE_BY_ITEM_ID
	assert_eq(marble_modifiers[by_id["dark_marble"]]["dark_marble_damage"], [
		{"min_level": 1, "value": 1.0},
		{"min_level": 2, "value": 2.0},
		{"min_level": 3, "value": 3.0},
		{"min_level": 4, "value": 4.0},
	])
	assert_eq(marble_modifiers[by_id["bomb_marble"]]["explosion_radius"],
		[{"min_level": 4, "value": 75.0}])
	assert_eq(marble_modifiers[by_id["lightning_marble"]]["lightning_repeat_arc_stacks"],
		[{"min_level": 4, "value": 2.0}])

	assert_eq(skill_level_values["dash"].size(), 4)
	assert_eq(skill_level_values["magic_missile"].size(), 4)
	assert_eq(skill_level_values["demolition_charge"].size(), 4)
	assert_eq(skill_level_values["demolition_charge"][0], {
		"recharge_time": 6.0,
		"base_damage": 12,
		"blast_radius": 70.0,
		"fuse_time": 3.0,
	})
	assert_eq(skill_level_values["dash"][0], {
		"recharge_time": 5.0,
		"dash_damage_multiplier": 1.0,
		"dash_damage_duration": 0.0,
	})
	assert_eq(skill_level_values["magic_missile"][3], {
		"recharge_time": 2.5,
		"base_damage": 24,
		"projectile_lifetime": 6.0,
	})
	# base_damage 是 int；dash 的空字段不存在；0.0 是有效值必须保留。
	assert_true(skill_level_values["magic_missile"][0]["base_damage"] is int)
	assert_false(skill_level_values["dash"][0].has("base_damage"))
	assert_false(skill_level_values["dash"][0].has("projectile_lifetime"))
	assert_eq(skill_level_values["dash"][0]["dash_damage_duration"], 0.0)


func test_valid_fixtures_load_clean() -> void:
	var result: Dictionary = LevelConfigLoaderScript.load_config(
		FIXTURE_ROOT + "valid_marbles.csv", FIXTURE_ROOT + "valid_skills.csv")
	assert_true(bool(result.get(&"ok", false)), "合法 fixture 应成功")
	var config: Dictionary = result[&"config"] as Dictionary
	var marble_modifiers: Dictionary = config[&"marble_modifiers"] as Dictionary
	var skill_level_values: Dictionary = config[&"skill_level_values"] as Dictionary
	assert_eq(marble_modifiers.size(), 8)
	assert_eq(skill_level_values.size(), 3)
	assert_true((result.get(&"errors", PackedStringArray()) as PackedStringArray).is_empty())


func test_marble_rows_sorted_by_min_level() -> void:
	var result: Dictionary = LevelConfigLoaderScript.load_config(
		FIXTURE_ROOT + "valid_marbles.csv", FIXTURE_ROOT + "valid_skills.csv")
	var config: Dictionary = result[&"config"] as Dictionary
	var marble_modifiers: Dictionary = config[&"marble_modifiers"] as Dictionary
	var by_id: Dictionary = LevelConfigLoaderScript.MARBLE_TYPE_BY_ITEM_ID
	var dark_rows: Array = marble_modifiers[by_id["dark_marble"]]["dark_marble_damage"]
	assert_eq(int((dark_rows[0] as Dictionary)["min_level"]), 1)
	assert_eq(int((dark_rows[1] as Dictionary)["min_level"]), 2)


func test_bom_and_crlf_fixture_loads_clean() -> void:
	var result: Dictionary = LevelConfigLoaderScript.load_config(
		FIXTURE_ROOT + "bom_crlf_marbles.csv", FIXTURE_ROOT + "valid_skills.csv")
	assert_true(bool(result.get(&"ok", false)), "BOM + CRLF 应剥离并解析成功")
	var config: Dictionary = result[&"config"] as Dictionary
	var marble_modifiers: Dictionary = config[&"marble_modifiers"] as Dictionary
	assert_eq(marble_modifiers.size(), 8)


func test_quoted_cells_and_empty_cells_parse() -> void:
	var result: Dictionary = LevelConfigLoaderScript.load_config(
		FIXTURE_ROOT + "valid_marbles.csv", FIXTURE_ROOT + "quoted_skills.csv")
	assert_true(bool(result.get(&"ok", false)), "引号单元格应解析成功")
	var config: Dictionary = result[&"config"] as Dictionary
	var skill_level_values: Dictionary = config[&"skill_level_values"] as Dictionary
	var dash_level_one: Dictionary = (skill_level_values["dash"][0] as Dictionary)
	assert_eq(dash_level_one.get("recharge_time"), 5.0)
	# 引号空单元格 "" 视为字段不存在。
	assert_false(dash_level_one.has("base_damage"))
	# 引号包裹的 "4.0" 正常解析。
	assert_eq((skill_level_values["magic_missile"][0] as Dictionary).get("projectile_lifetime"), 4.0)
	assert_eq(skill_level_values["dash"].size(), 4)


func test_bad_marble_rows_report_path_and_line_and_fail_atomically() -> void:
	var result: Dictionary = LevelConfigLoaderScript.load_config(
		FIXTURE_ROOT + "bad_marbles.csv", FIXTURE_ROOT + "valid_skills.csv")
	assert_false(bool(result.get(&"ok", false)))
	assert_true((result[&"config"] as Dictionary).is_empty(), "原子失败：两个 config 均不交付")
	var errors: PackedStringArray = result[&"errors"] as PackedStringArray
	assert_true(errors.size() > 0)
	assert_true(_any_error_contains(errors, "bad_marbles.csv:3"), "未知 id 报路径+行号")
	assert_true(_any_error_contains(errors, "bad_marbles.csv:4"), "非法等级报路径+行号")
	assert_true(_any_error_contains(errors, "bad_marbles.csv:5"), "非法数值报路径+行号")
	assert_true(_any_error_contains(errors, "bad_marbles.csv:7"), "重复行报路径+行号")
	assert_true(_any_error_contains(errors, "marble 'brown_marble' has no min_level=1 row"),
		"已知弹珠缺 Lv1 行")


func test_bad_skill_rows_report_path_and_line() -> void:
	var result: Dictionary = LevelConfigLoaderScript.load_config(
		FIXTURE_ROOT + "valid_marbles.csv", FIXTURE_ROOT + "bad_skills.csv")
	assert_false(bool(result.get(&"ok", false)))
	assert_true((result[&"config"] as Dictionary).is_empty())
	var errors: PackedStringArray = result[&"errors"] as PackedStringArray
	assert_true(_any_error_contains(errors, "bad_skills.csv:5"), "重复等级报路径+行号")
	assert_true(_any_error_contains(errors, "bad_skills.csv:7"), "未知 skill id 报路径+行号")
	assert_true(_any_error_contains(errors, "bad_skills.csv:8"), "非法 base_damage 报路径+行号")
	assert_true(_any_error_contains(errors, "skill 'magic_missile' missing level 1"),
		"被拒行导致技能缺级")


func test_wrong_header_rejected() -> void:
	var result: Dictionary = LevelConfigLoaderScript.load_config(
		FIXTURE_ROOT + "valid_marbles.csv", FIXTURE_ROOT + "wrong_header_skills.csv")
	assert_false(bool(result.get(&"ok", false)))
	var errors: PackedStringArray = result[&"errors"] as PackedStringArray
	assert_true(_any_error_contains(errors, "wrong_header_skills.csv:1"))
	assert_true(_any_error_contains(errors, "skill header mismatch"))


func test_missing_files_report_open_error() -> void:
	var result: Dictionary = LevelConfigLoaderScript.load_config(
		"res://tests/Content/fixtures/level_config/does_not_exist_marbles.csv",
		"res://tests/Content/fixtures/level_config/does_not_exist_skills.csv")
	assert_false(bool(result.get(&"ok", false)))
	var errors: PackedStringArray = result[&"errors"] as PackedStringArray
	assert_true(_any_error_contains(errors, "Cannot open"))
	assert_eq(errors.size(), 2, "两个文件都报 open error")


func test_atomic_failure_returns_no_partial_config_even_with_one_good_file() -> void:
	var result: Dictionary = LevelConfigLoaderScript.load_config(
		FIXTURE_ROOT + "bad_marbles.csv", FIXTURE_ROOT + "valid_skills.csv")
	assert_false(bool(result.get(&"ok", false)))
	assert_true((result[&"config"] as Dictionary).is_empty(),
		"弹珠文件坏、技能文件好时也不交付部分数据")


func _any_error_contains(errors: PackedStringArray, needle: String) -> bool:
	for message: String in errors:
		if message.contains(needle):
			return true
	return false
