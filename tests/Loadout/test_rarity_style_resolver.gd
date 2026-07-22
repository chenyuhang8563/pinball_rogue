extends GutTest

const InventoryScene: PackedScene = preload("res://Loadout/presentation/inventory_scene/inventory.tscn")
const RarityStyleResolverScript: GDScript = preload("res://UI/shared/rarity_style_resolver.gd")


func test_every_rarity_resolves_to_a_distinct_prebuilt_border() -> void:
	# Regression source: Phase 0c adds five item rarities to inventory/shop UI.
	# Boundary: no rarity may fall through to a missing or shared StyleBox resource.
	var styles: Array[StyleBox] = []
	for rarity: int in [
		Item.Rarity.COMMON,
		Item.Rarity.UNCOMMON,
		Item.Rarity.RARE,
		Item.Rarity.BOSS,
		Item.Rarity.CURSE,
	]:
		var item := Item.new()
		item.rarity = rarity as Item.Rarity
		var style: StyleBox = RarityStyleResolverScript.for_item(item)
		assert_not_null(style, "rarity %d resolves" % rarity)
		assert_false(styles.has(style), "rarity %d has its own StyleBox" % rarity)
		styles.append(style)


func test_inventory_scene_exposes_five_relic_slots() -> void:
	# Regression source: relic capacity increased from three to five in Phase 0c.
	# Boundary: the fourth and fifth owned relics must both have visual slots.
	var inventory := InventoryScene.instantiate()
	add_child_autofree(inventory)
	var relic_bar := inventory.get_node_or_null("RelicBar") as HBoxContainer
	assert_not_null(relic_bar)
	assert_eq(relic_bar.get_child_count(), 5)
