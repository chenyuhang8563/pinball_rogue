extends GutTest

const ItemTooltipScene: PackedScene = preload("res://UI/shared/item_tooltip.tscn")
const UpgradeDialogScene: PackedScene = preload("res://Loadout/presentation/skill_replace_dialog.tscn")
const RewardTooltipButtonScript: GDScript = preload("res://Run/presentation/reward_tooltip_button.gd")
const DraftRewardPanelScript: GDScript = preload("res://Run/presentation/draft_reward_panel.gd")
const InventoryIconSlotScript: GDScript = preload("res://Loadout/presentation/inventory_icon_slot.gd")
const RewardOptionScript: GDScript = preload("res://Run/domain/reward_option.gd")

const ITEM_IDS: Array[String] = [
	"dark_marble", "bomb_marble", "brown_marble", "blue_marble", "green_marble", "fire_marble", "assassin_marble", "lightning_marble",
	"lightning", "leyden_jar", "arc_relay", "thunderstorm", "fire_bellows", "accelerant", "cremation", "poison_culture", "ice_hammer", "permafrost", "cryoclasm",
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
	assert_string_contains(term_definition.text, "[color=#cead4a]%s[/color]\n%s" % [tr("TERM_BURN_NAME"), tr("TERM_BURN_DESC")])
	tooltip.set_text("Plain item", "Deal 3 damage.")
	assert_false((tooltip.get_node("TermPanel") as Control).visible)
	assert_eq(term_definition.text, "")
	TranslationServer.set_locale(previous_locale)
	TranslationServer.remove_translation(translation)


func test_term_card_lists_each_term_name_then_brief_in_order() -> void:
	var translation := Translation.new()
	translation.locale = "en"
	translation.add_message("TERM_BURN_NAME", "Burn")
	translation.add_message("TERM_BURN_DESC", "Burn brief")
	translation.add_message("TERM_CRIT_NAME", "Crit")
	translation.add_message("TERM_CRIT_DESC", "Crit brief")
	TranslationServer.add_translation(translation)
	var previous_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var tooltip: ItemTooltip = add_child_autofree(ItemTooltipScene.instantiate()) as ItemTooltip
	tooltip.set_text("Multi", "Applies Burn and Crit.")
	assert_true((tooltip.get_node("TermPanel") as Control).visible)
	var term_definition := tooltip.get_node("TermPanel/TermMargin/TermLayout/TermDefinitionLabel") as RichTextLabel
	# 每个术语：名称（术语色）独占一行作小标题，下一行写简介
	var burn_block := "[color=#cead4a]%s[/color]\n%s" % [tr("TERM_BURN_NAME"), tr("TERM_BURN_DESC")]
	var crit_block := "[color=#cead4a]%s[/color]\n%s" % [tr("TERM_CRIT_NAME"), tr("TERM_CRIT_DESC")]
	assert_string_contains(term_definition.text, burn_block)
	assert_string_contains(term_definition.text, crit_block)
	# 多个术语按出现顺序依次向下堆叠
	assert_true(term_definition.text.find(burn_block) < term_definition.text.find(crit_block))
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


func test_reward_relic_row_uses_settlement_target_level_and_clears_tooltip() -> void:
	var scene_source := FileAccess.get_file_as_string("res://Run/presentation/draft_reward_panel.tscn")
	assert_string_contains(scene_source, "res://Run/presentation/reward_tooltip_button.gd")
	var relic_section := scene_source.get_slice("[node name=\"RelicRewardButton\"", 1)
	assert_string_contains(relic_section.get_slice("[node", 0), "script = ExtResource")

	var panel: DraftRewardPanel = DraftRewardPanelScript.new() as DraftRewardPanel
	var button: RewardTooltipButton = RewardTooltipButtonScript.new() as RewardTooltipButton
	var relic := Item.new()
	relic.id = "fire_bellows"
	var option: RewardOption = RewardOptionScript.item_reward(&"relic-upgrade", relic) as RewardOption
	option.call(
		"_configure_settlement", "", RewardOption.Resolution.UPGRADE_ITEM, 0, 0, 0, 0, 0, "", 2
	)
	panel.call("_configure_reward_row", button, option, null, "Fire Bellows")
	assert_eq(button.get("_item") as Item, relic)
	assert_eq(int(button.get("_level")), option.target_level)
	var tooltip := button.call("_make_custom_tooltip", "") as ItemTooltip
	assert_not_null(tooltip)
	if tooltip != null:
		var description := tooltip.get_node(
			"MainPanel/TooltipMargin/TooltipLayout/DescriptionLabel"
		) as RichTextLabel
		assert_eq(description.text, ItemTooltip.description_bbcode(relic, option.target_level))
		tooltip.free()
	panel.call("_configure_reward_row", button, null, null, "")
	assert_null(button.get("_item"))
	assert_null(button.call("_make_custom_tooltip", ""))
	button.free()
	panel.free()


func test_reward_settlement_exposes_target_level_instead_of_ui_guessing() -> void:
	var new_reward: RewardOption = RewardOptionScript.item_reward(&"new", Item.new()) as RewardOption
	new_reward.call(
		"_configure_settlement", "", RewardOption.Resolution.ADD_ITEM, 0, 0, 0, 0, 0, "", 0
	)
	assert_eq(new_reward.target_level, 1)
	assert_false(new_reward.is_upgrade)
	var upgrade: RewardOption = RewardOptionScript.item_reward(&"upgrade", Item.new()) as RewardOption
	upgrade.call(
		"_configure_settlement", "", RewardOption.Resolution.UPGRADE_ITEM, 0, 0, 0, 0, 0, "", 2
	)
	assert_eq(upgrade.target_level, 3)
	assert_true(upgrade.is_upgrade)


func test_upgrade_dialog_compares_all_item_types_and_keeps_arrow_between_rows() -> void:
	var translation := Translation.new()
	translation.locale = "en"
	var cases: Array[Dictionary] = [
		{&"id": "comparison_marble", &"type": Item.ItemType.MARBLE},
		{&"id": "comparison_relic", &"type": Item.ItemType.RELIC},
		{&"id": "comparison_skill", &"type": Item.ItemType.SKILL},
	]
	for data: Dictionary in cases:
		var item_id := String(data[&"id"])
		translation.add_message("ITEM_%s_DESC_LV2" % item_id.to_upper(), "%s current" % item_id)
		translation.add_message("ITEM_%s_DESC_LV3" % item_id.to_upper(), "%s upgraded" % item_id)
	TranslationServer.add_translation(translation)
	var previous_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var dialog: SkillReplaceDialog = add_child_autofree(UpgradeDialogScene.instantiate()) as SkillReplaceDialog
	var comparison := dialog.get_node("Center/Panel/Margin/Layout/UpgradeComparison") as VBoxContainer
	var cards_row := comparison.get_node("CardsRow") as HBoxContainer
	assert_eq((cards_row.get_child(0) as Node).name, &"CurrentCard")
	assert_eq((cards_row.get_child(1) as Node).name, &"Arrow")
	assert_eq((cards_row.get_child(2) as Node).name, &"UpgradedCard")
	assert_false(comparison.has_node("ArrowRow"))
	var arrow := cards_row.get_node("Arrow") as Label
	assert_eq(arrow.text, "升级 " + String.chr(0x2192))
	for panel_path: NodePath in [
		^"CardsRow/CurrentCard",
		^"CardsRow/UpgradedCard",
		^"DescriptionsRow/CurrentDescriptionPanel",
		^"DescriptionsRow/UpgradedDescriptionPanel",
	]:
		var panel := comparison.get_node(panel_path) as Control
		assert_true(panel.get_theme_stylebox(&"panel") is StyleBoxEmpty)
	for data: Dictionary in cases:
		var item := Item.new()
		item.id = String(data[&"id"])
		item.type = int(data[&"type"])
		dialog.request_upgrade(item, 2, 3)
		assert_true(comparison.visible)
		assert_false((dialog.get_node("Center/Panel/Margin/Layout/Message") as Label).visible)
		assert_eq(
			(dialog.get_node("Center/Panel/Margin/Layout/UpgradeComparison/CardsRow/CurrentCard/Icon/LevelBadge") as Label).text,
			"II"
		)
		assert_false(
			(dialog.get_node("Center/Panel/Margin/Layout/UpgradeComparison/CardsRow/CurrentCard/Icon/LevelBadge") as Label).visible
		)
		assert_eq(
			(dialog.get_node("Center/Panel/Margin/Layout/UpgradeComparison/CardsRow/UpgradedCard/Icon/LevelBadge") as Label).text,
			"III"
		)
		assert_eq(
			(dialog.get_node("Center/Panel/Margin/Layout/UpgradeComparison/DescriptionsRow/CurrentDescriptionPanel/Margin/Description") as RichTextLabel).text,
			"%s current" % item.id
		)
		assert_eq(
			(dialog.get_node("Center/Panel/Margin/Layout/UpgradeComparison/DescriptionsRow/UpgradedDescriptionPanel/Margin/Description") as RichTextLabel).text,
			"%s upgraded" % item.id
		)
	TranslationServer.set_locale(previous_locale)
	TranslationServer.remove_translation(translation)
