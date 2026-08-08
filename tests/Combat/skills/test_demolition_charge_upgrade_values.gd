extends GutTest

## 升级数值：demolition_charge 的 CSV 行（生产 skill_level_values.csv）经
## Progression 返回 Lv 数值，SkillController 白名单写入 definition——Lv3 应为
## blast_radius=86、fuse_time=2.6、base_damage=24、recharge_time=4.0。

const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")
const SkillControllerScript: GDScript = preload("res://Combat/skills/skill_controller.gd")
const SkillItem: Resource = preload("res://Content/data/demolition_charge_skill.tres")


func after_each() -> void:
	Engine.time_scale = 1.0


func _item_at_level(level: int) -> Item:
	var item: Item = (SkillItem as Item).duplicate()
	return item


func test_progression_reports_skill_values_from_production_csv() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var item: Item = _item_at_level(1)
	assert_true(loadout.call("add", item))
	assert_true(progression.call("upgrade_one", item))  # Lv2
	assert_true(progression.call("upgrade_one", item))  # Lv3

	var values: Dictionary = progression.call("get_skill_values", "demolition_charge")
	assert_eq(values.get("recharge_time"), 4.0, "Lv3 recharge_time")
	assert_eq(values.get("base_damage"), 24, "Lv3 base_damage")
	assert_eq(values.get("blast_radius"), 86.0, "Lv3 blast_radius")
	assert_eq(values.get("fuse_time"), 2.6, "Lv3 fuse_time")


func test_skill_controller_writes_upgrade_values_onto_definition() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var item: Item = _item_at_level(1)
	assert_true(loadout.call("add", item))
	assert_true(progression.call("upgrade_one", item))  # Lv2
	assert_true(progression.call("upgrade_one", item))  # Lv3

	var controller: SkillController = SkillControllerScript.new()
	add_child_autofree(controller)
	assert_true(controller.configure(loadout, progression), "configure 成功")
	assert_true(controller.equip_skill(item), "装备技能")

	assert_almost_eq(controller.definition.blast_radius, 86.0, 0.0001, "Lv3 blast_radius 写入 definition")
	assert_almost_eq(controller.definition.fuse_time, 2.6, 0.0001, "Lv3 fuse_time 写入 definition")
	assert_eq(controller.definition.base_damage, 24, "Lv3 base_damage 写入 definition")
	assert_almost_eq(controller.definition.recharge_time, 4.0, 0.0001, "Lv3 recharge_time 写入 definition")


func test_definition_defaults_match_level_one_csv_row() -> void:
	# 定义 .tres 默认值 = CSV Lv1：装备前（未升级）数值一致。
	var definition: SkillDefinition = (SkillItem as Item).skill_definition
	assert_eq(definition.base_damage, 12)
	assert_almost_eq(definition.blast_radius, 70.0, 0.0001)
	assert_almost_eq(definition.fuse_time, 3.0, 0.0001)
	assert_almost_eq(definition.recharge_time, 6.0, 0.0001)
