extends GutTest

const ItemTooltipScene: PackedScene = preload("res://UI/shared/item_tooltip.tscn")
const RewardTooltipButtonScript: GDScript = preload("res://Run/presentation/reward_tooltip_button.gd")
const DraftRewardPanelScript: GDScript = preload("res://Run/presentation/draft_reward_panel.gd")
const InventoryIconSlotScript: GDScript = preload("res://Loadout/presentation/inventory_icon_slot.gd")
const RewardOptionScript: GDScript = preload("res://Run/domain/reward_option.gd")

const ITEM_IDS: Array[String] = [
	"dark_marble", "bomb_marble", "brown_marble", "blue_marble", "green_marble", "fire_marble", "assassin_marble",
	"lightning", "fire_bellows", "accelerant", "cremation", "poison_culture", "ice_hammer", "permafrost", "cryoclasm",
	"carrion", "parasite", "pustule", "venom_knife", "scorpion_tail", "witch_hat", "assassins_whetstone", "fortuna_dice",
	"many_faced_prism", "scarlet_thread", "execution_decree", "thermal_shock", "miasma", "dash", "magic_missile",
]


func test_level_csv_has_exactly_four_unique_descriptions_for_each_item() -> void:
	var file := FileAccess.open("res://translations/item_levels.csv", FileAccess.READ)
	assert_not_null(file)
	var keys: Dictionary = {}
	if file == null:
		return
	file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 3:
			continue
		var key := String(row[0])
		if key.begins_with("ITEM_") and "_DESC_LV" in key:
			assert_eq(row.size(), 3, "CSV row must have key, English and Chinese columns: %s" % key)
			assert_false(keys.has(key), "duplicate level description key: %s" % key)
			keys[key] = true
	for item_id: String in ITEM_IDS:
		for level: int in range(1, 5):
			assert_true(keys.has("ITEM_%s_DESC_LV%d" % [item_id.to_upper(), level]))
	assert_eq(keys.size(), ITEM_IDS.size() * 4)


func test_tooltip_selects_level_text_and_formats_hoverable_term() -> void:
	var translation := Translation.new()
	translation.locale = "en"
	translation.add_message("ITEM_FIRE_MARBLE_TITLE", "Fire Marble")
	translation.add_message("ITEM_FIRE_MARBLE_DESC_LV3", "Burn deals [damage_fire]3[/damage_fire] damage.")
	translation.add_message("TERM_BURN_NAME", "Burn")
	translation.add_message("TERM_BURN_DESC", "Definition")
	translation.add_message("UI_TOOLTIP_TERMS_TITLE", "Terms")
	TranslationServer.add_translation(translation)
	var previous_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var tooltip: ItemTooltip = add_child_autofree(ItemTooltipScene.instantiate()) as ItemTooltip
	var item := Item.new()
	item.id = "fire_marble"
	item.title = "fallback"
	item.description = "fallback"
	tooltip.set_item(item, 3)
	var description: RichTextLabel = tooltip.get_node("MainPanel/TooltipMargin/TooltipLayout/DescriptionLabel") as RichTextLabel
	assert_string_contains(description.text, "[color=#cead4a]Burn[/color]")
	assert_string_contains(description.text, "#ef6a4c")
	assert_true((tooltip.get_node("TermPanel") as Control).visible)
	var term_definition := tooltip.get_node("TermPanel/TermMargin/TermLayout/TermDefinitionLabel") as RichTextLabel
	assert_ne(term_definition.text, "")
	tooltip.set_text("Plain item", "Deal 3 damage.")
	assert_false((tooltip.get_node("TermPanel") as Control).visible)
	assert_eq((tooltip.get_node("TermPanel/TermMargin/TermLayout/TermTitleLabel") as Label).text, "")
	assert_eq(term_definition.text, "")
	TranslationServer.set_locale(previous_locale)
	TranslationServer.remove_translation(translation)


func test_reward_and_inventory_tooltip_hosts_keep_the_requested_level() -> void:
	var item := Item.new()
	item.id = "fire_marble"
	var reward_button: RewardTooltipButton = RewardTooltipButtonScript.new() as RewardTooltipButton
	reward_button.call("set_item_tooltip", item, 4)
	var reward_tooltip: ItemTooltip = reward_button.call("_make_custom_tooltip", "") as ItemTooltip
	assert_not_null(reward_tooltip)
	var inventory_slot: InventoryIconSlot = InventoryIconSlotScript.new() as InventoryIconSlot
	inventory_slot.call("set_item_tooltip", item, 2)
	var inventory_tooltip: ItemTooltip = inventory_slot.call("_make_custom_tooltip", "") as ItemTooltip
	assert_not_null(inventory_tooltip)
	reward_tooltip.free()
	inventory_tooltip.free()
	reward_button.free()
	inventory_slot.free()


func test_upgrade_reward_uses_next_level_and_new_reward_uses_level_one() -> void:
	var panel: DraftRewardPanel = DraftRewardPanelScript.new() as DraftRewardPanel
	var new_reward: RewardOption = RewardOptionScript.item_reward(&"new", Item.new()) as RewardOption
	assert_eq(panel.call("_tooltip_level_for_option", new_reward), 1)
	var upgrade: RewardOption = RewardOptionScript.item_reward(&"upgrade", Item.new()) as RewardOption
	upgrade.call("_configure_settlement", "", RewardOption.Resolution.UPGRADE_RELIC, 0, 0, 0, 0, 0, "", 2)
	assert_eq(panel.call("_tooltip_level_for_option", upgrade), 3)
	panel.free()
