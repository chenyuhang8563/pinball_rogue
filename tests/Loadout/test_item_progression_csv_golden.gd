extends GutTest

## 弹珠升级曲线结构测试（数值无关）。
##
## 升级曲线由 Content/data/marble_level_modifiers.csv 驱动。本测试只断言
## 曲线结构与单调性不变量，不断言具体数值——调整平衡数值（增删行、改值）
## 不应导致本测试失败。结构不变量：
##   1. 每个弹珠 Lv1..Lv4 曲线完整（从 Lv1 可一路升到 Lv4）；
##   2. 每个等级至少发布一个 modifier（曲线非空）；
##   3. 每个 stat 出现后值随等级非递减（等级只升不降）。

const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")
const FakeStatSystemScript: GDScript = preload("res://tests/Loadout/fake_stat_system.gd")

const WEAK_POINT_STAT: String = "assassin_weak_point_count"

## 与 Content/application/level_config_loader.gd 的 MARBLE_TYPE_BY_ITEM_ID 一致。
const MARBLES: Array = [
	["dark_marble", Marble.MARBLE_TYPE.DEFAULT],
	["brown_marble", Marble.MARBLE_TYPE.BROWN],
	["bomb_marble", Marble.MARBLE_TYPE.BOMB],
	["green_marble", Marble.MARBLE_TYPE.GREEN],
	["blue_marble", Marble.MARBLE_TYPE.BLUE],
	["fire_marble", Marble.MARBLE_TYPE.FIRE],
	["assassin_marble", Marble.MARBLE_TYPE.ASSASSIN],
	["lightning_marble", Marble.MARBLE_TYPE.LIGHTNING],
]


func test_each_marble_curve_is_complete_and_monotonic() -> void:
	for entry: Array in MARBLES:
		_assert_curve_structure(entry[0] as String, entry[1] as Marble.MARBLE_TYPE)


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


## 从 Lv1 升到 Lv4，逐级断言曲线结构（减去 live-chain 弱点 stat，另行覆盖）。
func _assert_curve_structure(item_id: String, marble_type: Marble.MARBLE_TYPE) -> void:
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
	var stat_values: Dictionary = {}
	for level_index: int in 4:
		var actual := _modifier_map(stats)
		actual.erase(WEAK_POINT_STAT)
		assert_false(actual.is_empty(), "%s Lv%d 应发布至少一个 modifier"
				% [item_id, level_index + 1])
		for stat_id: Variant in actual:
			if not stat_values.has(stat_id):
				stat_values[stat_id] = []
			(stat_values[stat_id] as Array).append(actual[stat_id])
		if level_index < 3:
			assert_true(progression.call("upgrade_one", item),
				"%s 可升到 Lv%d" % [item_id, level_index + 2])
	# 每个 stat 出现后的值随等级非递减（等级只升不降）。
	for stat_id: Variant in stat_values:
		var values: Array = stat_values[stat_id]
		for index: int in range(1, values.size()):
			assert_true(float(values[index]) >= float(values[index - 1]),
				"%s %s 曲线单调不减（Lv%d -> Lv%d）"
				% [item_id, stat_id, index, index + 1])
	progression.call("dispose")


## 构造 stored_level=1 的合法快照。restore() 会复算 revision 并与快照内值比对
## （不匹配仅告警；硬校验是结构校验），这里按 item_progression.gd 的规范化形式
## ——五个字段各自的 [key, value] 对数组、按键排序——构造一致的值。
func _lv1_state(marble_type: Marble.MARBLE_TYPE) -> Dictionary:
	var state: Dictionary = {
		&"marble_levels": {int(marble_type): 1},
		&"marble_awakened": {},
		&"relic_levels": {},
		&"relic_awakened": {},
		&"skill_levels": {},
	}
	state[&"revision"] = {
		&"marble_levels": [[int(marble_type), 1]],
		&"marble_awakened": [],
		&"relic_levels": [],
		&"relic_awakened": [],
		&"skill_levels": [],
	}.hash()
	return state


func _modifier_map(stats: Node) -> Dictionary:
	var result: Dictionary = {}
	for modifier: RefCounted in stats.get("modifiers") as Array:
		result[modifier.stat_id] = modifier.value
	return result
