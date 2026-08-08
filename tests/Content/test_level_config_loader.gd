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

	# 结构不变式（不绑定具体数值/行数）：每个弹珠每个 stat 的档位合法且按
	# min_level 严格递增。调整平衡数值（marble_level_modifiers.csv 增删行/改值）
	# 不应破坏本测试。
	for stats_by_id: Dictionary in marble_modifiers.values():
		assert_false(stats_by_id.is_empty(), "每种弹珠至少配置一个 stat")
		for stat_id: Variant in stats_by_id:
			var rows: Array = stats_by_id[stat_id]
			assert_true(rows.size() >= 1, "每个 stat 至少一档")
			assert_true(rows.size() <= 4, "每个 stat 至多 4 档（min_level 1..4）")
			var last_min_level := 0
			for row: Dictionary in rows:
				var min_level := int(row.get("min_level", 0))
				assert_true(min_level >= 1 and min_level <= 4, "min_level 必须在 1..4")
				assert_true(min_level > last_min_level, "同 stat 档位严格递增")
				last_min_level = min_level

	var by_id: Dictionary = LevelConfigLoaderScript.MARBLE_TYPE_BY_ITEM_ID
	# dark 伤害曲线逐级有档（结构保证，数值自由）。
	var dark_rows: Array = marble_modifiers[by_id["dark_marble"]]["dark_marble_damage"]
	assert_eq(dark_rows.size(), 4, "dark_marble 伤害曲线 4 档完整")
	for level: int in range(4):
		assert_eq(int((dark_rows[level] as Dictionary)["min_level"]), level + 1,
			"dark_marble 伤害逐级有档")

	assert_eq(skill_level_values["dash"].size(), 4)
	assert_eq(skill_level_values["magic_missile"].size(), 4)
	assert_eq(skill_level_values["demolition_charge"].size(), 4)
	# demolition_charge 字段结构（表头契约，数值自由）。
	var demo_lv1: Dictionary = skill_level_values["demolition_charge"][0]
	assert_true(demo_lv1.has("recharge_time"))
	assert_true(demo_lv1.has("base_damage"))
	assert_true(demo_lv1.has("blast_radius"))
	assert_true(demo_lv1.has("fuse_time"))
	assert_false(demo_lv1.has("projectile_lifetime"), "demolition_charge 无 projectile_lifetime 字段")
	assert_false(demo_lv1.has("dash_damage_multiplier"), "demolition_charge 无 dash 字段")
	assert_true(skill_level_values["demolition_charge"][0]["base_damage"] is int, "base_damage 是 int")
	# dash 字段结构（表头契约，数值自由）。
	var dash_lv1: Dictionary = skill_level_values["dash"][0]
	assert_true(dash_lv1.has("recharge_time"))
	assert_true(dash_lv1.has("dash_damage_multiplier"))
	assert_true(dash_lv1.has("dash_damage_duration"),
		"dash_damage_duration=0.0 是字面值，必须保留（0.0 不等于空字段）")
	assert_false(dash_lv1.has("base_damage"), "dash 无 base_damage 字段")
	assert_false(dash_lv1.has("projectile_lifetime"), "dash 无 projectile_lifetime 字段")
	# magic_missile 字段结构 + 类型契约。
	var missile_lv4: Dictionary = skill_level_values["magic_missile"][3]
	assert_true(missile_lv4.has("recharge_time"))
	assert_true(missile_lv4.has("base_damage"))
	assert_true(missile_lv4.has("projectile_lifetime"))
	assert_true(skill_level_values["magic_missile"][0]["base_damage"] is int, "base_damage 是 int")


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
