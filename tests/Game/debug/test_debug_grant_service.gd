extends GutTest

const DebugGrantServiceScript: GDScript = preload("res://Game/Debug/debug_grant_service.gd")
const RunScopeScript: GDScript = preload("res://Game/Bootstrap/run_scope.gd")
const FakeStatSystemScript: GDScript = preload("res://tests/Loadout/fake_stat_system.gd")


func test_grant_adds_catalog_item_and_rejects_duplicate() -> void:
	var scope := _scope()
	var service: RefCounted = DebugGrantServiceScript.new()
	assert_true(service.configure(scope.loadout, scope.progression))

	assert_eq(service.grant(&"green_marble"), DebugGrantServiceScript.Result.GRANTED)
	assert_eq(service.grant(&"green_marble"), DebugGrantServiceScript.Result.DUPLICATE)
	assert_true(scope.loadout.has_item_id("green_marble"))


func test_grant_replaces_skill_and_resets_replaced_skill_progression() -> void:
	var scope := _scope()
	var service: RefCounted = DebugGrantServiceScript.new()
	assert_true(service.configure(scope.loadout, scope.progression))
	assert_eq(service.grant(&"dash"), DebugGrantServiceScript.Result.GRANTED)
	var dash := load("res://Content/data/dash_skill.tres") as Item
	assert_true(scope.progression.upgrade_one(dash))

	assert_eq(service.grant(&"magic_missile"), DebugGrantServiceScript.Result.GRANTED)
	assert_eq(scope.loadout.current_skill().id, "magic_missile")
	assert_eq(scope.progression.level_of(dash), 1)


func test_grant_rejects_unknown_id() -> void:
	var scope := _scope()
	var service: RefCounted = DebugGrantServiceScript.new()
	assert_true(service.configure(scope.loadout, scope.progression))
	assert_eq(service.grant(&"not_an_item"), DebugGrantServiceScript.Result.UNKNOWN_ID)


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
