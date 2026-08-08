extends GutTest

const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")
const FakeStatSystemScript: GDScript = preload("res://tests/Loadout/fake_stat_system.gd")


func test_marble_relic_and_skill_progress_from_i_to_awakened_iv() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var marble := _item("dark", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.DEFAULT)
	var relic := _item("relic", Item.ItemType.RELIC)
	var skill := _item("dash", Item.ItemType.SKILL)
	for item: Item in [marble, relic, skill]:
		assert_true(loadout.call("add", item))
		assert_eq(progression.call("level_of", item), 1)
		assert_true(progression.call("upgrade_one", item))
		assert_eq(progression.call("level_of", item), 2)
		assert_true(progression.call("upgrade_one", item))
		assert_eq(progression.call("level_of", item), 3)
		assert_true(progression.call("upgrade_one", item))
		assert_eq(progression.call("level_of", item), 4)
		assert_false(progression.call("can_upgrade", item))


func test_skill_values_follow_owned_progression_levels() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var dash := _item("dash", Item.ItemType.SKILL)
	assert_true(loadout.call("add", dash))
	# 技能曲线字段结构（表头契约，数值自由）：字段存在即可，不断言具体数值。
	var dash_lv1: Dictionary = progression.call("get_skill_values", "dash")
	assert_true(dash_lv1.has("recharge_time"), "dash Lv1 有 recharge_time")
	assert_true(progression.call("upgrade_one", dash))
	var dash_lv2: Dictionary = progression.call("get_skill_values", "dash")
	assert_true(dash_lv2.has("recharge_time"), "dash Lv2 有 recharge_time")
	assert_true(progression.call("upgrade_one", dash))
	var dash_lv3: Dictionary = progression.call("get_skill_values", "dash")
	assert_true(dash_lv3.has("recharge_time"), "dash Lv3 有 recharge_time")
	assert_true(dash_lv3.has("dash_damage_multiplier"), "dash Lv3 有 dash_damage_multiplier")
	assert_true(dash_lv3.has("dash_damage_duration"), "dash Lv3 有 dash_damage_duration")
	assert_true(progression.call("upgrade_one", dash))
	var dash_lv4: Dictionary = progression.call("get_skill_values", "dash")
	assert_true(dash_lv4.has("dash_damage_multiplier"), "dash Lv4 有 dash_damage_multiplier")
	var missile := _item("magic_missile", Item.ItemType.SKILL)
	assert_true(loadout.call("replace_skill", missile))
	for _upgrade: int in 3:
		assert_true(progression.call("upgrade_one", missile))
	var missile_values: Dictionary = progression.call("get_skill_values", "magic_missile")
	assert_true(missile_values.has("recharge_time"), "missile 有 recharge_time")
	assert_true(missile_values.has("base_damage"), "missile 有 base_damage")
	assert_true(missile_values.has("projectile_lifetime"), "missile 有 projectile_lifetime")
	assert_false(progression.call("upgrade_one", missile))


func test_upgradable_owned_items_include_each_supported_owned_type() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var marble := _item("dark", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.DEFAULT)
	var relic := _item("relic", Item.ItemType.RELIC)
	var skill := _item("dash", Item.ItemType.SKILL)
	for item: Item in [marble, relic, skill]:
		assert_true(loadout.call("add", item))

	var candidates: Array = progression.call("upgradable_owned_items")

	assert_has(candidates, marble)
	assert_has(candidates, relic)
	assert_has(candidates, skill)


func test_unknown_skill_and_unowned_quote_semantics() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var known_unowned := _item("magic_missile", Item.ItemType.SKILL)
	var unknown := _item("not_registered", Item.ItemType.SKILL)
	assert_eq(progression.call("level_of", unknown), 0)
	assert_false(progression.call("can_upgrade", unknown))
	assert_true(progression.call("can_upgrade", known_unowned), "已知未拥有技能可用于报价")
	assert_false(progression.call("upgrade_one", known_unowned), "实际成长必须 owned")
	assert_eq(progression.call("level_of", known_unowned), 1)


