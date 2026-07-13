extends Control
class_name DevilShop

const StatRegistryScript: GDScript = preload("res://Stats/stat_registry.gd")
const ItemLevelResolverScript: GDScript = preload("res://UI/item_level_resolver.gd")
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
var _marble_upgrade_system: Node
var _pending_skill_offer: DevilShopOffer
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
	_connect_battle_health_hud()
	_refresh_battle_health_hud()
	if _scale_sprite != null and not _scale_sprite.frame_changed.is_connected(_on_scale_frame_changed):
		_scale_sprite.frame_changed.connect(_on_scale_frame_changed)
	hide()


func open_for_run(marble_upgrade_system: Node) -> void:
	_marble_upgrade_system = marble_upgrade_system
	_generate_offers()
	_reset_chips()
	_connect_battle_health_hud()
	_refresh_battle_health_hud()
	_refresh_ui()
	show()
	get_tree().paused = true
	if _confirm_button != null:
		_confirm_button.grab_focus()


func close_shop() -> void:
	_pending_skill_offer = null
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
	var shop: Node = _get_autoload_node(&"Shop")
	var available_gold: int = int(shop.get("gold")) if shop != null else 0
	var previous_value := gold_chips
	gold_chips = clampi(gold_chips + amount, 0, available_gold)
	_refresh_ui(gold_chips != previous_value)


func adjust_health_chips(amount: int) -> void:
	var minimum_health: int = config.minimum_remaining_health if config != null else 1
	var available_health: int = maxi(0, _get_run_health() - minimum_health)
	var previous_value := health_chips
	health_chips = clampi(health_chips + amount, 0, available_health)
	_refresh_ui(health_chips != previous_value)


func can_confirm_purchase() -> bool:
	var offer := get_current_offer()
	return offer != null and get_payment_value() >= offer.price and _can_grant_offer(offer)


func confirm_purchase() -> bool:
	var offer := get_current_offer()
	if offer == null or not can_confirm_purchase():
		return false
	var inventory: Node = _get_autoload_node(&"Inventory")
	if inventory == null:
		return false
	if offer.item.type == Item.ItemType.SKILL and inventory.get("skill_item") != null:
		_pending_skill_offer = offer
		if _skill_dialog != null:
			_skill_dialog.request_replace(inventory.get("skill_item") as Item, offer.item)
		return false
	return _complete_purchase(offer, false)


func _complete_purchase(offer: DevilShopOffer, replace_skill: bool) -> bool:
	if offer == null or offer != get_current_offer() or not can_confirm_purchase():
		return false
	var inventory: Node = _get_autoload_node(&"Inventory")
	var shop: Node = _get_autoload_node(&"Shop")
	if inventory == null or shop == null:
		return false
	if offer.item.type == Item.ItemType.SKILL:
		if replace_skill:
			if not bool(inventory.call("replace_skill", offer.item)):
				return false
		elif not bool(inventory.call("add_item", offer.item)):
			return false
	elif not _grant_levelled_item(inventory, offer):
		return false
	shop.set("gold", int(shop.get("gold")) - gold_chips)
	_set_run_health(_get_run_health() - health_chips)
	var completed_offer := offer
	current_offer_index += 1
	_reset_chips()
	purchase_completed.emit(completed_offer)
	offer_changed.emit(get_current_offer())
	if current_offer_index >= offers.size():
		_status_text("DEVIL_SHOP_SOLD_OUT")
	_refresh_ui()
	return true


func _grant_levelled_item(inventory: Node, offer: DevilShopOffer) -> bool:
	if offer.item.type == Item.ItemType.RELIC:
		while _get_relic_level(inventory, offer.item) < offer.target_level:
			if not bool(inventory.call("add_item", offer.item)):
				return false
		if offer.target_level == 4 and not bool(inventory.call("is_relic_awakened", offer.item)):
			if not bool(inventory.call("add_item", offer.item)):
				return false
		return true
	if offer.item.type != Item.ItemType.MARBLE:
		return false
	if not bool(inventory.call("has_item_id", offer.item.id)) and not bool(inventory.call("add_item", offer.item)):
		return false
	if _marble_upgrade_system == null:
		return false
	while _get_marble_level(offer.item) < offer.target_level:
		if not bool(_marble_upgrade_system.call("upgrade_marble", offer.item.marble_type)):
			return false
	if offer.target_level == 4 and not bool(_marble_upgrade_system.call("is_awakened", offer.item.marble_type)):
		return bool(_marble_upgrade_system.call("upgrade_marble", offer.item.marble_type))
	return true


