class_name RarityStyleResolver
extends RefCounted

const COMMON: StyleBox = preload("res://Themes/RarityBorders/common.tres")
const UNCOMMON: StyleBox = preload("res://Themes/RarityBorders/uncommon.tres")
const RARE: StyleBox = preload("res://Themes/RarityBorders/rare.tres")
const BOSS: StyleBox = preload("res://Themes/RarityBorders/boss.tres")
const CURSE: StyleBox = preload("res://Themes/RarityBorders/curse.tres")


static func for_item(item: Item) -> StyleBox:
	if item == null:
		return COMMON
	match item.rarity:
		Item.Rarity.UNCOMMON:
			return UNCOMMON
		Item.Rarity.RARE:
			return RARE
		Item.Rarity.BOSS:
			return BOSS
		Item.Rarity.CURSE:
			return CURSE
		_:
			return COMMON


static func apply_to(slot: Control, item: Item) -> void:
	if slot != null:
		slot.add_theme_stylebox_override(&"panel", for_item(item))
