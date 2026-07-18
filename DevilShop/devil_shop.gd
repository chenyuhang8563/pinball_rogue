extends Control
class_name DevilShop

const StatRegistryScript: GDScript = preload("res://Stats/stat_registry.gd")
const DevilShopSessionScript: GDScript = preload("res://Commerce/application/devil_shop_session.gd")
const CurrentInventoryAdapterScript: GDScript = preload("res://Commerce/application/adapters/current_inventory_adapter.gd")
const CurrentProgressionAdapterScript: GDScript = preload("res://Commerce/application/adapters/current_progression_adapter.gd")
const CurrentWalletAdapterScript: GDScript = preload("res://Commerce/application/adapters/current_wallet_adapter.gd")
const CurrentHealthAdapterScript: GDScript = preload("res://Commerce/application/adapters/current_health_adapter.gd")
const PurchaseResultScript: GDScript = preload("res://Commerce/domain/purchase_result.gd")
const RUN_HEALTH_ENTITY_ID: String = "run:current"
const PAYMENT_PAN_ANIMATION_REFERENCE_Y: float = 189.0

signal closed
signal health_changed(value: int)
signal offer_changed(offer: DevilShopOffer)
signal purchase_completed(offer: DevilShopOffer)

enum ScaleState {
	RIGHT_HEAVY,
	BALANCED,
	LEFT_HEAVY,
}

@export var config: DevilShopConfig

var offers: Array[DevilShopOffer] = []
var current_offer_index: int = 0
var gold_chips: int = 0
var health_chips: int = 0
var devil_shop_session: RefCounted = DevilShopSessionScript.new()
var current_inventory_adapter: RefCounted = null
var current_progression_adapter: RefCounted = null
var current_wallet_adapter: RefCounted = null
var current_health_adapter: RefCounted = null

var _wallet_source: Node = null
var _pending_skill_offer_id: StringName = &""
var _purchases_disabled: bool = false
var _held_delta: int = 0
var _scale_state: int = -1
var _pending_scale_frame: int = -1

@onready var _offer_slot: Node = get_node_or_null("OfferPan/OfferSlot")
@onready var _payment_pan: Control = get_node_or_null("PaymentPan") as Control
@onready var _gold_value: Label = get_node_or_null("PaymentPan/GoldValue") as Label
@onready var _health_value: Label = get_node_or_null("PaymentPan/HealthValue") as Label
@onready var _gold_amount: Label = get_node_or_null("BottomHUD/GoldControls/Amount") as Label
@onready var _health_amount: Label = get_node_or_null("BottomHUD/HealthControls/Amount") as Label
@onready var _total_value: Label = get_node_or_null("BottomHUD/PaymentValue") as Label
@onready var _confirm_button: Button = get_node_or_null("BottomHUD/ConfirmButton") as Button
@onready var _status_label: Label = get_node_or_null("BottomHUD/Status") as Label
@onready var _scale_sprite: AnimatedSprite2D = get_node_or_null("DevilArt") as AnimatedSprite2D
@onready var _pan_animation_player: AnimationPlayer = get_node_or_null("PanAnimationPlayer") as AnimationPlayer
@onready var _repeat_timer: Timer = get_node_or_null("RepeatTimer") as Timer
@onready var _skill_dialog: SkillReplaceDialog = get_node_or_null("SkillReplaceDialog") as SkillReplaceDialog
@onready var _battle_health_hud: BattleHealthHud = get_node_or_null("BattleHealthHud") as BattleHealthHud


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rebase_payment_pan_animations()
	_connect_buttons()
	_apply_text()
	if _scale_sprite != null and not _scale_sprite.frame_changed.is_connected(_on_scale_frame_changed):
		_scale_sprite.frame_changed.connect(_on_scale_frame_changed)
	hide()


func open_for_run(marble_upgrade_system: Node) -> void:
	_purchases_disabled = false
	var inventory := _get_autoload_node(&"Inventory")
	var shop := _get_autoload_node(&"Shop")
	var stat_system := _get_autoload_node(&"StatSystem")
	var opened: Array = []
	if config != null and _configure_production_session(
		inventory,
		marble_upgrade_system,
		shop,
		stat_system
	):
		opened = devil_shop_session.call("open", config, config.item_pool) as Array
	_set_offer_views(opened)
	_reset_chips()
	_connect_battle_health_hud()
	_refresh_battle_health_hud()
	offer_changed.emit(get_current_offer())
	_refresh_ui()
	show()
	get_tree().paused = true
	if _confirm_button != null:
		_confirm_button.grab_focus()


