extends GutTest

## Golden matrix for marble upgrade curves. Each expectation is the COMPLETE
## modifier map published to the stat system at levels 1..4 for that marble,
## sourced from Content/data/marble_level_modifiers.csv.
##
## This test passes against both the old hardcoded UPGRADE_VALUES and the CSV
## loader: writing it before wiring proves the expectation matrix itself, and
## after wiring it proves the CSV is semantically equal to the old constants.

const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")
const FakeStatSystemScript: GDScript = preload("res://tests/Loadout/fake_stat_system.gd")

const WEAK_POINT_STAT: String = "assassin_weak_point_count"


func test_dark_marble_curve() -> void:
	_assert_marble_curve("dark_marble", Marble.MARBLE_TYPE.DEFAULT, [
		{"dark_marble_damage": 1.0},
		{"dark_marble_damage": 2.0},
		{"dark_marble_damage": 3.0},
		{"dark_marble_damage": 4.0},
	])


func test_bomb_marble_curve() -> void:
	_assert_marble_curve("bomb_marble", Marble.MARBLE_TYPE.BOMB, [
		{"explosion_damage": 4.0},
		{"explosion_damage": 6.0},
		{"explosion_damage": 8.0},
		{"explosion_damage": 8.0, "explosion_radius": 75.0, "explosion_effect_scale": 4.0},
	])


func test_green_marble_curve() -> void:
	_assert_marble_curve("green_marble", Marble.MARBLE_TYPE.GREEN, [
		{"poison_max_stacks": 10.0},
		{"poison_max_stacks": 15.0},
		{"poison_max_stacks": 20.0},
		{"poison_max_stacks": 20.0, "poison_stacks_per_hit": 2.0},
	])


func test_brown_marble_curve() -> void:
	_assert_marble_curve("brown_marble", Marble.MARBLE_TYPE.BROWN, [
		{"echo_bonus_damage": 2.0},
		{"echo_bonus_damage": 4.0},
		{"echo_bonus_damage": 8.0},
		{"echo_bonus_damage": 8.0, "echo_flipper_speed_multiplier": 2.0},
	])


func test_blue_marble_curve() -> void:
	_assert_marble_curve("blue_marble", Marble.MARBLE_TYPE.BLUE, [
		{"blue_frost_duration": 4.0},
		{"blue_frost_duration": 4.0, "blue_frost_bonus_damage_enabled": 1.0},
		{"blue_frost_duration": 4.0, "blue_frost_bonus_damage_enabled": 1.0},
		{"blue_frost_duration": 4.0, "blue_frost_bonus_damage_enabled": 1.0,
				"blue_frost_stacks_per_hit": 2.0},
	])


func test_fire_marble_curve() -> void:
	_assert_marble_curve("fire_marble", Marble.MARBLE_TYPE.FIRE, [
		{"fire_burn_max_stacks": 10.0},
		{"fire_burn_max_stacks": 15.0},
		{"fire_burn_max_stacks": 20.0, "fire_burn_damage_per_layer": 3.0},
		{"fire_burn_max_stacks": 20.0, "fire_burn_damage_per_layer": 3.0},
	])


func test_assassin_marble_curve() -> void:
	_assert_marble_curve("assassin_marble", Marble.MARBLE_TYPE.ASSASSIN, [
		{"assassin_segment_damage": 1.0},
		{"assassin_segment_damage": 2.0},
		{"assassin_segment_damage": 3.0},
		{"assassin_segment_damage": 3.0},
	])


func test_lightning_marble_curve() -> void:
	_assert_marble_curve("lightning_marble", Marble.MARBLE_TYPE.LIGHTNING, [
		{"lightning_discharge_damage_per_stack": 2.0},
		{"lightning_discharge_damage_per_stack": 3.0},
		{"lightning_discharge_damage_per_stack": 4.0},
		{"lightning_discharge_damage_per_stack": 4.0, "lightning_repeat_arc_stacks": 2.0},
	])


func test_assassin_weak_point_count_is_zero_when_not_slotted() -> void:
	# 上阵语义 = 在 chain 中；loadout.add() 会把弹珠直接放入 chain，因此
	# 「未上阵」用非刺客弹珠验证：chain 无 assassin 时 weak point 为 0。
	var stats: Node = add_child_autofree(FakeStatSystemScript.new())
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout, stats)
	var item := Item.new()
	item.id = "dark_marble"
	item.type = Item.ItemType.MARBLE
	item.marble_type = Marble.MARBLE_TYPE.DEFAULT
	assert_true(loadout.call("add", item))
	assert_eq(_modifier_map(stats).get(WEAK_POINT_STAT), 0.0, "未上阵不暴露弱点")
	progression.call("dispose")


## Grows the marble through levels 1..4 and asserts the complete modifier map
## (minus the live-chain weak-point stat, covered separately) at each level.
func _assert_marble_curve(item_id: String, marble_type: Marble.MARBLE_TYPE,
		expected_levels: Array) -> void:
	var stats: Node = add_child_autofree(FakeStatSystemScript.new())
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout, stats)
	var item := Item.new()
	item.id = item_id
	item.type = Item.ItemType.MARBLE
	item.marble_type = marble_type
	assert_true(loadout.call("add", item))
	# 用合法 restore() 确立 Lv1：显式 stored_level=1。注意 add() 后不做任何
	# restore 时 _marble_levels 为空，_sync_stat_modifiers 的 types_to_sync
	# 不含该弹珠 —— Lv1 不发布任何 modifier（与旧实现一致）。
	assert_true(progression.call("restore", _lv1_state(marble_type)))
	for level_index: int in expected_levels.size():
		var actual := _modifier_map(stats)
		actual.erase(WEAK_POINT_STAT)
		assert_eq(actual, expected_levels[level_index] as Dictionary,
				"%s Lv%d" % [item_id, level_index + 1])
		if level_index < expected_levels.size() - 1:
			assert_true(progression.call("upgrade_one", item))
	progression.call("dispose")


## 构造 stored_level=1 的合法快照：restore() 校验 revision 等于五个状态字典
## 的哈希（不含 revision 键自身），因此这里显式计算一次。
func _lv1_state(marble_type: Marble.MARBLE_TYPE) -> Dictionary:
	var state: Dictionary = {
		&"marble_levels": {int(marble_type): 1},
		&"marble_awakened": {},
		&"relic_levels": {},
		&"relic_awakened": {},
		&"skill_levels": {},
	}
	state[&"revision"] = {
		&"marble_levels": state[&"marble_levels"],
		&"marble_awakened": state[&"marble_awakened"],
		&"relic_levels": state[&"relic_levels"],
		&"relic_awakened": state[&"relic_awakened"],
		&"skill_levels": state[&"skill_levels"],
	}.hash()
	return state


func _modifier_map(stats: Node) -> Dictionary:
	var result: Dictionary = {}
	for modifier: RefCounted in stats.get("modifiers") as Array:
		result[modifier.stat_id] = modifier.value
	return result
