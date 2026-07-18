extends Control

const UIFontsScript: GDScript = preload("res://UI/fonts.gd")
const UI_FONT_SIZE: int = 12
const ItemLevelResolverScript: GDScript = preload("res://UI/item_level_resolver.gd")
const NormalShopSessionScript: GDScript = preload("res://Commerce/application/normal_shop_session.gd")
const NormalShopSaleServiceScript: GDScript = preload("res://Commerce/application/normal_shop_sale_service.gd")
const CurrentInventoryAdapterScript: GDScript = preload("res://Commerce/application/adapters/current_inventory_adapter.gd")
const CurrentProgressionAdapterScript: GDScript = preload("res://Commerce/application/adapters/current_progression_adapter.gd")
const CurrentWalletAdapterScript: GDScript = preload("res://Commerce/application/adapters/current_wallet_adapter.gd")
const ItemIdentityScript: GDScript = preload("res://Commerce/domain/item_identity.gd")
const NormalShopPricingScript: GDScript = preload("res://Commerce/domain/normal_shop_pricing.gd")
const PurchaseResultScript: GDScript = preload("res://Commerce/domain/purchase_result.gd")
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
var gold: int = 0:
	set(value):
		gold = value
		gold_changed.emit(value)
		_refresh_slot_affordability()

var normal_shop_session: RefCounted = null
var normal_shop_sale_service: RefCounted = null
var current_inventory_adapter: RefCounted = null
var current_progression_adapter: RefCounted = null
var current_wallet_adapter: RefCounted = null

var _commerce_inventory: Node = null
var _commerce_progression: Node = null
var _commerce_quote_sources: Dictionary = {}
var _pending_skill_offer_id: StringName = &""

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
	if normal_shop_sale_service == null and not _configure_from_runtime_fallback():
		return false
	return _sell_item(item)


func _sell_item(item: Item) -> bool:
	if normal_shop_sale_service == null or normal_shop_session == null:
		return false
	var result: RefCounted = normal_shop_sale_service.call("sell", item)
	if int(result.get("code")) != PurchaseResultScript.Code.SUCCESS \
			or not bool(result.get("committed")):
		_handle_failed_result(result)
		return false
	normal_shop_session.call("invalidate_snapshot")
	_regenerate_from_pool(true)
	refresh_collection_rows()
	return true


func configure(inventory: Node, progression: Node) -> bool:
	return _configure_commerce(inventory, progression)


func _configure_commerce(inventory: Node, marble_upgrade_system: Node) -> bool:
	if inventory == null or marble_upgrade_system == null:
		return false
	if normal_shop_session != null or normal_shop_sale_service != null:
		return normal_shop_session != null and normal_shop_sale_service != null \
			and inventory == _commerce_inventory \
			and marble_upgrade_system == _commerce_progression
	_commerce_inventory = inventory
	_commerce_progression = marble_upgrade_system
	current_inventory_adapter = CurrentInventoryAdapterScript.new(inventory)
	current_progression_adapter = CurrentProgressionAdapterScript.new(
		marble_upgrade_system,
		current_inventory_adapter
	)
	current_wallet_adapter = CurrentWalletAdapterScript.new(
		self,
		Callable(self, "_quote_commerce_item"),
		Callable(self, "get_sell_price")
	)
	normal_shop_session = NormalShopSessionScript.new()
	normal_shop_sale_service = NormalShopSaleServiceScript.new()
	var session_configured := bool(normal_shop_session.call(
		"configure",
		current_inventory_adapter,
		current_progression_adapter,
		current_wallet_adapter
	))
	var sale_configured := bool(normal_shop_sale_service.call(
		"configure",
		current_inventory_adapter,
		current_progression_adapter,
		current_wallet_adapter
	))
	var configured := session_configured and sale_configured
	if not configured:
		normal_shop_session = null
		normal_shop_sale_service = null
	return configured


func _configure_from_runtime_fallback() -> bool:
	var inventory: Node = _get_autoload_node(&"Inventory")
	var progression: Node = _get_marble_upgrade_system()
	return _configure_commerce(inventory, progression)


## Purchases an upgrade quote using the runtime dependencies resolved from the active run.
func purchase_offer(offer: Variant) -> bool:
	if offer == null:
		return false
	if normal_shop_session == null and not _configure_from_runtime_fallback():
		return false
	var offer_id := StringName(offer.get("offer_id"))
	return offer_id != &"" and _purchase_offer_id(offer_id)


