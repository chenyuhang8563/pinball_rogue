extends Control

const UIFontsScript: GDScript = preload("res://UI/fonts.gd")
const UI_FONT_SIZE: int = 12
const ItemLevelResolverScript: GDScript = preload("res://UI/item_level_resolver.gd")
const ShopOfferScript: GDScript = preload("res://Shop/shop_offer.gd")
const ShopItemPolicyScript: GDScript = preload("res://Shop/shop_item_policy.gd")
const SHOP_SLOT_COUNT: int = 6

signal gold_changed(value: int)

@export var shop_slot_node: PackedScene = preload("res://Items/slot.tscn")
@export var shop_item_pool: Array[Item] = []
@export var shop_items: Array[Item] = []
var shop_offers: Array = []
@export var shop_container: GridContainer
@export var marble_box_container: HBoxContainer
@export var relic_bar_container: HBoxContainer
@export var skill_box_container: HBoxContainer
@export var skill_replace_dialog: SkillReplaceDialog
var resource_hud: BattleHealthHud
var gold: int = 0:
	set(value):
		gold = value
		gold_changed.emit(value)
		if resource_hud != null:
			resource_hud.set_gold(value)

var _pending_skill_purchase: Item = null
var _pending_skill_offer: Variant = null

enum MODE {
	ON,
	OFF
}

var mode: MODE = MODE.OFF:
	set(value):
		var previous_mode: MODE = mode
		mode = value
		if value == MODE.ON:
			if previous_mode != MODE.ON:
				refresh_shop_inventory()
			_connect_run_controller_health()
			_sync_resource_hud()
			_apply_text()
			refresh_collection_rows()
			var ui: CanvasLayer = get_node_or_null("UI") as CanvasLayer
			if ui != null:
				ui.show()
			if is_inside_tree():
				get_tree().paused = true
		elif value == MODE.OFF:
			var ui: CanvasLayer = get_node_or_null("UI") as CanvasLayer
			if ui != null:
				ui.hide()
			if is_inside_tree():
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
	refresh_shop_inventory()
	_connect_collection_slot_inputs()
	_connect_inventory()
	_connect_skill_replace_dialog()
	_grant_starting_marbles()
	refresh_collection_rows()
	_sync_resource_hud()


func _bind_optional_nodes() -> void:
	if skill_box_container == null:
		skill_box_container = get_node_or_null("UI/Panel/CollectionRows/SkillBox") as HBoxContainer
	if skill_replace_dialog == null:
		skill_replace_dialog = get_node_or_null("UI/Panel/SkillReplaceDialog") as SkillReplaceDialog
	if resource_hud == null:
		resource_hud = get_node_or_null("UI/Panel/ShopResourceHud") as BattleHealthHud

func _input(event) -> void:
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_U:
			if mode == MODE.ON:
				mode = MODE.OFF
			elif mode == MODE.OFF:
				mode = MODE.ON


func close_shop() -> void:
	cancel_pending_skill_purchase()
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
	var inventory: Node = _get_autoload_node(&"Inventory")
	return sell_item_with_dependencies(item, inventory, _get_marble_upgrade_system())


## 出售物品后同步清理其成长状态，并按最新库存重建报价。
func sell_item_with_dependencies(item: Item, inventory: Node, marble_upgrade_system: Node) -> bool:
	if item == null or item.type == Item.ItemType.SKILL:
		return false
	if inventory == null or not inventory.has_method("remove_item"):
		return false
	if not bool(inventory.call("remove_item", item)):
		return false
	if item.type == Item.ItemType.MARBLE and marble_upgrade_system != null \
			and marble_upgrade_system.has_method("reset_marble_level"):
		marble_upgrade_system.call("reset_marble_level", item.marble_type)
	gold += get_sell_price(item)
	if not shop_item_pool.is_empty():
		set_upgrade_offers(generate_upgrade_offers(shop_item_pool, inventory, marble_upgrade_system))
	refresh_collection_rows()
	return true

func buy_item(item: Item) -> bool:
	return purchase_item(item)


