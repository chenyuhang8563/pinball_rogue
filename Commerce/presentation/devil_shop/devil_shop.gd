extends Control
class_name DevilShop

const DevilShopSessionScript: GDScript = preload("res://Commerce/application/devil_shop_session.gd")
const PurchaseResultScript: GDScript = preload("res://Commerce/domain/purchase_result.gd")
const ShopRefreshResultScript: GDScript = preload("res://Commerce/domain/shop_refresh_result.gd")

signal shop_close_intent(token: RunFlowToken, shop_kind: StringName)
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
var devil_shop_session: RefCounted = null

var _loadout: RefCounted = null
var _progression: RefCounted = null
var _wallet: RefCounted = null
var _health: RefCounted = null
var _configured: bool = false
var _pending_skill_offer_id: StringName = &""
var _purchases_disabled: bool = false
var _held_delta: int = 0
var _scale_state: int = -1
var _pending_scale_frame: int = -1
var _run_flow_token: RunFlowToken = null
var _run_flow_shop_kind: StringName = &""

@onready var _offer_slot: Node = get_node_or_null("OfferPan/OfferSlot")
@onready var _gold_value: Label = get_node_or_null("PaymentPan/GoldValue") as Label
@onready var _health_value: Label = get_node_or_null("PaymentPan/HealthValue") as Label
@onready var _gold_amount: Label = get_node_or_null("BottomHUD/GoldControls/Amount") as Label
@onready var _health_amount: Label = get_node_or_null("BottomHUD/HealthControls/Amount") as Label
@onready var _total_value: Label = get_node_or_null("BottomHUD/PaymentValue") as Label
@onready var _confirm_button: Button = get_node_or_null("BottomHUD/ConfirmButton") as Button
@onready var _status_label: Label = get_node_or_null("BottomHUD/Status") as Label
@onready var _refresh_control: Control = get_node_or_null("ShopRefreshControl") as Control
@onready var _scale_sprite: AnimatedSprite2D = get_node_or_null("DevilArt") as AnimatedSprite2D
@onready var _pan_animation_player: AnimationPlayer = get_node_or_null("PanAnimationPlayer") as AnimationPlayer
@onready var _repeat_timer: Timer = get_node_or_null("RepeatTimer") as Timer
@onready var _skill_dialog: SkillReplaceDialog = get_node_or_null("SkillReplaceDialog") as SkillReplaceDialog
@onready var _battle_hud: BattleHud = get_node_or_null("BattleHud") as BattleHud


func _ready() -> void:
	_connect_buttons()
	_apply_text()
	if _scale_sprite != null and not _scale_sprite.frame_changed.is_connected(_on_scale_frame_changed):
		_scale_sprite.frame_changed.connect(_on_scale_frame_changed)
	hide()


func _exit_tree() -> void:
	_disconnect_port_signals()


func configure(
	loadout: RefCounted,
	progression: RefCounted,
	wallet: RefCounted,
	health: RefCounted
) -> bool:
	unconfigure()
	if loadout == null or progression == null or wallet == null or health == null \
			or not is_instance_valid(loadout) or not is_instance_valid(progression) \
			or not is_instance_valid(wallet) or not is_instance_valid(health):
		return false
	var session: RefCounted = DevilShopSessionScript.new()
	if not bool(session.call("configure", loadout, progression, wallet, health)):
		return false
	_loadout = loadout
	_progression = progression
	_wallet = wallet
	_health = health
	devil_shop_session = session
	_configured = true
	_purchases_disabled = false
	_connect_port_signals()
	_set_offer_views([])
	_reset_chips()
	_refresh_battle_hud()
	return true


func set_floor(floor_number: int) -> void:
	if _battle_hud != null:
		_battle_hud.set_floor(floor_number)


func unconfigure() -> void:
	clear_run_presentation()
	_disconnect_port_signals()
	_loadout = null
	_progression = null
	_wallet = null
	_health = null
	devil_shop_session = null
	_configured = false
	_pending_skill_offer_id = &""
	_purchases_disabled = false
	_held_delta = 0
	_scale_state = -1
	_pending_scale_frame = -1
	_set_offer_views([])
	_reset_chips()
	_refresh_battle_hud()


