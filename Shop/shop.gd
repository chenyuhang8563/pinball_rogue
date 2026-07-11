extends Control

const UIFontsScript: GDScript = preload("res://UI/fonts.gd")
const UI_FONT_SIZE: int = 12
const ItemLevelResolverScript: GDScript = preload("res://UI/item_level_resolver.gd")

signal gold_changed(value: int)

@export var shop_slot_node: PackedScene = preload("res://Items/slot.tscn")
@export var shop_items: Array[Item] = []
@export var shop_container: GridContainer
@export var marble_box_container: HBoxContainer
@export var relic_bar_container: HBoxContainer
@export var skill_box_container: HBoxContainer
@export var skill_replace_dialog: SkillReplaceDialog
var gold: int = 0:
	set(value):
		gold = value
		gold_changed.emit(value)

var _pending_skill_purchase: Item = null

enum MODE {
	ON,
	OFF
}

var mode: MODE = MODE.OFF:
	set(value):
		mode = value
		if value == MODE.ON:
			_apply_text()
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
	_bind_optional_nodes()
	$UI.hide()
	_connect_localization()
	_apply_text()
	var exit_button: Button = get_node_or_null("UI/Panel/ExitButton") as Button
	if exit_button != null and not exit_button.pressed.is_connected(close_shop):
		_apply_button_label_settings(exit_button)
		exit_button.pressed.connect(close_shop)
	set_initial_gold()
	load_shop_inventory()
	_connect_collection_slot_inputs()
	_connect_inventory()
	_connect_skill_replace_dialog()
	_grant_starting_marbles()
	refresh_collection_rows()


func _bind_optional_nodes() -> void:
	if skill_box_container == null:
		skill_box_container = get_node_or_null("UI/Panel/CollectionRows/SkillBox") as HBoxContainer
	if skill_replace_dialog == null:
		skill_replace_dialog = get_node_or_null("UI/Panel/SkillReplaceDialog") as SkillReplaceDialog

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
		UIFontsScript.apply_button_font(button, UI_FONT_SIZE)


func _apply_text() -> void:
	var title_label: Label = get_node_or_null("UI/Panel/Label") as Label
	if title_label != null:
		title_label.text = tr("UI_SHOP_TITLE")
	var exit_button: Button = get_node_or_null("UI/Panel/ExitButton") as Button
	if exit_button != null:
		exit_button.text = tr("UI_EXIT")
		_apply_button_label_settings(exit_button)

func sell_item(item: Item) -> bool:
	if item == null:
		return false
	if item.type == Item.ItemType.SKILL:
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
	if item.type == Item.ItemType.SKILL:
		return _request_skill_purchase(item, inventory)
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


func _request_skill_purchase(item: Item, inventory: Node) -> bool:
	if item == null or item.type != Item.ItemType.SKILL:
		return false
	if item.id != "" and inventory.has_method("has_item_id") and bool(inventory.call("has_item_id", item.id)):
		return false
	if get_buy_price(item) > gold:
		return false
	var current_skill: Item = inventory.get("skill_item") as Item
	if current_skill == null:
		if not inventory.call("add_item", item):
			return false
		gold -= get_buy_price(item)
		_remove_shop_item(item)
		refresh_collection_rows()
		return true
	_pending_skill_purchase = item
	if skill_replace_dialog != null:
		skill_replace_dialog.request_replace(current_skill, item)
	return false


func confirm_pending_skill_purchase() -> bool:
	var item := _pending_skill_purchase
	_pending_skill_purchase = null
	if item == null or not shop_items.has(item):
		return false
	var inventory := _get_autoload_node(&"Inventory")
	if inventory == null or not inventory.has_method("replace_skill"):
		return false
	var price := get_buy_price(item)
	if price > gold or not bool(inventory.call("replace_skill", item)):
		return false
	gold -= price
	_remove_shop_item(item)
	refresh_collection_rows()
	return true


func cancel_pending_skill_purchase() -> void:
	_pending_skill_purchase = null


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
		_update_collection_icons(skill_box_container, [])
		return

	var raw_marble_items: Variant = inventory.get("marble_items")
	var raw_relic_items: Variant = inventory.get("relic_items")
	var raw_skill_items: Variant = inventory.get("skill_items")
	var marble_items: Array = raw_marble_items if raw_marble_items is Array else []
	var relic_items: Array = raw_relic_items if raw_relic_items is Array else []
	var skill_items: Array = raw_skill_items if raw_skill_items is Array else []
	_update_collection_icons(marble_box_container, marble_items)
	_update_collection_icons(relic_bar_container, relic_items)
	_update_collection_icons(skill_box_container, skill_items)


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
	_connect_collection_slot_inputs_for_row(skill_box_container)


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
		print("Sold " + item.title)


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


func _connect_skill_replace_dialog() -> void:
	if skill_replace_dialog == null:
		return
	var confirm_callback := Callable(self, "_on_skill_replace_confirmed")
	if not skill_replace_dialog.confirmed.is_connected(confirm_callback):
		skill_replace_dialog.confirmed.connect(confirm_callback)
	var cancel_callback := Callable(self, "cancel_pending_skill_purchase")
	if not skill_replace_dialog.cancelled.is_connected(cancel_callback):
		skill_replace_dialog.cancelled.connect(cancel_callback)


func _on_skill_replace_confirmed(_item: Item) -> void:
	confirm_pending_skill_purchase()


func _get_autoload_node(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))


func _connect_localization() -> void:
	var localization := _get_autoload_node(&"Localization")
	if localization == null or not localization.has_signal(&"locale_changed"):
		return
	var callback := Callable(self, "_on_locale_changed")
	if not localization.is_connected(&"locale_changed", callback):
		localization.connect(&"locale_changed", callback)


func _on_locale_changed(_locale_code: String) -> void:
	_apply_text()


func _filter_purchasable_items(list: Array[Item]) -> Array[Item]:
	var purchasable_items: Array[Item] = []
	for item: Item in list:
		if _is_purchasable_item(item):
			purchasable_items.append(item)
	return purchasable_items


func _is_purchasable_item(item: Item) -> bool:
	if item == null:
		return false
	return item.type == Item.ItemType.MARBLE or item.type == Item.ItemType.RELIC or item.type == Item.ItemType.SKILL
