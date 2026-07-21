extends Control

const NormalShopSessionScript: GDScript = preload("res://Commerce/application/normal_shop_session.gd")
const NormalShopSaleServiceScript: GDScript = preload("res://Commerce/application/normal_shop_sale_service.gd")
const PurchaseResultScript: GDScript = preload("res://Commerce/domain/purchase_result.gd")
const SHOP_SLOT_COUNT: int = 6

signal gold_changed(value: int)
signal shop_close_intent(token: RunFlowToken, shop_kind: StringName)

@export var shop_slot_node: PackedScene = preload("res://Loadout/presentation/slot.tscn")
@export var shop_item_pool: Array[Item] = []
@export var shop_items: Array[Item] = []
var shop_offers: Array = []
@export var shop_container: GridContainer
@export var marble_box_container: HBoxContainer
@export var relic_bar_container: HBoxContainer
@export var skill_box_container: HBoxContainer
@export var skill_replace_dialog: SkillReplaceDialog
var gold: int:
	get:
		return int(_wallet.call("balance")) if _wallet != null else 0
	set(value):
		if _wallet != null:
			_wallet.call("set_balance", value)

var normal_shop_session: RefCounted = null
var normal_shop_sale_service: RefCounted = null
var _loadout: RefCounted = null
var _progression: RefCounted = null
var _wallet: RefCounted = null
var _pending_skill_offer_id: StringName = &""
var _run_flow_token: RunFlowToken = null
var _run_flow_shop_kind: StringName = &""

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
	_bind_optional_nodes()
	$UI.hide()
	_connect_localization()
	_apply_text()
	var exit_button: Button = get_node_or_null("UI/Panel/ExitButton") as Button
	if exit_button != null and not exit_button.pressed.is_connected(close_shop):
		exit_button.pressed.connect(close_shop)
	_connect_collection_slot_inputs()
	_connect_skill_replace_dialog()
	_connect_port_signals()


func _exit_tree() -> void:
	_disconnect_port_signals()


func _bind_optional_nodes() -> void:
	if skill_box_container == null:
		skill_box_container = get_node_or_null("UI/Panel/CollectionRows/SkillBox") as HBoxContainer
	if skill_replace_dialog == null:
		skill_replace_dialog = get_node_or_null("UI/Panel/SkillReplaceDialog") as SkillReplaceDialog

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_U and mode == MODE.ON and _run_flow_token != null:
			close_shop()


func present_shop(token: RunFlowToken, shop_kind: StringName) -> bool:
	if token == null or not token.is_valid() or shop_kind != &"shop":
		return false
	_run_flow_token = token
	_run_flow_shop_kind = shop_kind
	mode = MODE.ON
	return true


func close_shop() -> void:
	cancel_pending_skill_purchase()
	mode = MODE.OFF
	if _run_flow_token == null:
		return
	var token: RunFlowToken = _run_flow_token
	var shop_kind: StringName = _run_flow_shop_kind
	_run_flow_token = null
	_run_flow_shop_kind = &""
	shop_close_intent.emit(token, shop_kind)


func dismiss_shop(token: RunFlowToken, shop_kind: StringName) -> void:
	if _run_flow_token == null or token == null or not _run_flow_token.matches(token) \
			or _run_flow_shop_kind != shop_kind:
		return
	_run_flow_token = null
	_run_flow_shop_kind = &""
	cancel_pending_skill_purchase()
	mode = MODE.OFF


func clear_run_presentation() -> void:
	_run_flow_token = null
	_run_flow_shop_kind = &""
	cancel_pending_skill_purchase()
	mode = MODE.OFF


func _apply_text() -> void:
	var title_label: Label = get_node_or_null("UI/Panel/Label") as Label
	if title_label != null:
		title_label.text = tr("UI_SHOP_TITLE")
	var exit_button: Button = get_node_or_null("UI/Panel/ExitButton") as Button
	if exit_button != null:
		exit_button.text = tr("UI_EXIT")

func sell_item(item: Item) -> bool:
	return _sell_item(item)


func _sell_item(item: Item) -> bool:
	if normal_shop_sale_service == null or normal_shop_session == null:
		return false
	var result: RefCounted = normal_shop_sale_service.call("sell", item)
	if int(result.get("code")) != PurchaseResultScript.Code.SUCCESS \
			or not bool(result.get("committed")):
		_handle_failed_result(result)
		return false
	normal_shop_session.call("acknowledge_external_change")
	_sync_presentation_from_session()
	refresh_collection_rows()
	return true


func _connect_port_signals() -> void:
	var wallet_callback := Callable(self, "_on_wallet_changed")
	if _wallet != null and is_instance_valid(_wallet) and _wallet.has_signal(&"changed") \
			and not _wallet.is_connected(&"changed", wallet_callback):
		_wallet.connect(&"changed", wallet_callback)
	var loadout_callback := Callable(self, "_on_loadout_changed")
	if _loadout != null and is_instance_valid(_loadout) and _loadout.has_signal(&"changed") \
			and not _loadout.is_connected(&"changed", loadout_callback):
		_loadout.connect(&"changed", loadout_callback)
	var item_progressed_callback := Callable(self, "_on_item_progressed")
	if _progression != null and is_instance_valid(_progression) \
			and _progression.has_signal(&"item_progressed") \
			and not _progression.is_connected(&"item_progressed", item_progressed_callback):
		_progression.connect(&"item_progressed", item_progressed_callback)
	var skill_progressed_callback := Callable(self, "_on_skill_progressed")
	if _progression != null and is_instance_valid(_progression) \
			and _progression.has_signal(&"skill_progressed") \
			and not _progression.is_connected(&"skill_progressed", skill_progressed_callback):
		_progression.connect(&"skill_progressed", skill_progressed_callback)


