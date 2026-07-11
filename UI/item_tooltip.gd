extends PanelContainer
class_name ItemTooltip

var _title_label: Label
var _description_label: Label


func set_item(item: Item) -> void:
	if item == null:
		set_text("")
		return
	set_text(
		_translated_item_text(item, "TITLE", item.title),
		_translated_item_text(item, "DESC", item.description)
	)


func set_text(title: String, description: String = "") -> void:
	_bind_nodes()
	if _title_label != null:
		_title_label.text = title
	if _description_label != null:
		_description_label.text = description


func _bind_nodes() -> void:
	if _title_label != null:
		return
	_title_label = get_node_or_null("TooltipMargin/TooltipLayout/TooltipLabel") as Label
	_description_label = get_node_or_null("TooltipMargin/TooltipLayout/DescriptionLabel") as Label


func _translated_item_text(item: Item, suffix: String, fallback: String) -> String:
	if item.id.is_empty():
		return tr(fallback)
	var key: String = "ITEM_%s_%s" % [item.id.to_upper(), suffix]
	var translated: String = tr(key)
	return translated if translated != key else tr(fallback)
