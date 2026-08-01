extends GutTest

const InventoryScene: PackedScene = preload("res://Loadout/presentation/inventory_scene/inventory.tscn")
const InventoryPanelScene: PackedScene = preload("res://Loadout/presentation/inventory_panel.tscn")
const ShopScene: PackedScene = preload("res://Commerce/presentation/normal_shop/shop.tscn")
const RewardCardScene: PackedScene = preload("res://Run/presentation/reward_marble_card.tscn")
const ItemTooltipScene: PackedScene = preload("res://UI/shared/item_tooltip.tscn")
const ItemTooltipScript: GDScript = preload("res://UI/shared/item_tooltip.gd")
const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")


func test_inventory_shared_scenes_use_tooltip_slots_for_every_item_type() -> void:
	var inventory: Node = add_child_autofree(InventoryScene.instantiate()) as Node
	for path: NodePath in [
		NodePath("MarbleBox/MarbleSlot1"),
		NodePath("RelicBar/RelicSlot1"),
	]:
		_assert_tooltip_slot(inventory.get_node(path))

	var panel: Node = add_child_autofree(InventoryPanelScene.instantiate()) as Node
	_assert_tooltip_slot(panel.get_node(
		"UI/Panel/MarginContainer/Layout/Content/SkillBar/SkillSlot1"
	))

	var shop: Node = add_child_autofree(ShopScene.instantiate()) as Node
	_assert_tooltip_slot(shop.get_node("UI/Panel/CollectionRows/SkillBox/SkillSlot"))


func test_inventory_panel_normal_and_upgrade_selection_keep_current_levels_in_tooltips() -> void:
	var fixture := _loadout_fixture()
	var panel := add_child_autofree(InventoryPanelScene.instantiate()) as InventoryPanel
	assert_true(panel.configure(fixture.loadout, fixture.progression))

	_assert_panel_levels(panel, 3)
	panel.set("_upgrade_selection_active", true)
	panel.refresh_inventory()
	_assert_panel_levels(panel, 3)


func test_shop_inventory_passes_current_levels_and_clears_empty_slot_tooltip() -> void:
	var fixture := _loadout_fixture()
	var shop: Node = add_child_autofree(ShopScene.instantiate()) as Node
	shop.set("_loadout", fixture.loadout)
	shop.set("_progression", fixture.progression)
	shop.call("refresh_collection_rows")

	var marble_slot: Node = shop.get_node("UI/Panel/CollectionRows/MarbleBox/MarbleSlot1")
	var relic_slot: Node = shop.get_node("UI/Panel/CollectionRows/RelicBar/RelicSlot1")
	var skill_slot: Node = shop.get_node("UI/Panel/CollectionRows/SkillBox/SkillSlot")
	for slot: Node in [marble_slot, relic_slot, skill_slot]:
		assert_eq(int(slot.get("_level")), 3)
		var tooltip := slot.call("_make_custom_tooltip", "") as ItemTooltip
		assert_not_null(tooltip)
		if tooltip != null:
			tooltip.free()

	assert_true(fixture.loadout.call("remove", fixture.relic))
	shop.call("refresh_collection_rows")
	assert_null(relic_slot.get("_item"))
	assert_eq(int(relic_slot.get("_level")), 0)
	assert_null(relic_slot.call("_make_custom_tooltip", ""))
	var relic_icon := relic_slot.get_node("Icon") as ItemIconView
	assert_null(relic_icon.get_texture())


