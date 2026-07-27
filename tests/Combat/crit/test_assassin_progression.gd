extends GutTest

## Verifies ItemProgression writes assassin_weak_point_count from the LIVE chain and
## awakening state (owned-but-unslotted must not reveal weak points), and that the
## assassin_segment_damage growth stat is actually consumed by progression. Uses the
## class-less fake/loadout/progression scripts via .call() (their .new() is Variant).

const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")
const FakeStatSystemScript: GDScript = preload("res://tests/Loadout/fake_stat_system.gd")

const STAT_COUNT: String = "assassin_weak_point_count"
const STAT_SEGMENT: String = "assassin_segment_damage"


func _assassin_item() -> Item:
	var item := Item.new()
	item.id = "assassin_marble"
	item.type = Item.ItemType.MARBLE
	item.marble_type = Marble.MARBLE_TYPE.ASSASSIN
	return item


func _dark_item() -> Item:
	var item := Item.new()
	item.id = "dark_marble"
	item.type = Item.ItemType.MARBLE
	item.marble_type = Marble.MARBLE_TYPE.DEFAULT
	return item


func _setup(loadout: RefCounted, fake: Node) -> RefCounted:
	return ProgressionScript.new(loadout, fake)


func _count_or_zero(fake: Node) -> float:
	var value: Variant = fake.call("modifier_value", STAT_COUNT)
	return 0.0 if value == null else float(value)


func test_assassin_in_chain_sets_count_one() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var fake: Node = FakeStatSystemScript.new()
	add_child_autofree(fake)
	var _progression: RefCounted = _setup(loadout, fake)
	assert_true(loadout.call("add", _assassin_item()))
	assert_eq(fake.call("modifier_value", STAT_COUNT), 1.0)


func test_non_assassin_chain_sets_count_zero() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var fake: Node = FakeStatSystemScript.new()
	add_child_autofree(fake)
	var _progression: RefCounted = _setup(loadout, fake)
	assert_true(loadout.call("add", _dark_item()))
	assert_eq(fake.call("modifier_value", STAT_COUNT), 0.0)


func test_assassin_presence_full_lifecycle() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var fake: Node = FakeStatSystemScript.new()
	add_child_autofree(fake)
	var progression: RefCounted = _setup(loadout, fake)
	var assassin := _assassin_item()

	# Not equipped yet: no sync has run, presence reads as 0.
	assert_eq(_count_or_zero(fake), 0.0)

	assert_true(loadout.call("add", assassin), "equip Lv1")
	assert_eq(fake.call("modifier_value", STAT_COUNT), 1.0)

	for _upgrade: int in 3:
		assert_true(progression.call("upgrade_one", assassin))
	assert_eq(progression.call("level_of", assassin), 4)
	assert_eq(fake.call("modifier_value", STAT_COUNT), 2.0, "awakened while equipped -> two weak points")

	assert_true(loadout.call("remove", assassin), "unequip")
	assert_eq(fake.call("modifier_value", STAT_COUNT), 0.0, "removed from chain -> hidden")


func test_assassin_segment_damage_grows_with_level() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var fake: Node = FakeStatSystemScript.new()
	add_child_autofree(fake)
	var progression: RefCounted = _setup(loadout, fake)
	var assassin := _assassin_item()
	assert_true(loadout.call("add", assassin))

	# Lv1 has no explicit upgrade record yet; the base stat applies.
	assert_eq(fake.call("modifier_value", STAT_SEGMENT), null)

	assert_true(progression.call("upgrade_one", assassin))
	assert_eq(fake.call("modifier_value", STAT_SEGMENT), 2.0, "Lv2")
	assert_true(progression.call("upgrade_one", assassin))
	assert_eq(fake.call("modifier_value", STAT_SEGMENT), 3.0, "Lv3")
	assert_true(progression.call("upgrade_one", assassin))
	assert_eq(fake.call("modifier_value", STAT_SEGMENT), 3.0, "awakened keeps segment damage at 3")