## 为已拥有物品创建原价、升一级的升级报价。
func create_upgrade_offer(item: Item, inventory: Node, marble_upgrade_system: Node):
	var owned_item := _find_owned_matching_item(item, inventory)
	if owned_item == null or marble_upgrade_system == null:
		return null
	if not marble_upgrade_system.has_method("can_upgrade_item"):
		return null
	if not bool(marble_upgrade_system.call("can_upgrade_item", owned_item, inventory)):
		return null
	var current_level := _get_item_level(owned_item, inventory, marble_upgrade_system)
	if current_level <= 0:
		return null
	return ShopOfferScript.new(owned_item, current_level + 1, get_buy_price(item), true)


## 将候选转换成新商品或同一物品升级报价；满级同物不再出售。
func create_shop_offer(item: Item, inventory: Node, marble_upgrade_system: Node):
	if not _is_purchasable_item(item):
		return null
	if _find_owned_matching_item(item, inventory) == null:
		return ShopOfferScript.new(item, 1, get_buy_price(item), false)
	return create_upgrade_offer(item, inventory, marble_upgrade_system)


## Replaces the normal-shop stock with upgrade quotes and preserves legacy item stock for other callers.
func set_upgrade_offers(offers: Array) -> void:
	cancel_pending_skill_purchase()
	shop_offers = offers.duplicate()
	shop_items.clear()
	for offer in shop_offers:
		if offer != null and offer.item != null:
			shop_items.append(offer.item)
	free_previous_slots()
	load_shop_inventory()


## Purchases an upgrade quote using the runtime dependencies resolved from the active run.
func purchase_offer(offer: Variant) -> bool:
	var inventory: Node = _get_autoload_node(&"Inventory")
	var marble_upgrade_system: Node = _get_marble_upgrade_system()
	return purchase_offer_with_dependencies(offer, inventory, marble_upgrade_system)


## 按报价购买新商品或升级，成功后同步移除同一索引的商品与报价。
func purchase_offer_with_dependencies(offer: Variant, inventory: Node, marble_upgrade_system: Node) -> bool:
	if offer == null or not shop_offers.has(offer) or inventory == null:
		return false
	if offer.item == null or offer.price > gold:
		return false
	if offer.is_upgrade:
		if marble_upgrade_system == null:
			return false
		var owned_item := _find_owned_matching_item(offer.item, inventory)
		if owned_item == null:
			return false
		if _get_item_level(owned_item, inventory, marble_upgrade_system) + 1 != offer.target_level:
			return false
		if not bool(marble_upgrade_system.call("upgrade_item", owned_item, inventory)):
			return false
	else:
		if _find_owned_matching_item(offer.item, inventory) != null:
			return false
		if offer.item.type == Item.ItemType.SKILL and inventory.get("skill_item") != null:
			_pending_skill_offer = offer
			var current_skill := inventory.get("skill_item") as Item
			if skill_replace_dialog != null:
				skill_replace_dialog.request_replace(current_skill, offer.item)
			return false
		if inventory.has_method("can_add_item") and not bool(inventory.call("can_add_item", offer.item)):
			return false
		if not bool(inventory.call("add_item", offer.item)):
			return false
	gold -= offer.price
	_remove_shop_offer(offer)
	refresh_collection_rows()
	return true


func purchase_item(item: Item) -> bool:
	if not _is_purchasable_item(item) or not shop_items.has(item):
		return false

	var inventory: Node = _get_autoload_node(&"Inventory")
	if inventory == null or not inventory.has_method("add_item"):
		return false
	var marble_upgrade_system: Node = _get_marble_upgrade_system() if item.type == Item.ItemType.MARBLE else null
	return purchase_item_with_dependencies(item, inventory, marble_upgrade_system)


func purchase_item_with_dependencies(item: Item, inventory: Node, marble_upgrade_system: Node = null) -> bool:
	if not _is_purchasable_item(item) or not shop_items.has(item) or inventory == null:
		return false
	if item.type == Item.ItemType.SKILL:
		return _request_skill_purchase(item, inventory)
	if item.type == Item.ItemType.MARBLE and _inventory_has_marble_type(inventory, item.marble_type):
		return _purchase_owned_marble(item, inventory, marble_upgrade_system)
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