func present_shop(token: RunFlowToken, shop_kind: StringName) -> bool:
	if token == null or not token.is_valid() or shop_kind != &"devil_shop":
		return false
	_run_flow_token = token
	_run_flow_shop_kind = shop_kind
	_open_for_run()
	return true


func _open_for_run() -> void:
	_purchases_disabled = false
	var opened: Array = []
	if _configured and devil_shop_session != null and config != null:
		devil_shop_session.call("begin_visit")
		opened = devil_shop_session.call("open", config, config.item_pool) as Array
	_set_offer_views(opened)
	_reset_chips()
	_connect_port_signals()
	_refresh_battle_hud()
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
	_pending_skill_offer_id = &""
	if _skill_dialog != null and _skill_dialog.is_request_pending():
		_skill_dialog.cancel_replace_request()
	hide()
	if is_inside_tree():
		get_tree().paused = false


func clear_run_presentation() -> void:
	_run_flow_token = null
	_run_flow_shop_kind = &""
	_pending_skill_offer_id = &""
	if _skill_dialog != null and _skill_dialog.is_request_pending():
		_skill_dialog.cancel_replace_request()
	hide()
	if is_inside_tree():
		get_tree().paused = false


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
	var available_gold := int(_wallet.call("balance")) if _wallet != null else 0
	var previous_value := gold_chips
	gold_chips = clampi(gold_chips + amount, 0, available_gold)
	_refresh_ui(gold_chips != previous_value)


func adjust_health_chips(amount: int) -> void:
	var minimum_health := _minimum_remaining_health()
	var available_health: int = maxi(0, _current_health() - minimum_health)
	var previous_value := health_chips
	health_chips = clampi(health_chips + amount, 0, available_health)
	_refresh_ui(health_chips != previous_value)


func can_confirm_purchase() -> bool:
	var offer := get_current_offer()
	if _purchases_disabled or offer == null or offer.offer_id == &"" \
			or not _configured or devil_shop_session == null or config == null \
			or _loadout == null or _progression == null or _wallet == null or _health == null:
		return false
	if gold_chips < 0 or health_chips < 0 or get_payment_value() < offer.price:
		return false
	var wallet_balance := int(_wallet.call("balance"))
	if gold_chips > wallet_balance \
			or not bool(_wallet.call("can_debit", gold_chips)):
		return false
	var current_health := int(_health.call("current"))
	if current_health - health_chips < _minimum_remaining_health():
		return false
	return bool(_health.call("can_debit", health_chips))


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
			var equipped_skill: Item = _loadout.call("current_skill") as Item \
					if _loadout != null else null
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
	_refresh_battle_hud()
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
	_refresh_battle_hud()
	_refresh_ui()


func refresh_offers() -> bool:
	if _purchases_disabled or devil_shop_session == null or config == null:
		return false
	var result: RefCounted = devil_shop_session.call("refresh", config.item_pool)
	if result == null:
		return false
	if int(result.get("code")) != ShopRefreshResultScript.Code.SUCCESS or not bool(result.get("committed")):
		if int(result.get("code")) == ShopRefreshResultScript.Code.INSUFFICIENT_FUNDS:
			_status_text("UI_SHOP_REFRESH_INSUFFICIENT")
		_refresh_ui()
		return false
	_pending_skill_offer_id = &""
	_sync_presentation_from_session()
	_reset_chips()
	offer_changed.emit(get_current_offer())
	_refresh_battle_hud()
	_refresh_ui()
	return true


func _refresh_after_failed_purchase(sync_session_views: bool) -> void:
	_pending_skill_offer_id = &""
	if sync_session_views:
		_sync_presentation_from_session()
	_reset_chips()
	if sync_session_views:
		offer_changed.emit(get_current_offer())
	_refresh_battle_hud()
	_refresh_ui()


func _disable_purchases_after_rollback_failure() -> void:
	_pending_skill_offer_id = &""
	_purchases_disabled = true
	_clear_session_offers()
	_reset_chips()
	offer_changed.emit(null)
	_refresh_battle_hud()
	_refresh_ui()


