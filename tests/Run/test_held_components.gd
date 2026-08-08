extends GutTest

const HeldComponentsScript: GDScript = preload("res://Run/domain/held_components.gd")


func test_seed_initial_kit_holds_barrel_booster_portal_each_once() -> void:
	var held: RefCounted = HeldComponentsScript.new()
	assert_true(held.call("seed_initial_kit"))
	assert_eq(held.call("count_of", &"barrel"), 1)
	assert_eq(held.call("count_of", &"booster"), 1)
	assert_eq(held.call("count_of", &"portal"), 1)


func test_count_of_unknown_kind_returns_zero() -> void:
	var held: RefCounted = HeldComponentsScript.new()
	assert_eq(held.call("count_of", &"nonexistent"), 0)
	assert_eq(held.call("count_of", &"unknown"), 0)


func test_snapshot_restore_round_trips_counts() -> void:
	var held: RefCounted = HeldComponentsScript.new()
	held.call("seed_initial_kit")
	var state: Dictionary = held.call("snapshot")
	var restored: RefCounted = HeldComponentsScript.new()
	assert_true(restored.call("restore", state))
	assert_eq(restored.call("count_of", &"barrel"), 1)
	assert_eq(restored.call("count_of", &"booster"), 1)
	assert_eq(restored.call("count_of", &"portal"), 1)


func test_kinds_and_entries_iterate_initial_kit_in_seed_order() -> void:
	var held: RefCounted = HeldComponentsScript.new()
	held.call("seed_initial_kit")
	assert_eq(held.call("kinds"), [&"barrel", &"booster", &"portal"])
	var entries: Array = held.call("entries")
	assert_eq(entries.size(), 3)
	assert_eq(entries[0][&"kind"], &"barrel")
	assert_eq(entries[0][&"count"], 1)
	assert_eq(entries[1][&"kind"], &"booster")
	assert_eq(entries[1][&"count"], 1)
	assert_eq(entries[2][&"kind"], &"portal")
	assert_eq(entries[2][&"count"], 1)