func close_shop() -> void:
	_pending_skill_offer_id = &""
	if _skill_dialog != null and _skill_dialog.is_request_pending():
		_skill_dialog.cancel_replace_request()
	hide()
	get_tree().paused = false
	closed.emit()


func get_current_offer() -> DevilShopOffer:
	if current_offer_index < 0 or current_offer_index >= offers.size():
		return null
	return offers[current_offer_index]


func get_payment_value() -> int:
	var exchange_rate: int = config.health_to_gold if config != null else 5
	return gold_chips + health_chips * exchange_rate


func get_scale_state() -> ScaleState:
	var offer := get_current_offer()
	if offer == null:
		return ScaleState.BALANCED
	var payment_value := get_payment_value()
	if payment_value < offer.price:
		return ScaleState.RIGHT_HEAVY
	if payment_value > offer.price:
		return ScaleState.LEFT_HEAVY
	return ScaleState.BALANCED


func adjust_gold_chips(amount: int) -> void:
	var available_gold := int(current_wallet_adapter.call("balance")) \
			if current_wallet_adapter != null else 0
	var previous_value := gold_chips
	gold_chips = clampi(gold_chips + amount, 0, available_gold)
	_refresh_ui(gold_chips != previous_value)


func adjust_health_chips(amount: int) -> void:
	var minimum_health: int = config.minimum_remaining_health if config != null else 1
	var available_health: int = maxi(0, _current_health() - minimum_health)
	var previous_value := health_chips
	health_chips = clampi(health_chips + amount, 0, available_health)
	_refresh_ui(health_chips != previous_value)


func can_confirm_purchase() -> bool:
	var offer := get_current_offer()
	if _purchases_disabled or offer == null or offer.offer_id == &"" \
			or devil_shop_session == null or config == null \
			or current_inventory_adapter == null or current_progression_adapter == null \
			or current_wallet_adapter == null or current_health_adapter == null:
		return false
	if gold_chips < 0 or health_chips < 0 or get_payment_value() < offer.price:
		return false
	var wallet_balance := int(current_wallet_adapter.call("balance"))
	if gold_chips > wallet_balance \
			or not bool(current_wallet_adapter.call("can_debit", gold_chips)):
		return false
	var current_health := int(current_health_adapter.call("current"))
	if current_health - health_chips < config.minimum_remaining_health:
		return false
	return bool(current_health_adapter.call("can_debit", health_chips))


func confirm_purchase() -> bool:
	var offer := get_current_offer()
	if not can_confirm_purchase():
		return false
	var selected: RefCounted = devil_shop_session.call(
		"select_payment",
		offer.offer_id,
		gold_chips,
		health_chips
	)
	if not _result_is_success(selected):
		return _handle_purchase_result(selected, offer)
	var result: RefCounted = devil_shop_session.call("purchase", offer.offer_id)
	return _handle_purchase_result(result, offer)


func _configure_production_session(
	inventory: Node,
	progression: Node,
	wallet: Node,
	stat_system: Node
) -> bool:
	if inventory == null or progression == null or wallet == null or stat_system == null:
		return false
	devil_shop_session = DevilShopSessionScript.new()
	current_inventory_adapter = CurrentInventoryAdapterScript.new(inventory)
	current_progression_adapter = CurrentProgressionAdapterScript.new(
		progression,
		current_inventory_adapter
	)
	current_wallet_adapter = CurrentWalletAdapterScript.new(wallet)
	current_health_adapter = CurrentHealthAdapterScript.new(
		stat_system,
		StatRegistryScript.RUN_HEALTH,
		RUN_HEALTH_ENTITY_ID,
		config.minimum_remaining_health
	)
	_wallet_source = wallet
	return bool(devil_shop_session.call(
		"configure",
		current_inventory_adapter,
		current_progression_adapter,
		current_wallet_adapter,
		current_health_adapter
	))
func _set_offer_views(session_views: Array) -> void:
	offers.clear()
	for view: Variant in session_views:
		var wrapper := DevilShopOffer.from_commerce(view)
		if wrapper != null:
			offers.append(wrapper)
	current_offer_index = 0 if not offers.is_empty() else offers.size()


func _sync_presentation_from_session() -> void:
	if devil_shop_session == null:
		_set_offer_views([])
		return
	_set_offer_views(devil_shop_session.call("get_offers") as Array)
	var current: Variant = devil_shop_session.call("get_current_offer")
	if current == null:
		current_offer_index = offers.size()
		return
	var current_id := StringName(current.get("offer_id"))
	current_offer_index = offers.size()
	for index: int in offers.size():
		if offers[index].offer_id == current_id:
			current_offer_index = index
			break