func _disconnect_port_signals() -> void:
	var wallet_callback := Callable(self, "_on_wallet_changed")
	if _wallet != null and is_instance_valid(_wallet) and _wallet.has_signal(&"changed") \
			and _wallet.is_connected(&"changed", wallet_callback):
		_wallet.disconnect(&"changed", wallet_callback)
	var loadout_callback := Callable(self, "_on_loadout_changed")
	if _loadout != null and is_instance_valid(_loadout) and _loadout.has_signal(&"changed") \
			and _loadout.is_connected(&"changed", loadout_callback):
		_loadout.disconnect(&"changed", loadout_callback)
	var item_progressed_callback := Callable(self, "_on_item_progressed")
	if _progression != null and is_instance_valid(_progression) \
			and _progression.has_signal(&"item_progressed") \
			and _progression.is_connected(&"item_progressed", item_progressed_callback):
		_progression.disconnect(&"item_progressed", item_progressed_callback)
	var skill_progressed_callback := Callable(self, "_on_skill_progressed")
	if _progression != null and is_instance_valid(_progression) \
			and _progression.has_signal(&"skill_progressed") \
			and _progression.is_connected(&"skill_progressed", skill_progressed_callback):
		_progression.disconnect(&"skill_progressed", skill_progressed_callback)


func _on_wallet_changed(value: int) -> void:
	gold_changed.emit(value)
	_refresh_slot_affordability()


func _on_loadout_changed() -> void:
	refresh_collection_rows()


func _on_item_progressed(_item: Item, _level: int, _awakened: bool) -> void:
	refresh_collection_rows()


func _on_skill_progressed(_skill_id: String, _level: int) -> void:
	refresh_collection_rows()


func configure(loadout: RefCounted, progression: RefCounted, wallet: RefCounted) -> bool:
	unconfigure()
	if not _has_port_api(loadout, [
		&"find_owned", &"can_add", &"add", &"remove", &"replace_skill", &"current_skill",
		&"revision", &"marbles", &"relics", &"skills",
	]) or not _has_port_api(progression, [
		&"level_of", &"can_upgrade", &"upgrade_one", &"reset_skill", &"reset_item", &"revision",
	]) or not _has_port_api(wallet, [
		&"balance", &"set_balance", &"quote_price", &"quote_sell_price", &"can_debit",
		&"debit", &"credit", &"revision",
	]):
		return false
	var session: RefCounted = NormalShopSessionScript.new()
	var sale_service: RefCounted = NormalShopSaleServiceScript.new()
	if not bool(session.call("configure", loadout, progression, wallet)) \
			or not bool(sale_service.call("configure", loadout, progression, wallet)):
		return false
	_loadout = loadout
	_progression = progression
	_wallet = wallet
	normal_shop_session = session
	normal_shop_sale_service = sale_service
	_connect_port_signals()
	_on_wallet_changed(gold)
	refresh_collection_rows()
	return true


func unconfigure() -> void:
	clear_run_presentation()
	_disconnect_port_signals()
	_loadout = null
	_progression = null
	_wallet = null
	normal_shop_session = null
	normal_shop_sale_service = null
	_set_presentation_offers([])
	refresh_collection_rows()


## Purchases an upgrade quote using the runtime dependencies resolved from the active run.
func purchase_offer(offer: Variant) -> bool:
	if offer == null or normal_shop_session == null:
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
	var current_skill: Item = _loadout.call("current_skill") as Item if _loadout != null else null
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
	if _wallet != null:
		_on_wallet_changed(int(_wallet.call("balance")))


func _regenerate_from_pool(regenerate_empty_pool: bool) -> void:
	if normal_shop_session == null:
		_set_presentation_offers([])
		return
	if shop_item_pool.is_empty() and not regenerate_empty_pool:
		_set_presentation_offers([])
		return
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


func get_buy_price(item: Item) -> int:
	return int(_wallet.call("quote_price", item)) if _wallet != null else 0


## Returns whether the player can pay this quote's actual price.
func can_afford_offer(offer: Variant) -> bool:
	return offer != null and gold >= offer.price


func get_sell_price(item: Item) -> int:
	return int(_wallet.call("quote_sell_price", item)) if _wallet != null else 0

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
	if normal_shop_session == null:
		_set_presentation_offers([])
		return
	normal_shop_session.call("regenerate", shop_item_pool, SHOP_SLOT_COUNT)
	_sync_presentation_from_session()


func refresh_collection_rows() -> void:
	if _loadout == null:
		_update_collection_icons(marble_box_container, [])
		_update_collection_icons(relic_bar_container, [])
		_update_collection_icons(skill_box_container, [])
		return
	var marble_items: Array = _loadout.call("marbles") as Array
	var relic_items: Array = _loadout.call("relics") as Array
	var skill_items: Array = _loadout.call("skills") as Array
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
	return int(_progression.call("level_of", item)) if _progression != null else 0


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


func _is_purchasable_item(item: Item) -> bool:
	if item == null:
		return false
	return item.type == Item.ItemType.MARBLE or item.type == Item.ItemType.RELIC or item.type == Item.ItemType.SKILL


func _has_port_api(port: RefCounted, methods: Array[StringName]) -> bool:
	if port == null or not is_instance_valid(port):
		return false
	for method: StringName in methods:
		if not port.has_method(method):
			return false
	return true
