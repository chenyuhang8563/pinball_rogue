extends Button
class_name RewardTooltipButton

const ItemTooltipScene: PackedScene = preload("res://UI/shared/item_tooltip.tscn")

var _item: Item
var _title: String = ""
var _level: int = 1


func set_item_tooltip(item: Item, level: int = 1) -> void:
	_item = item
	_title = ""
	_level = maxi(1, level)


func set_text_tooltip(title: String) -> void:
	_item = null
	_title = title
	_level = 1


func _make_custom_tooltip(_for_text: String) -> Control:
	if _item == null and _title.is_empty():
		return null
	var tooltip: ItemTooltip = ItemTooltipScene.instantiate() as ItemTooltip
	if _item != null:
		tooltip.set_item(_item, _level)
	else:
		tooltip.set_text(_title)
	return tooltip