func confirm_pending_skill_purchase() -> bool:
	var offer_id := _pending_skill_offer_id
	_pending_skill_offer_id = &""
	if offer_id == &"" or normal_shop_session == null:
		return false
	if not bool(normal_shop_session.call("authorize_skill_replacement", offer_id)):
		return false
	return _purchase_offer_id(offer_id)


func cancel_pending_skill_purchase() -> void:
	_pending_skill_offer_id = &""
	if skill_replace_dialog != null and skill_replace_dialog.is_request_pending():
		skill_replace_dialog.cancel_replace_request()


func _purchase_offer_id(offer_id: StringName) -> bool:
	if normal_shop_session == null or offer_id == &"":
		return false
	var offer: Variant = _find_session_offer_by_id(offer_id)
	var result: RefCounted = normal_shop_session.call("purchase", offer_id)
	var code := int(result.get("code"))
	if code == PurchaseResultScript.Code.SUCCESS and bool(result.get("committed")):
		_pending_skill_offer_id = &""
		_sync_presentation_from_session()
		refresh_collection_rows()
		return true
	if code == PurchaseResultScript.Code.SKILL_REPLACEMENT_REQUIRED and offer != null:
		_request_skill_replacement(offer_id, offer)
		return false
	_handle_failed_result(result)
	return false


func _request_skill_replacement(offer_id: StringName, offer: Variant) -> void:
	_pending_skill_offer_id = offer_id
	var current_skill: Item = null
	if current_inventory_adapter != null:
		current_skill = current_inventory_adapter.call("current_skill") as Item
	if skill_replace_dialog != null:
		skill_replace_dialog.request_replace(current_skill, offer.item)


func _handle_failed_result(result: RefCounted) -> void:
	if result == null:
		_set_presentation_offers([])
		return
	match int(result.get("code")):
		PurchaseResultScript.Code.STALE_SNAPSHOT, \
		PurchaseResultScript.Code.OWNERSHIP_CHANGED, \
		PurchaseResultScript.Code.LEVEL_CHANGED, \
		PurchaseResultScript.Code.CAPACITY_CHANGED:
			if shop_item_pool.is_empty():
				_set_presentation_offers([])
			else:
				_regenerate_from_pool(false)
		PurchaseResultScript.Code.INSUFFICIENT_FUNDS:
			_refresh_slot_affordability()
		PurchaseResultScript.Code.COMMIT_FAILED:
			if bool(result.get("rollback_completed")):
				_sync_balance_from_wallet()
				_sync_presentation_from_session()
				refresh_collection_rows()
			else:
				_set_presentation_offers([])
		PurchaseResultScript.Code.ROLLBACK_FAILED:
			_set_presentation_offers([])
		PurchaseResultScript.Code.OFFER_CONSUMED:
			_sync_presentation_from_session()
		PurchaseResultScript.Code.UNKNOWN_OFFER, PurchaseResultScript.Code.NOT_CONFIGURED:
			_set_presentation_offers([])
		_:
			_sync_presentation_from_session()


func _sync_balance_from_wallet() -> void:
	if current_wallet_adapter != null:
		gold = int(current_wallet_adapter.call("balance"))


func _regenerate_from_pool(regenerate_empty_pool: bool) -> void:
	if normal_shop_session == null:
		_set_presentation_offers([])
		return
	if shop_item_pool.is_empty() and not regenerate_empty_pool:
		_set_presentation_offers([])
		return
	_set_commerce_quote_sources(shop_item_pool)
	normal_shop_session.call("regenerate", shop_item_pool, SHOP_SLOT_COUNT)
	_sync_presentation_from_session()


func _find_session_offer_by_id(offer_id: StringName) -> Variant:
	if normal_shop_session == null:
		return null
	for offer: Variant in normal_shop_session.call("get_offers"):
		if offer != null and StringName(offer.offer_id) == offer_id:
			return offer
	return null


func _sync_presentation_from_session() -> void:
	if normal_shop_session == null:
		_set_presentation_offers([])
		return
	var active_offers: Array = []
	for offer: Variant in normal_shop_session.call("get_offers"):
		if offer != null and not bool(offer.consumed):
			active_offers.append(offer)
	_set_presentation_offers(active_offers)