func _find_offer_by_id(offer_id: StringName) -> DevilShopOffer:
	for offer: DevilShopOffer in offers:
		if offer.offer_id == offer_id:
			return offer
	return null


func _handle_purchase_result(result: RefCounted, completed_offer: DevilShopOffer) -> bool:
	if result == null:
		return false
	var code := int(result.get("code"))
	match code:
		PurchaseResultScript.Code.SKILL_REPLACEMENT_REQUIRED:
			_pending_skill_offer_id = completed_offer.offer_id
			var equipped_skill: Item = current_inventory_adapter.call("current_skill") as Item \
					if current_inventory_adapter != null else null
			if _skill_dialog != null:
				_skill_dialog.request_replace(equipped_skill, completed_offer.item)
			return false
		PurchaseResultScript.Code.STALE_SNAPSHOT, \
		PurchaseResultScript.Code.OWNERSHIP_CHANGED, \
		PurchaseResultScript.Code.LEVEL_CHANGED, \
		PurchaseResultScript.Code.CAPACITY_CHANGED:
			_regenerate_after_invalid_offer()
			return false
		PurchaseResultScript.Code.INSUFFICIENT_FUNDS, \
		PurchaseResultScript.Code.MINIMUM_HEALTH_VIOLATED, \
		PurchaseResultScript.Code.INVALID_PAYMENT, \
		PurchaseResultScript.Code.PAYMENT_NOT_SELECTED:
			_refresh_after_failed_purchase(false)
			return false
		PurchaseResultScript.Code.COMMIT_FAILED:
			if bool(result.get("rollback_completed")):
				_refresh_after_failed_purchase(true)
			else:
				_disable_purchases_after_rollback_failure()
			return false
		PurchaseResultScript.Code.ROLLBACK_FAILED, PurchaseResultScript.Code.NOT_CONFIGURED:
			_disable_purchases_after_rollback_failure()
			return false
		PurchaseResultScript.Code.OFFER_CONSUMED, PurchaseResultScript.Code.UNKNOWN_OFFER:
			_refresh_after_failed_purchase(true)
			return false
		PurchaseResultScript.Code.SUCCESS:
			if not bool(result.get("committed")):
				return false
		_:
			_refresh_after_failed_purchase(false)
			return false
	_pending_skill_offer_id = &""
	_sync_presentation_from_session()
	_reset_chips()
	purchase_completed.emit(completed_offer)
	offer_changed.emit(get_current_offer())
	health_changed.emit(_current_health())
	_refresh_battle_health_hud()
	if get_current_offer() == null:
		_status_text("DEVIL_SHOP_SOLD_OUT")
	_refresh_ui()
	return true


func _regenerate_after_invalid_offer() -> void:
	_pending_skill_offer_id = &""
	if devil_shop_session != null and config != null:
		devil_shop_session.call("open", config, config.item_pool)
		_sync_presentation_from_session()
	else:
		_clear_session_offers()
	_reset_chips()
	offer_changed.emit(get_current_offer())
	_refresh_battle_health_hud()
	_refresh_ui()


func _refresh_after_failed_purchase(sync_session_views: bool) -> void:
	_pending_skill_offer_id = &""
	if sync_session_views:
		_sync_presentation_from_session()
	_reset_chips()
	if sync_session_views:
		offer_changed.emit(get_current_offer())
	_refresh_battle_health_hud()
	_refresh_ui()


func _disable_purchases_after_rollback_failure() -> void:
	_pending_skill_offer_id = &""
	_purchases_disabled = true
	_clear_session_offers()
	_reset_chips()
	offer_changed.emit(null)
	_refresh_battle_health_hud()
	_refresh_ui()


func _clear_session_offers() -> void:
	if devil_shop_session != null:
		devil_shop_session.call("replace_offers", [])
	_set_offer_views([])


func _result_is_success(result: RefCounted) -> bool:
	return result != null \
			and int(result.get("code")) == PurchaseResultScript.Code.SUCCESS


func _current_health() -> int:
	return int(current_health_adapter.call("current")) if current_health_adapter != null else 0