func test_reward_card_reuses_tooltip_description_bbcode_without_creating_tooltip_or_price() -> void:
	var translation := Translation.new()
	translation.locale = "en"
	translation.add_message("ITEM_FIRE_MARBLE_TITLE", "Fire Marble")
	translation.add_message(
		"ITEM_FIRE_MARBLE_DESC_LV3",
		"Burn deals [damage_fire]4[/damage_fire] damage."
	)
	TranslationServer.add_translation(translation)
	var previous_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")

	var item := _item("fire_marble", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.FIRE)
	var card := add_child_autofree(RewardCardScene.instantiate()) as RewardMarbleCard
	var tooltip := add_child_autofree(ItemTooltipScene.instantiate()) as ItemTooltip
	card.set_reward(item, 3, true)
	tooltip.set_item(item, 3)

	var card_description := card.get_node("Content/DescriptionLabel") as RichTextLabel
	var tooltip_description := tooltip.get_node(
		"MainPanel/TooltipMargin/TooltipLayout/DescriptionLabel"
	) as RichTextLabel
	assert_eq(card_description.text, tooltip_description.text)
	assert_eq(card_description.text, ItemTooltipScript.description_bbcode(item, 3))
	assert_string_contains(card_description.text, "[color=#cead4a]Burn[/color]")
	assert_string_contains(card_description.text, "#ef6a4c")
	assert_null(card.get_node_or_null("TermPanel"))
	assert_null(card.get_node_or_null("Price"))
	assert_true(card.find_children("*Price*", "", true, false).is_empty())
	assert_eq(card.tooltip_text, "")
	assert_false(card.has_method("_make_custom_tooltip"))

	TranslationServer.set_locale(previous_locale)
	TranslationServer.remove_translation(translation)


func test_reward_card_shows_target_roman_level_and_upgrade_arrow_state() -> void:
	var item := _item("brown_marble", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.DEFAULT)
	var card := add_child_autofree(RewardCardScene.instantiate()) as RewardMarbleCard
	var badge := card.get_node("Content/IconArea/Icon/LevelBadge") as Label
	var arrow := card.get_node("Content/IconArea/LevelUp") as Sprite2D
	var expected := ["I", "II", "III", "IV"]
	for level: int in range(1, 5):
		var upgrade := level > 1
		card.set_reward(item, level, upgrade)
		assert_eq(badge.text, expected[level - 1])
		assert_eq(arrow.visible, upgrade)
		assert_eq(card.target_level(), level)
		assert_eq(card.is_upgrade_reward(), upgrade)


func _assert_tooltip_slot(slot: Node) -> void:
	assert_not_null(slot)
	assert_true(slot.has_method("set_item_tooltip"))
	var item := _item("tooltip-test", Item.ItemType.RELIC)
	slot.call("set_item_tooltip", item, 2)
	var tooltip := slot.call("_make_custom_tooltip", "") as ItemTooltip
	assert_not_null(tooltip)
	if tooltip != null:
		tooltip.free()


func _assert_panel_levels(panel: InventoryPanel, expected_level: int) -> void:
	for path: NodePath in [
		NodePath("UI/Panel/MarginContainer/Layout/Content/CollectionRows/MarbleBox/MarbleSlot1"),
		NodePath("UI/Panel/MarginContainer/Layout/Content/CollectionRows/RelicBar/RelicSlot1"),
		NodePath("UI/Panel/MarginContainer/Layout/Content/SkillBar/SkillSlot1"),
	]:
		var slot := panel.get_node(path)
		assert_eq(int(slot.get("_level")), expected_level)
		var tooltip := slot.call("_make_custom_tooltip", "") as ItemTooltip
		assert_not_null(tooltip)
		if tooltip != null:
			tooltip.free()


func _loadout_fixture() -> Dictionary:
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var marble := (load("res://Content/data/brown_marble.tres") as Item).duplicate(true) as Item
	var relic := (load("res://Content/data/fire_bellows.tres") as Item).duplicate(true) as Item
	var skill := (load("res://Content/data/magic_missile_skill.tres") as Item).duplicate(true) as Item
	assert_true(loadout.call("add", marble))
	assert_true(loadout.call("add", relic))
	assert_true(loadout.call("add", skill))
	for item: Item in [marble, relic, skill]:
		assert_true(progression.call("upgrade_one", item))
		assert_true(progression.call("upgrade_one", item))
	return {
		"loadout": loadout,
		"progression": progression,
		"marble": marble,
		"relic": relic,
		"skill": skill,
	}


func _item(
	id: String,
	type: Item.ItemType,
	marble_type: Marble.MARBLE_TYPE = Marble.MARBLE_TYPE.DEFAULT
) -> Item:
	var item := Item.new()
	item.id = id
	item.title = id
	item.description = "description"
	item.type = type
	item.marble_type = marble_type
	return item
