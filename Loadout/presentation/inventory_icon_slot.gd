extends Panel
class_name InventoryIconSlot

const ItemTooltipScene: PackedScene = preload("res://UI/shared/item_tooltip.tscn")

var _item: Item = null
var _level: int = 1


func set_item_tooltip(item: Item, level: int) -> void:
	_item = item
	_level = maxi(1, level)


func _make_custom_tooltip(_for_text: String) -> Control:
	if _item == null:
		return null
	var tooltip: ItemTooltip = ItemTooltipScene.instantiate() as ItemTooltip
	tooltip.set_item(_item, _level)
	return tooltip
