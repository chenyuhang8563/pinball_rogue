extends Control

const UI_LABEL_SETTINGS: LabelSettings = preload("res://Themes/new_label_settings.tres")
const LocaleFontSettingsScript: GDScript = preload("res://UI/locale_font_settings.gd")
const ItemLevelResolverScript: GDScript = preload("res://UI/item_level_resolver.gd")

signal gold_changed(value: int)

@export var shop_slot_node: PackedScene = preload("res://Items/slot.tscn")
@export var shop_items: Array[Item] = []
@export var shop_container: GridContainer
@export var marble_box_container: HBoxContainer
@export var relic_bar_container: HBoxContainer
var gold: int = 0:
	set(value):
		gold = value
		gold_changed.emit(value)

enum MODE {
	ON,
	OFF
}

var mode: MODE = MODE.OFF:
	set(value):
		mode = value
		if value == MODE.ON:
			refresh_collection_rows()
			$UI.show()
			get_tree().paused = true
			#if inventory
			#Inventory.grid.show()
		elif value == MODE.OFF:
			$UI.hide()
			get_tree().paused = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$UI.hide()
	_apply_text()
	_connect_locale_changed()
	var exit_button: Button = get_node_or_null("UI/Panel/ExitButton") as Button
	if exit_button != null and not exit_button.pressed.is_connected(close_shop):
		_apply_button_label_settings(exit_button)
		exit_button.pressed.connect(close_shop)
	set_initial_gold()
	load_shop_inventory()
	_connect_collection_slot_inputs()
	_connect_inventory()
	_grant_starting_marbles()
	refresh_collection_rows()

func _input(event) -> void:
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_U:
			if mode == MODE.ON:
				mode = MODE.OFF
			elif mode == MODE.OFF:
				mode = MODE.ON


func close_shop() -> void:
	mode = MODE.OFF


func _apply_button_label_settings(button: Button) -> void:
	LocaleFontSettingsScript.apply_button_font(button, UI_LABEL_SETTINGS.font_size)

func sell_item(item: Item) -> bool:
	if item == null:
		return false

	var inventory: Node = _get_autoload_node(&"Inventory")
	if inventory == null or not inventory.has_method("remove_item"):
		return false
	if not inventory.call("remove_item", item):
		return false

	gold += get_sell_price(item)
	refresh_collection_rows()
	return true

func buy_item(item: Item) -> bool:
	return purchase_item(item)


func purchase_item(item: Item) -> bool:
	if not _is_purchasable_item(item) or not shop_items.has(item):
		return false

	var inventory: Node = _get_autoload_node(&"Inventory")
	if inventory == null or not inventory.has_method("add_item"):
		return false
	if inventory.has_method("can_add_item") and not inventory.call("can_add_item", item):
		if item.type == Item.ItemType.MARBLE:
			print("弹珠槽位已满，无法获得")
		return false
	if not _spend_gold_for_item(item):
		return false
	if not inventory.call("add_item", item):
		gold += get_buy_price(item)
		return false

	_remove_shop_item(item)
	refresh_collection_rows()
	return true


func _spend_gold_for_item(item: Item) -> bool:
	if item == null:
		return false
	var buy_price: int = get_buy_price(item)
	if buy_price > gold:
		return false

	gold -= buy_price
	return true


func get_buy_price(item: Item) -> int:
	return _get_stat_price(item, "buy_price_multiplier", 1.0, true)


func get_sell_price(item: Item) -> int:
	return _get_stat_price(item, "sell_price_multiplier", 0.5, false)


func _get_stat_price(item: Item, stat_id: String, fallback_multiplier: float, round_to_nearest: bool) -> int:
	if item == null:
		return 0

	var multiplier: float = fallback_multiplier
	var stat_system: Node = _get_autoload_node(&"StatSystem")
	if stat_system != null and stat_system.has_method("get_stat"):
		multiplier = float(stat_system.call("get_stat", stat_id, "player"))

	var price: float = float(item.price) * multiplier
	return max(0, roundi(price) if round_to_nearest else floori(price))

func free_previous_slots():
	for slot in shop_container.get_children():
		if slot.is_inside_tree():
			slot.hide()
			slot.queue_free()
		else:
			shop_container.remove_child(slot)
			slot.free()

func load_shop_inventory():
	for item in shop_items:
		if not _is_purchasable_item(item):
			continue
		var shop_slot = shop_slot_node.instantiate() as Panel
		shop_container.add_child(shop_slot)
		shop_slot.item = item

func set_shop_inventory(list: Array[Item]):
	free_previous_slots()
	shop_items = _filter_purchasable_items(list)
	load_shop_inventory()

func set_initial_gold():
	gold = 100


func refresh_collection_rows() -> void:
	var inventory: Node = _get_autoload_node(&"Inventory")
	if inventory == null:
		_update_collection_icons(marble_box_container, [])
		_update_collection_icons(relic_bar_container, [])
		return

	var raw_marble_items: Variant = inventory.get("marble_items")
	var raw_relic_items: Variant = inventory.get("relic_items")
	var marble_items: Array = raw_marble_items if raw_marble_items is Array else []
	var relic_items: Array = raw_relic_items if raw_relic_items is Array else []
	_update_collection_icons(marble_box_container, marble_items)
	_update_collection_icons(relic_bar_container, relic_items)


