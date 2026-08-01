extends Panel
class_name InventoryIconSlot

const ItemTooltipScene: PackedScene = preload("res://UI/shared/item_tooltip.tscn")

var _item: Item = null
var _level: int = 1


func set_item_tooltip(item: Item, level: int = 1) -> void:
	_item = item
	_level = clampi(level, 1, 4) if item != null else 0


func _make_custom_tooltip(_for_text: String) -> Control:
	if _item == null:
		return null
	var tooltip: ItemTooltip = ItemTooltipScene.instantiate() as ItemTooltip
	tooltip.set_item(_item, _level)
	return tooltip