func _rebase_payment_pan_animations() -> void:
	if _payment_pan == null or _pan_animation_player == null:
		return
	var source_library := _pan_animation_player.get_animation_library(&"")
	if source_library == null:
		return
	var instance_library := source_library.duplicate(true) as AnimationLibrary
	if instance_library == null:
		return
	for animation_name: StringName in instance_library.get_animation_list():
		var source_animation := instance_library.get_animation(animation_name)
		instance_library.remove_animation(animation_name)
		instance_library.add_animation(animation_name, source_animation.duplicate(true) as Animation)
	_pan_animation_player.remove_animation_library(&"")
	_pan_animation_player.add_animation_library(&"", instance_library)
	var initial_y := _payment_pan.position.y
	for animation_name: StringName in instance_library.get_animation_list():
		var animation := instance_library.get_animation(animation_name)
		for track_index in animation.get_track_count():
			if animation.track_get_path(track_index) != NodePath("PaymentPan:position:y"):
				continue
			for key_index in animation.track_get_key_count(track_index):
				var key_y: float = float(animation.track_get_key_value(track_index, key_index))
				animation.track_set_key_value(
					track_index,
					key_index,
					initial_y + key_y - PAYMENT_PAN_ANIMATION_REFERENCE_Y
				)


func _connect_battle_health_hud() -> void:
	if _wallet_source == null or not _wallet_source.has_signal(&"gold_changed"):
		return
	var callback := Callable(self, "_on_battle_health_hud_gold_changed")
	if not _wallet_source.is_connected(&"gold_changed", callback):
		_wallet_source.connect(&"gold_changed", callback)


func _refresh_battle_health_hud() -> void:
	if _battle_health_hud == null:
		return
	_battle_health_hud.set_health(_current_health())
	var gold := int(current_wallet_adapter.call("balance")) \
			if current_wallet_adapter != null else 0
	_battle_health_hud.set_gold(gold)


func _on_battle_health_hud_gold_changed(value: int) -> void:
	if _battle_health_hud != null:
		_battle_health_hud.set_gold(value)


func _reset_chips() -> void:
	gold_chips = 0
	health_chips = 0


func _connect_buttons() -> void:
	_connect_chip_button("BottomHUD/GoldControls/Add", 1)
	_connect_chip_button("BottomHUD/GoldControls/Remove", -1)
	_connect_chip_button("BottomHUD/HealthControls/Add", 2)
	_connect_chip_button("BottomHUD/HealthControls/Remove", -2)
	var confirm := _confirm_button
	if confirm != null and not confirm.pressed.is_connected(confirm_purchase):
		confirm.pressed.connect(confirm_purchase)
	var leave := get_node_or_null("BottomHUD/LeaveButton") as Button
	if leave != null and not leave.pressed.is_connected(close_shop):
		leave.pressed.connect(close_shop)
	if _repeat_timer != null and not _repeat_timer.timeout.is_connected(_on_repeat_timeout):
		_repeat_timer.timeout.connect(_on_repeat_timeout)
	if _skill_dialog != null:
		if not _skill_dialog.confirmed.is_connected(_on_skill_replace_confirmed):
			_skill_dialog.confirmed.connect(_on_skill_replace_confirmed)
		if not _skill_dialog.cancelled.is_connected(_on_skill_replace_cancelled):
			_skill_dialog.cancelled.connect(_on_skill_replace_cancelled)


func _connect_chip_button(path: String, delta: int) -> void:
	var button := get_node_or_null(path) as Button
	if button == null:
		return
	var down := Callable(self, "_on_chip_button_down").bind(delta)
	var up := Callable(self, "_on_chip_button_up")
	if not button.button_down.is_connected(down):
		button.button_down.connect(down)
	if not button.button_up.is_connected(up):
		button.button_up.connect(up)


func _on_chip_button_down(delta: int) -> void:
	_apply_chip_delta(delta)
	_held_delta = delta
	if _repeat_timer != null:
		_repeat_timer.wait_time = config.long_press_delay if config != null else 0.35
		_repeat_timer.start()


func _on_chip_button_up() -> void:
	_held_delta = 0
	if _repeat_timer != null:
		_repeat_timer.stop()


func _on_repeat_timeout() -> void:
	if _held_delta == 0:
		return
	_apply_chip_delta(_held_delta)
	if _repeat_timer != null:
		_repeat_timer.wait_time = config.long_press_interval if config != null else 0.08
		_repeat_timer.start()


func _apply_chip_delta(delta: int) -> void:
	if abs(delta) == 1:
		adjust_gold_chips(delta)
	else:
		adjust_health_chips(roundi(float(delta) / 2.0))


func _on_skill_replace_confirmed(_item: Item) -> void:
	var offer_id := _pending_skill_offer_id
	_pending_skill_offer_id = &""
	if offer_id == &"" or devil_shop_session == null:
		return
	var offer := _find_offer_by_id(offer_id)
	if offer == null or not bool(devil_shop_session.call("authorize_skill_replacement", offer_id)):
		return
	var result: RefCounted = devil_shop_session.call("purchase", offer_id)
	_handle_purchase_result(result, offer)


