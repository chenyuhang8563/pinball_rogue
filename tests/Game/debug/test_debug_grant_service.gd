extends GutTest

const DebugGrantServiceScript: GDScript = preload("res://Game/Debug/debug_grant_service.gd")
const RunScopeScript: GDScript = preload("res://Game/Bootstrap/run_scope.gd")
const FakeStatSystemScript: GDScript = preload("res://tests/Loadout/fake_stat_system.gd")


func test_grant_adds_catalog_item_and_rejects_same_level() -> void:
	var scope := _scope()
	var service: RefCounted = DebugGrantServiceScript.new()
	assert_true(service.call("configure", scope.loadout, scope.progression))

	assert_eq(service.call("grant", &"green_marble"), DebugGrantServiceScript.Result.GRANTED)
	# 已拥有且请求等级与当前等级相同 -> 提示，不再视为可覆盖。
	assert_eq(service.call("grant", &"green_marble"), DebugGrantServiceScript.Result.SAME_LEVEL)
	assert_true(scope.loadout.call("has_item_id", "green_marble"))


func test_grant_sets_and_overwrites_requested_level() -> void:
	var scope := _scope()
	var service: RefCounted = DebugGrantServiceScript.new()
	assert_true(service.call("configure", scope.loadout, scope.progression))

	# 新发放可直接指定等级（Lv3）。
	assert_eq(service.call("grant", &"green_marble", 3), DebugGrantServiceScript.Result.GRANTED)
	var green := load("res://Content/data/green_marble.tres") as Item
	assert_eq(scope.progression.call("level_of", green), 3)

	# 同等级重复发放 -> 提示，等级保持不变。
	assert_eq(service.call("grant", &"green_marble", 3), DebugGrantServiceScript.Result.SAME_LEVEL)
	assert_eq(scope.progression.call("level_of", green), 3)

	# 不同等级 -> 直接覆盖（后者胜出）。
	assert_eq(service.call("grant", &"green_marble", 1), DebugGrantServiceScript.Result.GRANTED)
	assert_eq(scope.progression.call("level_of", green), 1)


func test_grant_replaces_skill_and_sets_new_skill_level() -> void:
	var scope := _scope()
	var service: RefCounted = DebugGrantServiceScript.new()
	assert_true(service.call("configure", scope.loadout, scope.progression))

	# 新技能直接指定等级（觉醒 Lv4）。
	assert_eq(service.call("grant", &"dash", 4), DebugGrantServiceScript.Result.GRANTED)
	var dash := load("res://Content/data/dash_skill.tres") as Item
	assert_eq(scope.progression.call("level_of", dash), 4)

	# 同一技能不同等级 -> 覆盖。
	assert_eq(service.call("grant", &"dash", 2), DebugGrantServiceScript.Result.GRANTED)
	assert_eq(scope.progression.call("level_of", dash), 2)

	# 换新技能：重置旧技能成长并设定新技能等级。
	assert_eq(service.call("grant", &"magic_missile", 3), DebugGrantServiceScript.Result.GRANTED)
	assert_eq((scope.loadout.call("current_skill") as Item).id, "magic_missile")
	assert_eq(scope.progression.call("level_of", dash), 1)
	var missile := load("res://Content/data/magic_missile_skill.tres") as Item
	assert_eq(scope.progression.call("level_of", missile), 3)


func test_grant_rejects_unknown_id() -> void:
	var scope := _scope()
	var service: RefCounted = DebugGrantServiceScript.new()
	assert_true(service.call("configure", scope.loadout, scope.progression))
	assert_eq(service.call("grant", &"not_an_item"), DebugGrantServiceScript.Result.UNKNOWN_ID)


func _scope() -> RunScope:
	var stats: Node = add_child_autofree(FakeStatSystemScript.new())
	stats.set("values", {
		"marble_slot_count": 3,
		"relic_slot_count": 3,
		"buy_price_multiplier": 1.0,
		"sell_price_multiplier": 0.5,
	})
	var scope: RunScope = add_child_autofree(RunScopeScript.new())
	assert_true(scope.initialize(stats))
	return scope