func _set_presentation_offers(offers: Array) -> void:
	shop_offers = offers.duplicate()
	shop_items.clear()
	for offer: Variant in shop_offers:
		if offer != null and offer.item != null:
			shop_items.append(offer.item)
	free_previous_slots()
	load_shop_inventory()


func _set_commerce_quote_sources(candidates: Array) -> void:
	_commerce_quote_sources.clear()
	for value: Variant in candidates:
		var candidate := value as Item
		if candidate != null:
			_commerce_quote_sources[ItemIdentityScript.key(candidate)] = candidate


func _quote_commerce_item(item: Item) -> int:
	var source := _commerce_quote_sources.get(ItemIdentityScript.key(item), item) as Item
	return get_buy_price(source)


func get_buy_price(item: Item) -> int:
	return NormalShopPricingScript.quote(
		item,
		_get_stat_multiplier("buy_price_multiplier", 1.0)
	)


## Returns whether the player can pay this quote's actual price.
func can_afford_offer(offer: Variant) -> bool:
	return offer != null and gold >= offer.price


func get_sell_price(item: Item) -> int:
	return NormalShopPricingScript.sell_quote(
		item,
		_get_stat_multiplier("sell_price_multiplier", 0.5)
	)


func _get_stat_multiplier(stat_id: String, fallback_multiplier: float) -> float:
	var multiplier: float = fallback_multiplier
	var stat_system: Node = _get_autoload_node(&"StatSystem")
	if stat_system != null and stat_system.has_method("get_stat"):
		multiplier = float(stat_system.call("get_stat", stat_id, "player"))
	return multiplier

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
			if shop_slot.has_signal(&"purchase_requested"):
				var purchase_callback := Callable(self, "_on_shop_slot_purchase_requested")
				if not shop_slot.is_connected(&"purchase_requested", purchase_callback):
					shop_slot.connect(&"purchase_requested", purchase_callback)
			if shop_slot.has_method("set_affordable"):
				shop_slot.call("set_affordable", can_afford_offer(offer))
		else:
			shop_slot.item = item


func _on_shop_slot_purchase_requested(offer_id: StringName) -> void:
	var offer: Variant = _find_session_offer_by_id(offer_id)
	if offer != null:
		purchase_offer(offer)


func _refresh_slot_affordability() -> void:
	if shop_container == null:
		return
	for slot: Node in shop_container.get_children():
		if not slot.has_method("set_affordable"):
			continue
		var slot_offer: Variant = slot.get("offer")
		slot.call("set_affordable", can_afford_offer(slot_offer))

func refresh_shop_inventory() -> void:
	if shop_item_pool.is_empty():
		shop_item_pool = shop_items.duplicate()
	if normal_shop_session == null and not _configure_from_runtime_fallback():
		_set_presentation_offers([])
		return
	_set_commerce_quote_sources(shop_item_pool)
	normal_shop_session.call("regenerate", shop_item_pool, SHOP_SLOT_COUNT)
	_sync_presentation_from_session()


func set_initial_gold():
	gold = 100


func refresh_collection_rows() -> void:
	var inventory: Node = _commerce_inventory if _is_live_node(_commerce_inventory) \
		else _get_autoload_node(&"Inventory")
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
				_set_icon_view_level(icon_view, _get_presentation_item_level(item))


func _get_presentation_item_level(item: Item) -> int:
	if current_progression_adapter != null:
		return int(current_progression_adapter.call("level_of", item))
	return ItemLevelResolverScript.get_inventory_level(item)


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
	var inventory: Node = _commerce_inventory if _is_live_node(_commerce_inventory) \
		else _get_autoload_node(&"Inventory")
	if inventory == null or not inventory.has_method("has_effect"):
		return
	if not inventory.call("has_effect", Item.EffectType.DARK_MARBLE):
		var dark_marble_item: Item = preload("res://Resources/dark_marble.tres")
		inventory.call("add_item", dark_marble_item)


func _connect_inventory() -> void:
	var inventory: Node = _commerce_inventory if _is_live_node(_commerce_inventory) \
		else _get_autoload_node(&"Inventory")
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


func _is_purchasable_item(item: Item) -> bool:
	if item == null:
		return false
	return item.type == Item.ItemType.MARBLE or item.type == Item.ItemType.RELIC or item.type == Item.ItemType.SKILL