func _purchase_owned_marble(item: Item, inventory: Node, marble_upgrade_system: Node) -> bool:
	if marble_upgrade_system == null or not marble_upgrade_system.has_method("upgrade_item"):
		return false
	if not _spend_gold_for_item(item):
		return false
	if not bool(marble_upgrade_system.call("upgrade_item", item, inventory)):
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
	var pending_offer: Variant = _pending_skill_offer
	_pending_skill_offer = null
	var item: Item = pending_offer.item as Item if pending_offer != null else _pending_skill_purchase
	_pending_skill_purchase = null
	if item == null or not shop_items.has(item):
		return false
	if pending_offer != null and not shop_offers.has(pending_offer):
		return false
	var inventory := _get_autoload_node(&"Inventory")
	if inventory == null or not inventory.has_method("replace_skill"):
		return false
	var price: int = int(pending_offer.price) if pending_offer != null else get_buy_price(item)
	if price > gold:
		return false
	var previous_skill := inventory.get("skill_item") as Item
	if not bool(inventory.call("replace_skill", item)):
		return false
	var marble_upgrade_system := _get_marble_upgrade_system()
	if previous_skill != null and marble_upgrade_system != null and marble_upgrade_system.has_method("reset_skill_level"):
		marble_upgrade_system.call("reset_skill_level", previous_skill.id)
	gold -= price
	if pending_offer != null:
		_remove_shop_offer(pending_offer)
	else:
		_remove_shop_item(item)
	refresh_collection_rows()
	return true


func cancel_pending_skill_purchase() -> void:
	_pending_skill_purchase = null
	_pending_skill_offer = null
	if skill_replace_dialog != null and skill_replace_dialog.is_request_pending():
		skill_replace_dialog.cancel_replace_request()


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


func can_afford_item(item: Item) -> bool:
	return item != null and gold >= get_buy_price(item)


## Returns whether the player can pay this quote's actual price.
func can_afford_offer(offer: Variant) -> bool:
	return offer != null and gold >= offer.price


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
	if shop_container == null:
		return
	for slot in shop_container.get_children():
		if slot.is_inside_tree():
			slot.hide()
			slot.queue_free()
		else:
			shop_container.remove_child(slot)
			slot.free()

func load_shop_inventory():
	if shop_container == null or shop_slot_node == null:
		return
	for offer_index: int in range(shop_items.size()):
		var item: Item = shop_items[offer_index]
		if not _is_purchasable_item(item):
			continue
		var shop_slot = shop_slot_node.instantiate() as Panel
		shop_container.add_child(shop_slot)
		var offer: Variant = shop_offers[offer_index] if offer_index < shop_offers.size() else null
		if offer != null and shop_slot.has_method("set_offer"):
			shop_slot.call("set_offer", offer)
		else:
			shop_slot.item = item

func set_shop_inventory(list: Array[Item]):
	cancel_pending_skill_purchase()
	free_previous_slots()
	shop_offers.clear()
	shop_items = _filter_purchasable_items(list)
	load_shop_inventory()


func refresh_shop_inventory() -> void:
	if shop_item_pool.is_empty():
		shop_item_pool = shop_items.duplicate()
	var inventory: Node = _get_autoload_node(&"Inventory")
	set_upgrade_offers(generate_upgrade_offers(shop_item_pool, inventory, _get_marble_upgrade_system()))


## 生成混合库存：新物品保留，已有物转成升级报价，满级同物过滤后由其他候选补位。
func generate_upgrade_offers(candidates: Array, inventory: Node, marble_upgrade_system: Node) -> Array:
	var available_offers: Array = []
	for candidate_value in candidates:
		var candidate := candidate_value as Item
		if candidate == null:
			continue
		var offer: Variant = create_shop_offer(candidate, inventory, marble_upgrade_system)
		if offer == null:
			continue
		var already_listed := false
		for existing_offer in available_offers:
			if _items_have_same_identity(existing_offer.item, offer.item):
				already_listed = true
				break
		if not already_listed:
			available_offers.append(offer)
	var selected_offers: Array = []
	for item_type: Item.ItemType in [Item.ItemType.RELIC, Item.ItemType.MARBLE, Item.ItemType.SKILL]:
		var category_offers: Array = []
		for offer in available_offers:
			if offer.item.type == item_type:
				category_offers.append(offer)
		if not category_offers.is_empty():
			selected_offers.append(category_offers.pick_random())
	var remaining_offers: Array = []
	for offer in available_offers:
		if not selected_offers.has(offer):
			remaining_offers.append(offer)
	var target_count := mini(SHOP_SLOT_COUNT, available_offers.size())
	while selected_offers.size() < target_count and not remaining_offers.is_empty():
		selected_offers.append(remaining_offers.pop_at(randi_range(0, remaining_offers.size() - 1)))
	selected_offers.shuffle()
	return selected_offers


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