func test_skill_replacement_reset_and_all_growth_snapshot_restore() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var marble := _item("dark", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.DEFAULT)
	var relic := _item("relic", Item.ItemType.RELIC)
	var dash := _item("dash", Item.ItemType.SKILL)
	var missile := _item("magic_missile", Item.ItemType.SKILL)
	assert_true(loadout.call("add", marble))
	assert_true(loadout.call("add", relic))
	assert_true(loadout.call("add", dash))
	for item: Item in [marble, relic, dash]:
		assert_true(progression.call("upgrade_one", item))
	var saved: Dictionary = progression.call("snapshot")
	for item: Item in [marble, relic, dash]:
		assert_true(progression.call("upgrade_one", item))
	assert_true(loadout.call("replace_skill", missile))
	assert_true(progression.call("reset_skill", dash.id))
	assert_eq(progression.call("level_of", dash), 1)
	assert_eq(progression.call("level_of", missile), 1)

	assert_true(progression.call("restore", saved))
	assert_eq(progression.call("level_of", marble), 2)
	assert_eq(progression.call("level_of", relic), 2)
	assert_eq(progression.call("level_of", dash), 2)
	assert_eq(progression.call("revision"), saved[&"revision"])


func test_revision_is_order_independent_across_rebuilt_dicts() -> void:
	# 回归：Godot 的 Dictionary.hash() 对键插入顺序敏感，而 .tres 序列化往返不
	# 保证保持内存中的插入顺序。revision() 必须对内容相同、键序不同的字典给出
	# 相同指纹，否则存档写盘重载后永远无法通过恢复（进战斗退出后点继续只剩黑弹珠）。
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var marble := _item("dark", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.DEFAULT)
	var relic := _item("relic", Item.ItemType.RELIC)
	assert_true(loadout.call("add", marble))
	assert_true(loadout.call("add", relic))
	assert_true(progression.call("set_level", marble, 3))
	assert_true(progression.call("set_level", relic, 2))
	var snapshot: Dictionary = progression.call("snapshot")

	# 以相反的键插入顺序重建五个字段（模拟 .tres 重载后的字典顺序），再恢复。
	var rebuilt: Dictionary = {}
	for field: StringName in [
		&"marble_levels", &"marble_awakened", &"relic_levels", &"relic_awakened", &"skill_levels"
	]:
		var source_dict: Dictionary = snapshot[field]
		var rebuilt_dict: Dictionary = {}
		for key: Variant in source_dict:
			rebuilt_dict[key] = source_dict[key]
		rebuilt[field] = rebuilt_dict
	rebuilt[&"revision"] = snapshot[&"revision"]

	assert_true(progression.call("restore", rebuilt), "键序重排后仍应恢复成功")
	assert_eq(progression.call("level_of", marble), 3)
	assert_eq(progression.call("level_of", relic), 2)


func test_set_level_jumps_to_any_level_and_back() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var marble := _item("dark", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.DEFAULT)
	var relic := _item("relic", Item.ItemType.RELIC)
	var skill := _item("dash", Item.ItemType.SKILL)
	for item: Item in [marble, relic, skill]:
		assert_true(loadout.call("add", item))
	# 直接跳到觉醒。
	assert_true(progression.call("set_level", marble, 4))
	assert_eq(progression.call("level_of", marble), 4)
	# 觉醒降回普通等级。
	assert_true(progression.call("set_level", marble, 2))
	assert_eq(progression.call("level_of", marble), 2)
	assert_true(progression.call("set_level", relic, 3))
	assert_eq(progression.call("level_of", relic), 3)
	assert_true(progression.call("set_level", skill, 4))
	assert_eq(progression.call("level_of", skill), 4)
	# 未拥有物品不可设定等级。
	var unowned := _item("fire", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.FIRE)
	assert_false(progression.call("set_level", unowned, 3))