func _generate_offers() -> void:
	offers.clear()
	current_offer_index = 0
	if config == null:
		_refresh_ui()
		return
	var candidates := _get_eligible_items()
	while offers.size() < config.stock_count and not candidates.is_empty():
		var item: Item = candidates.pick_random()
		candidates.erase(item)
		var target_level := _pick_target_level(item)
		var multiplier: float = float(config.level_price_multipliers.get(target_level, 1.0))
		offers.append(DevilShopOffer.new(item, target_level, roundi(item.price * multiplier)))
	offer_changed.emit(get_current_offer())
	_refresh_ui()


func _get_eligible_items() -> Array[Item]:
	var result: Array[Item] = []
	if config == null:
		return result
	for item: Item in config.item_pool:
		if item != null and _is_item_eligible(item):
			result.append(item)
	return result


func _is_item_eligible(item: Item) -> bool:
	var inventory: Node = _get_autoload_node(&"Inventory")
	if inventory == null:
		return false
	if item.type == Item.ItemType.SKILL:
		return item.id == "" or not bool(inventory.call("has_item_id", item.id))
	if item.type == Item.ItemType.RELIC:
		return not bool(inventory.call("is_relic_max_level", item))
	if item.type == Item.ItemType.MARBLE:
		if _marble_upgrade_system == null:
			return false
		return not bool(_marble_upgrade_system.call("is_max_level", item.marble_type))
	return false


func _pick_target_level(item: Item) -> int:
	if item.type == Item.ItemType.SKILL or config == null:
		return 0
	var current_level: int = _get_relic_level(_get_autoload_node(&"Inventory"), item) if item.type == Item.ItemType.RELIC else _get_marble_level(item)
	var choices: Array[int] = []
	for level: int in [2, 3, 4]:
		if level > current_level:
			choices.append(level)
	if choices.is_empty():
		return 0
	var total_weight := 0
	for level: int in choices:
		total_weight += int(config.level_weights.get(level, 1))
	var roll := randi_range(1, total_weight)
	for level: int in choices:
		roll -= int(config.level_weights.get(level, 1))
		if roll <= 0:
			return level
	return choices.back()


func _can_grant_offer(offer: DevilShopOffer) -> bool:
	var inventory: Node = _get_autoload_node(&"Inventory")
	if inventory == null or offer == null:
		return false
	if offer.item.type == Item.ItemType.SKILL:
		return offer.item.id == "" or not bool(inventory.call("has_item_id", offer.item.id))
	if offer.item.type == Item.ItemType.RELIC:
		return not bool(inventory.call("is_relic_max_level", offer.item))
	if offer.item.type == Item.ItemType.MARBLE:
		return _marble_upgrade_system != null and not bool(_marble_upgrade_system.call("is_max_level", offer.item.marble_type))
	return false


func _get_relic_level(inventory: Node, item: Item) -> int:
	if inventory == null:
		return 0
	if bool(inventory.call("is_relic_awakened", item)):
		return 4
	return int(inventory.call("get_relic_level", item))


func _get_marble_level(item: Item) -> int:
	if _marble_upgrade_system == null:
		return 0
	if bool(_marble_upgrade_system.call("is_awakened", item.marble_type)):
		return 4
	return int(_marble_upgrade_system.call("get_level", item.marble_type))


func _get_run_health() -> int:
	var stat_system := _get_autoload_node(&"StatSystem")
	if stat_system == null:
		return 0
	return int(stat_system.call("get_stat", StatRegistryScript.RUN_HEALTH, RUN_HEALTH_ENTITY_ID))


func _set_run_health(value: int) -> void:
	var stat_system := _get_autoload_node(&"StatSystem")
	if stat_system == null:
		return
	stat_system.call("set_stat_base", RUN_HEALTH_ENTITY_ID, StatRegistryScript.RUN_HEALTH, float(maxi(0, value)))
	if _battle_health_hud != null:
		_battle_health_hud.set_health(_get_run_health())
	health_changed.emit(_get_run_health())


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
	var shop: Node = _get_autoload_node(&"Shop")
	if shop == null or not shop.has_signal(&"gold_changed"):
		return
	var callback := Callable(self, "_on_battle_health_hud_gold_changed")
	if not shop.is_connected(&"gold_changed", callback):
		shop.connect(&"gold_changed", callback)


func _refresh_battle_health_hud() -> void:
	if _battle_health_hud == null:
		return
	_battle_health_hud.set_health(_get_run_health())
	var shop: Node = _get_autoload_node(&"Shop")
	_battle_health_hud.set_gold(int(shop.get("gold")) if shop != null else 0)


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
		adjust_health_chips(delta / 2)


func _on_skill_replace_confirmed(_item: Item) -> void:
	var offer := _pending_skill_offer
	_pending_skill_offer = null
	_complete_purchase(offer, true)


func _on_skill_replace_cancelled() -> void:
	_pending_skill_offer = null


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