func _remove_shop_offer(offer: Variant) -> void:
	var offer_index := shop_offers.find(offer)
	if offer_index == -1:
		return
	shop_offers.remove_at(offer_index)
	var item_index := shop_items.find(offer.item)
	if item_index != -1:
		shop_items.remove_at(item_index)
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


func _connect_run_controller_health() -> void:
	var run_controller: Node = _get_run_controller()
	if run_controller == null or not run_controller.has_signal(&"run_health_changed"):
		return
	var callback := Callable(self, "_on_run_health_changed")
	if not run_controller.is_connected(&"run_health_changed", callback):
		run_controller.connect(&"run_health_changed", callback)


func _sync_resource_hud() -> void:
	if resource_hud == null:
		return
	resource_hud.set_gold(gold)
	var run_controller: Node = _get_run_controller()
	if run_controller != null and run_controller.has_method("_get_run_health"):
		resource_hud.set_health(int(run_controller.call("_get_run_health")))


func _on_run_health_changed(value: int) -> void:
	if resource_hud != null:
		resource_hud.set_health(value)


func _on_skill_replace_confirmed(_item: Item) -> void:
	confirm_pending_skill_purchase()


func _get_autoload_node(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))


func _get_run_controller() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var candidates: Array[Node] = []
	if tree.current_scene != null:
		candidates.append(tree.current_scene)
	candidates.append(tree.root)
	for candidate: Node in candidates:
		var direct: Node = candidate.get_node_or_null("RunController")
		if _is_live_node(direct):
			return direct
		for run_controller: Node in candidate.find_children("RunController", "", true, false):
			if _is_live_node(run_controller):
				return run_controller
	return null


func _get_marble_upgrade_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var candidates: Array[Node] = []
	if tree.current_scene != null:
		candidates.append(tree.current_scene)
	candidates.append(tree.root)
	for candidate: Node in candidates:
		var direct: Node = candidate.get_node_or_null("RunController/MarbleUpgradeSystem")
		if _is_live_node(direct):
			return direct
		for run_controller: Node in candidate.find_children("RunController", "", true, false):
			if not _is_live_node(run_controller):
				continue
			var system: Node = run_controller.get_node_or_null("MarbleUpgradeSystem")
			if _is_live_node(system):
				return system
	return null


func _is_live_node(node: Node) -> bool:
	var current: Node = node
	while current != null:
		if current.is_queued_for_deletion():
			return false
		current = current.get_parent()
	return node != null


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


func _inventory_has_marble_type(inventory: Node, marble_type: Marble.MARBLE_TYPE) -> bool:
	return _find_owned_matching_item_by_marble_type(inventory, marble_type) != null


func _find_owned_matching_item(item: Item, inventory: Node) -> Item:
	return ShopItemPolicyScript.find_owned_item(item, inventory)


func _find_owned_matching_item_by_marble_type(inventory: Node, marble_type: Marble.MARBLE_TYPE) -> Item:
	if inventory == null:
		return null
	var raw_marble_items: Variant = inventory.get("marble_items")
	if not raw_marble_items is Array:
		return null
	for owned_item: Item in raw_marble_items as Array:
		if owned_item != null and owned_item.type == Item.ItemType.MARBLE and owned_item.marble_type == marble_type:
			return owned_item
	return null


func _items_have_same_identity(first: Item, second: Item) -> bool:
	return ShopItemPolicyScript.has_same_identity(first, second)


func _get_item_level(item: Item, inventory: Node, marble_upgrade_system: Node) -> int:
	return ShopItemPolicyScript.get_level(item, inventory, marble_upgrade_system)


func _is_purchasable_item(item: Item) -> bool:
	if item == null:
		return false
	return item.type == Item.ItemType.MARBLE or item.type == Item.ItemType.RELIC or item.type == Item.ItemType.SKILL