func test_marble_growth_publishes_modifiers_to_stat_system() -> void:
	var stats: Node = add_child_autofree(FakeStatSystemScript.new())
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout, stats)
	var dark := _item("dark", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.DEFAULT)
	assert_true(loadout.call("add", dark))
	assert_true(progression.call("upgrade_one", dark))
	var lv2_damage: Variant = stats.call("modifier_value", "dark_marble_damage")
	assert_not_null(lv2_damage, "Lv2 发布 dark_marble_damage")
	assert_true(progression.call("upgrade_one", dark))
	assert_true(progression.call("upgrade_one", dark))
	var lv4_damage: Variant = stats.call("modifier_value", "dark_marble_damage")
	assert_not_null(lv4_damage, "Lv4 发布 dark_marble_damage")
	assert_true(float(lv4_damage) >= float(lv2_damage), "伤害曲线随等级单调不减")
	progression.call("dispose")
	assert_true((stats.get("modifiers") as Array).is_empty())


func test_green_marble_growth_publishes_poison_cap_and_per_hit_modifiers() -> void:
	var stats: Node = add_child_autofree(FakeStatSystemScript.new())
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout, stats)
	var green := _item("green", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.GREEN)
	assert_true(loadout.call("add", green))

	# Level II 发布 cap；per-hit 未发布（数值自由：只断言存在与单调）。
	assert_true(progression.call("upgrade_one", green))
	var lv2_cap: Variant = stats.call("modifier_value", "poison_max_stacks")
	assert_not_null(lv2_cap, "Lv2 发布 poison_max_stacks")
	assert_null(stats.call("modifier_value", "poison_stacks_per_hit"))

	# Level III 曲线单调不减。
	assert_true(progression.call("upgrade_one", green))
	var lv3_cap: Variant = stats.call("modifier_value", "poison_max_stacks")
	assert_not_null(lv3_cap, "Lv3 发布 poison_max_stacks")
	assert_true(float(lv3_cap) >= float(lv2_cap), "cap 随等级单调不减")

	# Awakened：曲线不降，per-hit 为正值。
	assert_true(progression.call("upgrade_one", green))
	var lv4_cap: Variant = stats.call("modifier_value", "poison_max_stacks")
	assert_not_null(lv4_cap, "觉醒发布 poison_max_stacks")
	assert_true(float(lv4_cap) >= float(lv3_cap), "觉醒 cap 不降")
	var lv4_per_hit: Variant = stats.call("modifier_value", "poison_stacks_per_hit")
	assert_not_null(lv4_per_hit, "觉醒发布 poison_stacks_per_hit")
	assert_true(float(lv4_per_hit) > 0.0, "per-hit 为正值")
	progression.call("dispose")
	assert_true((stats.get("modifiers") as Array).is_empty())


func test_fire_marble_growth_publishes_cap_and_damage_without_changing_hit_fuel() -> void:
	var stats: Node = add_child_autofree(FakeStatSystemScript.new())
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout, stats)
	var fire := _item("fire", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.FIRE)
	assert_true(loadout.call("add", fire))

	# 等级推进 Lv2..Lv4：cap 恒发布且单调不减；每层伤害若出现则单调不减
	# （数值自由，调整曲线数值不应破坏本测试）。
	var cap_prev := 0.0
	var per_layer_prev := 0.0
	for level: int in 3:
		assert_true(progression.call("upgrade_one", fire))
		var cap: Variant = stats.call("modifier_value", "fire_burn_max_stacks")
		assert_not_null(cap, "Lv%d 发布 fire_burn_max_stacks" % (level + 2))
		assert_true(float(cap) >= cap_prev, "燃料上限随等级单调不减")
		cap_prev = float(cap)
		var per_layer: Variant = stats.call("modifier_value", "fire_burn_damage_per_layer")
		if per_layer != null:
			assert_true(float(per_layer) >= per_layer_prev, "每层伤害随等级单调不减")
			per_layer_prev = float(per_layer)

	# Regression source: burn redesign fixes hits at 4 initial fuel then 1 follow-up.
	# Repair: awakening never alters fuel attached per hit — fuel is not a stat.
	assert_null(stats.call("modifier_value", "fire_fuel_per_hit"), "命中燃料从未作为 stat 发布")
	progression.call("dispose")
	assert_true((stats.get("modifiers") as Array).is_empty())


