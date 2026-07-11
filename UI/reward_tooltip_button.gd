extends Button
class_name RewardTooltipButton

const ItemTooltipScene: PackedScene = preload("res://UI/item_tooltip.tscn")

var _item: Item
var _title: String = ""


func set_item_tooltip(item: Item) -> void:
	_item = item
	_title = ""


func set_text_tooltip(title: String) -> void:
	_item = null
	_title = title


func _make_custom_tooltip(_for_text: String) -> Control:
	if _item == null and _title.is_empty():
		return null
	var tooltip: ItemTooltip = ItemTooltipScene.instantiate() as ItemTooltip
	if _item != null:
		tooltip.set_item(_item)
	else:
		tooltip.set_text(_title)
	return tooltip
