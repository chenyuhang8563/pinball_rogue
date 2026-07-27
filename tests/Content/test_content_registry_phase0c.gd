extends GutTest

const RandomSourceScript: GDScript = preload("res://Run/application/run_random_source.gd")


func test_real_content_ids_are_unique_sorted_and_starting_is_excluded_by_default() -> void:
	# Regression source: Phase 0c makes ContentRegistry the authored drop source.
	# Boundary: stable ordering and starting-only filtering must not depend on FS order.
	var registry: Node = get_node_or_null("/root/ContentRegistry")
	assert_not_null(registry)
	assert_true(registry.is_valid())
	var ids: Array[String] = []
	for item: Item in registry.all_items():
		assert_false(item.id.is_empty())
		assert_false(ids.has(item.id), "unique id %s" % item.id)
		ids.append(item.id)
	var sorted_ids: Array[String] = ids.duplicate()
	sorted_ids.sort()
	assert_eq(ids, sorted_ids)
	var marbles: Array = registry.query(Item.ItemType.MARBLE)
	assert_false(marbles.any(func(item: Item) -> bool: return item.tags.has(&"starting")))
	assert_not_null(registry.by_id(&"fire_bellows"))


func test_float_weights_are_seed_reproducible_and_negative_is_locally_zero() -> void:
	# Regression source: Phase 0c replaces integer-rounded drop weights.
	# Boundary: fractional positive weights survive, while a negative candidate is ignored.
	var registry: Node = get_node_or_null("/root/ContentRegistry")
	var negative := Item.new()
	negative.weight = -1.0
	var positive := Item.new()
	positive.weight = 0.25
	var negative_pool: Array[Item] = [negative, positive]
	assert_eq(registry.weighted_pick(negative_pool, RandomSourceScript.new(17)), positive)

	var first: RunRandomSource = RandomSourceScript.new(42)
	var second: RunRandomSource = RandomSourceScript.new(42)
	var pool: Array[Item] = []
	for weight: float in [0.2, 0.8]:
		var item := Item.new()
		item.weight = weight
		pool.append(item)
	for _index: int in range(12):
		assert_eq(registry.weighted_pick(pool, first), registry.weighted_pick(pool, second))


func test_new_fire_relics_use_distinct_32_pixel_rgba_icons() -> void:
	var registry: Node = get_node_or_null("/root/ContentRegistry")
	assert_not_null(registry)
	var expected_icons: Dictionary[StringName, String] = {
		&"accelerant": "res://Assets/Items/relic_accelerant.png",
		&"cremation": "res://Assets/Items/relic_cremation.png",
		&"fire_bellows": "res://Assets/Items/relic_fire_bellows.png",
	}
	for item_id: StringName in expected_icons:
		var item: Item = registry.by_id(item_id)
		assert_not_null(item)
		assert_eq(item.icon.resource_path, expected_icons[item_id])
		assert_eq(item.icon.get_width(), 32)
		assert_eq(item.icon.get_height(), 32)
		assert_ne(item.icon.get_image().detect_alpha(), Image.ALPHA_NONE)