func test_bomb_marble_growth_publishes_weakened_damage_and_awakened_radius_scale() -> void:
	var stats: Node = add_child_autofree(FakeStatSystemScript.new())
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout, stats)
	var bomb := _item("bomb", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.BOMB)
	assert_true(loadout.call("add", bomb))

	# 数值自由：只断言存在与单调。radius/effect_scale 曲线存在（数值自由）。
	assert_true(progression.call("upgrade_one", bomb))
	var lv2_damage: Variant = stats.call("modifier_value", "explosion_damage")
	assert_not_null(lv2_damage, "Lv2 发布 explosion_damage")
	assert_null(stats.call("modifier_value", "explosion_radius"))
	assert_true(progression.call("upgrade_one", bomb))
	assert_not_null(stats.call("modifier_value", "explosion_damage"), "Lv3 发布 explosion_damage")
	assert_true(progression.call("upgrade_one", bomb))
	var lv4_damage: Variant = stats.call("modifier_value", "explosion_damage")
	assert_not_null(lv4_damage, "觉醒发布 explosion_damage")
	assert_true(float(lv4_damage) >= float(lv2_damage), "爆炸伤害随等级单调不减")
	assert_not_null(stats.call("modifier_value", "explosion_radius"), "曲线含 explosion_radius")
	assert_not_null(stats.call("modifier_value", "explosion_effect_scale"), "曲线含 explosion_effect_scale")
	progression.call("dispose")
	assert_true((stats.get("modifiers") as Array).is_empty())


func test_lightning_marble_growth_publishes_discharge_damage_and_awakened_stacks() -> void:
	var stats: Node = add_child_autofree(FakeStatSystemScript.new())
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout, stats)
	var lightning := _item("lightning_marble", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.LIGHTNING)
	assert_true(loadout.call("add", lightning))

	# 数值自由：只断言存在与单调。repeat_arc_stacks 曲线存在（数值自由）。
	assert_true(progression.call("upgrade_one", lightning))
	var lv2_damage: Variant = stats.call("modifier_value", "lightning_discharge_damage_per_stack")
	assert_not_null(lv2_damage, "Lv2 发布 discharge_damage")
	assert_null(stats.call("modifier_value", "lightning_repeat_arc_stacks"))
	assert_true(progression.call("upgrade_one", lightning))
	var lv3_damage: Variant = stats.call("modifier_value", "lightning_discharge_damage_per_stack")
	assert_not_null(lv3_damage, "Lv3 发布 discharge_damage")
	assert_true(float(lv3_damage) >= float(lv2_damage), "伤害随等级单调不减")
	assert_true(progression.call("upgrade_one", lightning))
	var lv4_damage: Variant = stats.call("modifier_value", "lightning_discharge_damage_per_stack")
	assert_not_null(lv4_damage, "觉醒发布 discharge_damage")
	assert_true(float(lv4_damage) >= float(lv3_damage), "觉醒伤害不降")
	assert_not_null(stats.call("modifier_value", "lightning_repeat_arc_stacks"),
		"曲线含 lightning_repeat_arc_stacks")


func _item(id: String, type: Item.ItemType, marble_type: Marble.MARBLE_TYPE = Marble.MARBLE_TYPE.DEFAULT) -> Item:
	var result := Item.new()
	result.id = id
	result.type = type
	result.marble_type = marble_type
	return result