func _on_skill_replace_cancelled() -> void:
	_pending_skill_offer_id = &""


func _apply_text() -> void:
	var leave := get_node_or_null("BottomHUD/LeaveButton") as Button
	if leave != null:
		leave.text = tr("UI_EXIT")
	if _confirm_button != null:
		_confirm_button.text = tr("DEVIL_SHOP_CONFIRM")


func _refresh_ui(animate_scale: bool = false) -> void:
	var offer := get_current_offer()
	if _gold_value != null:
		_gold_value.text = str(gold_chips)
	if _health_value != null:
		_health_value.text = str(health_chips)
	if _gold_amount != null:
		_gold_amount.text = str(gold_chips)
	if _health_amount != null:
		_health_amount.text = str(health_chips)
	if _total_value != null:
		_total_value.text = tr("DEVIL_SHOP_PAYMENT_VALUE") % get_payment_value()
	if _confirm_button != null:
		_confirm_button.disabled = not can_confirm_purchase()
	if offer == null:
		if _offer_slot != null:
			if _offer_slot.has_method("set_offer"):
				_offer_slot.call("set_offer", null)
			else:
				_offer_slot.set("item", null)
		_set_scale_pose(ScaleState.BALANCED, false)
		return
	_refresh_offer_slot(offer)
	if _status_label != null:
		_status_label.text = ""
	_set_scale_pose(get_scale_state(), animate_scale)


func _set_scale_pose(next_state: ScaleState, animate: bool) -> void:
	if _scale_sprite == null:
		return
	var previous_state := _scale_state
	if previous_state < 0:
		animate = false
	var target_frame := _frame_for_scale_state(next_state)
	var current_frame := _frame_for_scale_state(previous_state) if previous_state >= 0 else _scale_sprite.frame
	if not animate or current_frame == target_frame:
		_pending_scale_frame = -1
		_scale_sprite.pause()
		_scale_sprite.animation = &"poses"
		_scale_sprite.frame = target_frame
		_scale_state = next_state
		_play_pan_pose(next_state)
		return
	_scale_sprite.animation = &"poses"
	_scale_sprite.frame = current_frame
	_pending_scale_frame = target_frame
	_scale_state = next_state
	_scale_sprite.play(&"poses", 1.0 if target_frame > current_frame else -1.0)
	_play_pan_transition(previous_state, next_state)


func _play_pan_pose(state: ScaleState) -> void:
	if _pan_animation_player == null:
		return
	_pan_animation_player.play(_pan_animation_name("pan_", state))


func _play_pan_transition(from_state: int, to_state: ScaleState) -> void:
	if _pan_animation_player == null or from_state < 0:
		return
	_pan_animation_player.play(
		"pan_%s_to_%s" % [_scale_state_name(from_state), _scale_state_name(to_state)]
	)


func _pan_animation_name(prefix: String, state: ScaleState) -> StringName:
	return StringName(prefix + _scale_state_name(state))


func _scale_state_name(state: int) -> String:
	match state:
		ScaleState.RIGHT_HEAVY:
			return "right"
		ScaleState.LEFT_HEAVY:
			return "left"
		_:
			return "balanced"


func _refresh_offer_slot(offer: DevilShopOffer) -> void:
	if _offer_slot == null:
		return
	if _offer_slot.has_method("set_offer"):
		_offer_slot.call("set_offer", offer)
		return
	_offer_slot.set("item", offer.item)
	var icon := _offer_slot.get_node_or_null("Icon")
	if icon != null and icon.has_method("set_level"):
		icon.call("set_level", offer.target_level)
	var price := _offer_slot.get_node_or_null("Price") as Label
	if price != null:
		price.text = tr("DEVIL_SHOP_PRICE") % offer.price


func _frame_for_scale_state(state: int) -> int:
	match state:
		ScaleState.RIGHT_HEAVY:
			return 0
		ScaleState.LEFT_HEAVY:
			return 2
		_:
			return 1


func _on_scale_frame_changed() -> void:
	if _scale_sprite == null or _pending_scale_frame < 0:
		return
	if _scale_sprite.frame == _pending_scale_frame:
		_scale_sprite.pause()
		_pending_scale_frame = -1


func _status_text(key: String) -> void:
	if _status_label != null:
		_status_label.text = tr(key)


func _item_title(item: Item) -> String:
	if item == null:
		return ""
	if item.skill_definition != null:
		return tr(String(item.skill_definition.get("name_key")))
	return tr("ITEM_%s_TITLE" % item.id.to_upper())


func _get_autoload_node(node_name: StringName) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))
