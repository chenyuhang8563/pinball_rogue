extends Control
class_name DevilShop

const StatRegistryScript: GDScript = preload("res://Stats/stat_registry.gd")
const ItemLevelResolverScript: GDScript = preload("res://UI/item_level_resolver.gd")
const ShopItemPolicyScript: GDScript = preload("res://Shop/shop_item_policy.gd")
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
	if _skill_dialog != null and _skill_dialog.is_request_pending():
		_skill_dialog.cancel_replace_request()
	hide()
	get_tree().paused = false
	closed.emit()


## Generates full-price acquisition quotes and discounted upgrades up to level IV.
func generate_upgrade_offers(inventory: Node, marble_upgrade_system: Node) -> Array[DevilShopOffer]:
	offers.clear()
	current_offer_index = 0
	_marble_upgrade_system = marble_upgrade_system
	if config == null or inventory == null or marble_upgrade_system == null:
		return offers
	var candidates := _get_eligible_upgrade_items(inventory)
	while offers.size() < config.stock_count and not candidates.is_empty():
		var item: Item = candidates.pick_random()
		candidates.erase(item)
		var owned_item := _find_owned_matching_item(item, inventory)
		var is_upgrade := owned_item != null
		var current_level := _get_item_level(inventory, owned_item) if is_upgrade else 0
		var target_level := _pick_target_level_from(current_level)
		if target_level <= current_level:
			continue
		var full_target_price := _get_level_price(item, target_level)
		var quoted_price := full_target_price - _get_level_price(item, current_level) if is_upgrade else full_target_price
		offers.append(DevilShopOffer.new(item, target_level, quoted_price, is_upgrade, full_target_price))
	return offers


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
		var equipped_skill := inventory.get("skill_item") as Item
		if not _items_have_same_identity(equipped_skill, offer.item):
			_pending_skill_offer = offer
			if _skill_dialog != null:
				_skill_dialog.request_replace(equipped_skill, offer.item)
			return false
	return _complete_purchase(offer, false)


func _complete_purchase(offer: DevilShopOffer, replace_skill: bool) -> bool:
	if offer == null or offer != get_current_offer() or not can_confirm_purchase():
		return false
	var inventory: Node = _get_autoload_node(&"Inventory")
	var shop: Node = _get_autoload_node(&"Shop")
	if inventory == null or shop == null:
		return false
	if not grant_levelled_item(inventory, offer, _marble_upgrade_system, replace_skill):
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


## 发放报价物品并提升至目标等级；依赖参数用于测试及无 Autoload 的调用方。
func grant_levelled_item(
	inventory: Node,
	offer: DevilShopOffer,
	marble_upgrade_system: Node,
	replace_skill: bool = false
) -> bool:
	if inventory == null or offer == null or offer.item == null or marble_upgrade_system == null:
		return false
	_marble_upgrade_system = marble_upgrade_system
	if offer.target_level < 2 or offer.target_level > 4:
		return false
	var owned_item := _find_owned_matching_item(offer.item, inventory)
	if owned_item == null:
		if not _can_acquire_new_item(inventory, offer.item):
			return false
		if not _can_reach_target(inventory, offer.item, 1, offer.target_level):
			return false
	elif not _can_reach_target(inventory, owned_item, _get_item_level(inventory, owned_item), offer.target_level):
		return false
	if owned_item == null:
		var equipped_skill := inventory.get("skill_item") as Item
		if offer.item.type == Item.ItemType.SKILL and equipped_skill != null:
			if not replace_skill or not bool(inventory.call("replace_skill", offer.item)):
				return false
			if marble_upgrade_system.has_method("reset_skill_level"):
				marble_upgrade_system.call("reset_skill_level", equipped_skill.id)
		elif not bool(inventory.call("add_item", offer.item)):
			return false
		owned_item = offer.item
	while _get_item_level(inventory, owned_item) < offer.target_level:
		if not bool(marble_upgrade_system.call("upgrade_item", owned_item, inventory)):
			return false
	return _get_item_level(inventory, owned_item) == offer.target_level


func _generate_offers() -> void:
	var inventory: Node = _get_autoload_node(&"Inventory")
	generate_upgrade_offers(inventory, _marble_upgrade_system)
	offer_changed.emit(get_current_offer())
	_refresh_ui()


func _get_eligible_upgrade_items(inventory: Node) -> Array[Item]:
	var result: Array[Item] = []
	if config == null or inventory == null or _marble_upgrade_system == null:
		return result
	for candidate: Item in config.item_pool:
		if candidate == null:
			continue
		var owned_item := _find_owned_matching_item(candidate, inventory)
		var eligible_item: Item = null
		if owned_item != null:
			if _can_upgrade_item(inventory, owned_item):
				eligible_item = owned_item
		elif _can_acquire_new_item(inventory, candidate):
			eligible_item = candidate
		if eligible_item == null:
			continue
		var already_listed := false
		for existing_item: Item in result:
			if _items_have_same_identity(existing_item, eligible_item):
				already_listed = true
				break
		if not already_listed:
			result.append(eligible_item)
	return result


func _find_owned_matching_item(candidate: Item, inventory: Node) -> Item:
	return ShopItemPolicyScript.find_owned_item(candidate, inventory)


func _items_have_same_identity(first: Item, second: Item) -> bool:
	return ShopItemPolicyScript.has_same_identity(first, second)


func _can_upgrade_item(inventory: Node, item: Item) -> bool:
	if item == null or _marble_upgrade_system == null:
		return false
	return bool(_marble_upgrade_system.call("can_upgrade_item", item, inventory))


func _can_acquire_new_item(inventory: Node, item: Item) -> bool:
	if inventory == null or item == null or not _can_upgrade_item(inventory, item):
		return false
	if item.type == Item.ItemType.SKILL:
		var equipped_skill := inventory.get("skill_item") as Item
		if equipped_skill != null:
			return not _items_have_same_identity(equipped_skill, item)
		return inventory.has_method("can_add_item") and bool(inventory.call("can_add_item", item))
	return inventory.has_method("can_add_item") and bool(inventory.call("can_add_item", item))


func _can_reach_target(inventory: Node, item: Item, current_level: int, target_level: int) -> bool:
	if item == null or current_level < 1 or target_level < 2 or target_level > 4:
		return false
	if current_level >= target_level:
		return false
	return _can_upgrade_item(inventory, item)


func _pick_target_level_from(current_level: int) -> int:
	if config == null:
		return 0
	var choices: Array[int] = []
	for level: int in [2, 3, 4]:
		if level > current_level and int(config.level_weights.get(level, 1)) > 0:
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


func _get_level_price(item: Item, level: int) -> int:
	if item == null or level <= 0:
		return 0
	var multiplier: float = float(config.level_price_multipliers.get(level, 1.0)) if config != null else 1.0
	return roundi(item.price * multiplier)


func _can_grant_offer(offer: DevilShopOffer) -> bool:
	var inventory: Node = _get_autoload_node(&"Inventory")
	if inventory == null or offer == null or offer.item == null:
		return false
	var owned_item := _find_owned_matching_item(offer.item, inventory)
	if owned_item == null:
		return _can_acquire_new_item(inventory, offer.item) \
				and _can_reach_target(inventory, offer.item, 1, offer.target_level)
	return _can_reach_target(inventory, owned_item, _get_item_level(inventory, owned_item), offer.target_level)


func _get_item_level(inventory: Node, item: Item) -> int:
	return ShopItemPolicyScript.get_level(item, inventory, _marble_upgrade_system)


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
		adjust_health_chips(roundi(float(delta) / 2.0))


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
