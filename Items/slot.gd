extends Panel

const SHOP_MODE_ON := 0
const ItemTooltipScene: PackedScene = preload("res://UI/item_tooltip.tscn")

@export var item: Item = null:
	set(value):
		item = value

		if value == null:
			_set_icon_texture(null)
			return

		_set_icon_texture(value.icon)
		$Price.text = "$ " + str(value.price)
		refresh_localized_content()


func _ready() -> void:
		_connect_localization()
		refresh_localized_content()


func refresh_localized_content() -> void:
	if item == null:
		return
	var title_label := get_node_or_null("Title") as Label
	if title_label != null:
		title_label.text = _item_title(item)
	var type_label := get_node_or_null("Type") as Label
	if type_label != null:
		type_label.text = _item_type_text(item)


func _connect_localization() -> void:
	var localization: Node = _get_autoload_node(&"Localization")
	if localization == null or not localization.has_signal(&"locale_changed"):
		return
	var callback := Callable(self, "_on_locale_changed")
	if not localization.is_connected(&"locale_changed", callback):
		localization.connect(&"locale_changed", callback)


func _on_locale_changed(_locale_code: String) -> void:
	refresh_localized_content()

func _on_gui_input(event) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.is_pressed() or event.button_index != MOUSE_BUTTON_LEFT:
		return

	var shop: Node = _get_autoload_node(&"Shop")
	if shop == null or shop.get("mode") != SHOP_MODE_ON:
		return

	var inventory: Node = _get_autoload_node(&"Inventory")
	if inventory == null:
		return

	if shop.has_method("purchase_item"):
		if shop.call("purchase_item", item):
			print("Bought " + item.title)
		return


func _get_autoload_node(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))


func _make_custom_tooltip(_for_text: String) -> Control:
	if item == null:
		return null
	var tooltip: ItemTooltip = ItemTooltipScene.instantiate() as ItemTooltip
	tooltip.set_item(item)
	return tooltip


func _set_icon_texture(texture: Texture2D) -> void:
	var icon: Node = get_node_or_null("Icon")
	if icon == null:
		return
	if icon.has_method("set_texture"):
		icon.call("set_texture", texture)
	elif icon is TextureRect:
		var texture_rect := icon as TextureRect
		texture_rect.texture = texture


func _item_title(value: Item) -> String:
	if value == null:
		return ""
	if value.skill_definition != null:
		return tr(String(value.skill_definition.get("name_key")))
	var key := "ITEM_%s_TITLE" % value.id.to_upper()
	var translated := tr(key)
	return translated if translated != key else tr(value.title)


func _item_type_text(value: Item) -> String:
	if value == null:
		return ""
	match value.type:
		Item.ItemType.SKILL:
			return tr("UI_SKILL_TYPE")
		Item.ItemType.RELIC:
			return tr("UI_RELIC_TYPE")
		Item.ItemType.MARBLE:
			return tr("UI_MARBLE_TYPE")
	return tr("UI_EMPTY")