func _clear_session_offers() -> void:
	if devil_shop_session != null:
		devil_shop_session.call("replace_offers", [])
	_set_offer_views([])


func _result_is_success(result: RefCounted) -> bool:
	return result != null \
			and int(result.get("code")) == PurchaseResultScript.Code.SUCCESS


func _current_health() -> int:
	return int(_health.call("current")) if _health != null else 0


func _minimum_remaining_health() -> int:
	var configured_minimum := config.minimum_remaining_health if config != null else 1
	if _health != null and _health.has_method("minimum_remaining"):
		return maxi(configured_minimum, int(_health.call("minimum_remaining")))
	return configured_minimum


func _connect_port_signals() -> void:
	if _wallet != null and _wallet.has_signal(&"changed"):
		var wallet_callback := Callable(self, "_on_wallet_changed")
		if not _wallet.is_connected(&"changed", wallet_callback):
			_wallet.connect(&"changed", wallet_callback)
	if _health != null and _health.has_signal(&"changed"):
		var health_callback := Callable(self, "_on_health_port_changed")
		if not _health.is_connected(&"changed", health_callback):
			_health.connect(&"changed", health_callback)


func _disconnect_port_signals() -> void:
	if _wallet != null and is_instance_valid(_wallet) and _wallet.has_signal(&"changed"):
		var wallet_callback := Callable(self, "_on_wallet_changed")
		if _wallet.is_connected(&"changed", wallet_callback):
			_wallet.disconnect(&"changed", wallet_callback)
	if _health != null and is_instance_valid(_health) and _health.has_signal(&"changed"):
		var health_callback := Callable(self, "_on_health_port_changed")
		if _health.is_connected(&"changed", health_callback):
			_health.disconnect(&"changed", health_callback)


func _refresh_battle_hud() -> void:
	if _battle_hud == null:
		return
	_battle_hud.set_health(_current_health())
	var gold := int(_wallet.call("balance")) if _wallet != null else 0
	_battle_hud.set_gold(gold)


func _on_wallet_changed(value: int) -> void:
	if _battle_hud != null:
		_battle_hud.set_gold(value)
	_refresh_refresh_control()


func _on_health_port_changed(value: int) -> void:
	if _battle_hud != null:
		_battle_hud.set_health(value)
	health_changed.emit(value)


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
	if _refresh_control != null and _refresh_control.has_signal(&"refresh_requested"):
		var refresh_callback := Callable(self, "refresh_offers")
		if not _refresh_control.is_connected(&"refresh_requested", refresh_callback):
			_refresh_control.connect(&"refresh_requested", refresh_callback)
	if _offer_slot != null and _offer_slot.has_signal(&"purchase_requested"):
		var offer_callback := Callable(self, "_on_offer_slot_purchase_requested")
		if not _offer_slot.is_connected(&"purchase_requested", offer_callback):
			_offer_slot.connect(&"purchase_requested", offer_callback)


func _on_offer_slot_purchase_requested(offer_id: StringName) -> void:
	if _purchases_disabled or devil_shop_session == null:
		return
	var payment: Dictionary = devil_shop_session.call("select_optimal_payment", offer_id) as Dictionary
	if payment.is_empty():
		return
	gold_chips = int(payment.get(&"gold", 0))
	health_chips = int(payment.get(&"health", 0))
	_refresh_ui(true)


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
	var is_sold_out := offer == null and not offers.is_empty()
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
		_confirm_button.text = tr("DEVIL_SHOP_SOLD_OUT") if is_sold_out else tr("DEVIL_SHOP_CONFIRM")
	_refresh_refresh_control()
	if offer == null:
		if is_sold_out and _status_label != null:
			_status_label.text = ""
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


func _refresh_refresh_control() -> void:
	if _refresh_control == null or not _refresh_control.has_method("set_refresh_state"):
		return
	var refresh_cost := int(devil_shop_session.call("next_refresh_cost")) if devil_shop_session != null else 0
	var gold := int(_wallet.call("balance")) if _wallet != null else 0
	_refresh_control.call("set_refresh_state", refresh_cost, not _purchases_disabled and gold >= refresh_cost)


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