func _update_collection_icons(container: HBoxContainer, collection_items: Array) -> void:
	if container == null:
		return

	for index: int in range(container.get_child_count()):
		var slot := container.get_child(index)
		var icon_view := slot.get_node_or_null("Icon")
		if icon_view == null:
			continue
		if slot.has_meta("item"):
			slot.remove_meta("item")
		_clear_icon_view(icon_view)
		if index < collection_items.size():
			var item: Item = collection_items[index] as Item
			if item != null:
				slot.set_meta("item", item)
				_set_icon_view_texture(icon_view, item.icon)
				_set_icon_view_level(icon_view, ItemLevelResolverScript.get_inventory_level(item))


func _remove_shop_item(item: Item) -> void:
	var index := shop_items.find(item)
	if index == -1:
		return
	shop_items.remove_at(index)
	free_previous_slots()
	load_shop_inventory()


func _connect_collection_slot_inputs() -> void:
	_connect_collection_slot_inputs_for_row(marble_box_container)
	_connect_collection_slot_inputs_for_row(relic_bar_container)


func _connect_collection_slot_inputs_for_row(container: HBoxContainer) -> void:
	if container == null:
		return

	for slot: Node in container.get_children():
		if slot.has_signal(&"gui_input"):
			var callable := Callable(self, "_on_collection_slot_gui_input").bind(slot)
			if not slot.is_connected(&"gui_input", callable):
				slot.connect(&"gui_input", callable)


func _set_icon_view_texture(icon_view: Node, texture: Texture2D) -> void:
	if icon_view == null:
		return
	if icon_view.has_method("set_texture"):
		icon_view.call("set_texture", texture)
	elif icon_view is TextureRect:
		var texture_rect := icon_view as TextureRect
		texture_rect.texture = texture
		texture_rect.visible = texture != null


func _set_icon_view_level(icon_view: Node, level: int) -> void:
	if icon_view != null and icon_view.has_method("set_level"):
		icon_view.call("set_level", level)


func _clear_icon_view(icon_view: Node) -> void:
	if icon_view == null:
		return
	if icon_view.has_method("clear"):
		icon_view.call("clear")
	elif icon_view is TextureRect:
		var texture_rect := icon_view as TextureRect
		texture_rect.texture = null
		texture_rect.hide()


func _on_collection_slot_gui_input(event: InputEvent, slot: Node) -> void:
	if mode != MODE.ON:
		return
	if not event is InputEventMouseButton:
		return
	if not event.is_pressed() or event.button_index != MOUSE_BUTTON_RIGHT:
		return
	if not slot.has_meta("item"):
		return

	var item: Item = slot.get_meta("item") as Item
	if sell_item(item):
		print("Sold " + tr(item.title))


func _grant_starting_marbles() -> void:
	var inventory: Node = _get_autoload_node(&"Inventory")
	if inventory == null or not inventory.has_method("has_effect"):
		return
	if not inventory.call("has_effect", Item.EffectType.DARK_MARBLE):
		var dark_marble_item: Item = preload("res://Resources/dark_marble.tres")
		inventory.call("add_item", dark_marble_item)


func _connect_inventory() -> void:
	var inventory: Node = _get_autoload_node(&"Inventory")
	if inventory == null or not inventory.has_signal(&"inventory_changed"):
		return
	var callable := Callable(self, "refresh_collection_rows")
	if not inventory.is_connected(&"inventory_changed", callable):
		inventory.connect(&"inventory_changed", callable)


func _get_autoload_node(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))


func _filter_purchasable_items(list: Array[Item]) -> Array[Item]:
	var purchasable_items: Array[Item] = []
	for item: Item in list:
		if _is_purchasable_item(item):
			purchasable_items.append(item)
	return purchasable_items


func _is_purchasable_item(item: Item) -> bool:
	if item == null:
		return false
	return item.type == Item.ItemType.MARBLE or item.type == Item.ItemType.RELIC


func _apply_text() -> void:
	var title_label: Label = get_node_or_null("UI/Panel/Label") as Label
	if title_label != null:
		title_label.text = tr("UI_SHOP_TITLE")
	var exit_button: Button = get_node_or_null("UI/Panel/ExitButton") as Button
	if exit_button != null:
		exit_button.text = tr("UI_EXIT")


func _connect_locale_changed() -> void:
	var localization: Node = _get_autoload_node(&"Localization")
	var callback := Callable(self, "_on_locale_changed")
	if localization != null and localization.has_signal(&"locale_changed") and not localization.is_connected(&"locale_changed", callback):
		localization.connect(&"locale_changed", callback)
	if TranslationServer.has_signal(&"locale_changed") and not TranslationServer.is_connected(&"locale_changed", callback):
		TranslationServer.connect(&"locale_changed", callback)


func _on_locale_changed(_locale_code: String = "") -> void:
	_apply_text()
	var exit_button: Button = get_node_or_null("UI/Panel/ExitButton") as Button
	if exit_button != null:
		_apply_button_label_settings(exit_button)
