extends Control
class_name DraftRewardPanel

signal reward_intent(token: RunFlowToken, draft_id: StringName, offer_id: StringName)
signal reward_continue_intent(token: RunFlowToken, draft_id: StringName)
signal reward_replacement_intent(token: RunFlowToken, replacement_token: StringName, confirmed: bool)
signal relic_replacement_selection_requested(token: RunFlowToken, replacement_token: StringName)

const CoinTexture: Texture2D = preload("res://Assets/Items/Coin.png")
const MarbleTexture: Texture2D = preload("res://Assets/Marbles/marble_icon.png")
const ItemTooltipScript: GDScript = preload("res://UI/shared/item_tooltip.gd")

var _active_offer: RewardOffer = null
var _pending_replacement: RewardResult = null
var _intent_pending := false
var _loadout: RefCounted = null
var _gold_button: Button
var _marble_button: Button
var _relic_button: Button
var _next_floor_button: Button
var _marble_selection: Control
var _dismiss_button: Button
var _back_button: Button
var _marble_cards: Array[RewardMarbleCard] = []
var _skill_replace_dialog: SkillReplaceDialog


func configure(loadout: RefCounted, _progression: RefCounted = null, _wallet: RefCounted = null) -> bool:
	unconfigure()
	if loadout == null or not is_instance_valid(loadout) or not loadout.has_method(&"current_skill"):
		return false
	_loadout = loadout
	return true


func unconfigure() -> void:
	clear_presentation()
	_loadout = null


func _ready() -> void:
	_bind_nodes()
	_connect_nodes()
	clear_presentation()


func present_offer(offer: RewardOffer) -> bool:
	_bind_nodes()
	if offer == null or offer.token == null or not offer.token.is_valid() or offer.draft_id.is_empty():
		return false
	_active_offer = offer
	_pending_replacement = null
	_intent_pending = false
	show()
	_render_offer()
	_set_tree_paused(true)
	return true


func present_ready_to_advance(token: RunFlowToken, draft_id: StringName) -> void:
	if _active_offer == null or _active_offer.token == null or token == null \
			or not _active_offer.token.matches(token) or _active_offer.draft_id != draft_id:
		return
	_intent_pending = false
	_next_floor_button.show()
	_next_floor_button.grab_focus()


func present_replacement(result: RewardResult) -> bool:
	if result == null or not result.replacement_required() or result.token == null \
			or _active_offer == null or _skill_replace_dialog == null:
		return false
	var option := result.option
	_pending_replacement = result
	if option != null and option.resolution == RewardOption.Resolution.REPLACE_RELIC:
		_skill_replace_dialog.request_relic_replace(option.item)
		return true
	var current_skill: Item = _loadout.call("current_skill") as Item if _loadout != null else null
	if option == null or option.item == null or current_skill == null:
		return false
	_skill_replace_dialog.request_replace(current_skill, option.item)
	return true


func apply_result(result: RewardResult, active_offer: RewardOffer) -> void:
	_pending_replacement = null
	_intent_pending = false
	if result == null:
		return
	if result.code == RewardResult.Code.DECLINED and active_offer != null:
		present_offer(active_offer)
		return
	if not result.was_granted() or active_offer == null:
		return
	_active_offer = active_offer
	_render_offer()


func clear_presentation() -> void:
	_pending_replacement = null
	_intent_pending = false
	_active_offer = null
	if _marble_selection != null:
		_marble_selection.hide()
	hide()
	_set_tree_paused(false)


func _render_offer() -> void:
	if _active_offer == null:
		return
	var gold := _find_gold_option()
	var relic := _find_relic_option()
	var marbles := _remaining_marbles()
	_configure_reward_row(_gold_button, gold, CoinTexture, _gold_text(gold))
	_configure_reward_row(_marble_button, null, MarbleTexture, tr("UI_REWARD_CHOOSE_MARBLE"))
	_configure_reward_row(_relic_button, relic, relic.item.icon if relic != null and relic.item != null else null, _item_title(relic.item) if relic != null else "")
	_marble_button.visible = not marbles.is_empty()
	_relic_button.visible = relic != null
	_next_floor_button.show()
	_render_marble_cards(marbles)


func _configure_reward_row(button: Button, option: RewardOption, icon: Texture2D, text: String) -> void:
	if button == null:
		return
	if button.has_method(&"set_item_tooltip"):
		var tooltip_item: Item = option.item if option != null else null
		var tooltip_level: int = option.target_level if option != null else 1
		button.call(&"set_item_tooltip", tooltip_item, tooltip_level)
	button.icon = icon
	button.expand_icon = true
	button.text = text
	button.disabled = option != null and (option.consumed or _intent_pending)
	button.visible = option != null or button == _marble_button


func _render_marble_cards(options: Array[RewardOption]) -> void:
	for index in range(_marble_cards.size()):
		var card: RewardMarbleCard = _marble_cards[index]
		if index >= options.size():
			card.clear_reward()
			card.hide()
			continue
		var option: RewardOption = options[index]
		card.show()
		card.set_reward(option.item, option.target_level, option.is_upgrade)
		card.disabled = _intent_pending


func _on_gold_pressed() -> void:
	_claim(_find_gold_option())


func _on_relic_pressed() -> void:
	_claim(_find_relic_option())


func _on_marble_pressed() -> void:
	if not _remaining_marbles().is_empty() and not _intent_pending:
		_marble_selection.show()


func _on_marble_card_pressed(index: int) -> void:
	var marbles := _remaining_marbles()
	if index >= 0 and index < marbles.size():
		_claim(marbles[index])


func _on_next_floor_pressed() -> void:
	if _active_offer != null and _active_offer.token != null:
		reward_continue_intent.emit(_active_offer.token, _active_offer.draft_id)


func _claim(option: RewardOption) -> void:
	if option == null or option.consumed or _active_offer == null or _intent_pending:
		return
	_intent_pending = true
	_marble_selection.hide()
	reward_intent.emit(_active_offer.token, _active_offer.draft_id, option.offer_id)


func _on_skill_replace_confirmed(_item: Item) -> void:
	if _pending_replacement == null:
		return
	var result := _pending_replacement
	_pending_replacement = null
	if result.option != null and result.option.resolution == RewardOption.Resolution.REPLACE_RELIC:
		relic_replacement_selection_requested.emit(result.token, result.replacement_token)
		return
	reward_replacement_intent.emit(result.token, result.replacement_token, true)


func _on_skill_replace_cancelled() -> void:
	if _pending_replacement == null:
		return
	var result := _pending_replacement
	_pending_replacement = null
	reward_replacement_intent.emit(result.token, result.replacement_token, false)


func _find_gold_option() -> RewardOption:
	if _active_offer == null:
		return null
	for option in _active_offer.remaining_options():
		if option.kind == RewardOption.Kind.GOLD:
			return option
	return null


func _find_relic_option() -> RewardOption:
	if _active_offer == null:
		return null
	for option in _active_offer.remaining_options():
		if option.kind == RewardOption.Kind.ITEM and option.item != null and option.item.type == Item.ItemType.RELIC:
			return option
	return null


func _remaining_marbles() -> Array[RewardOption]:
	var result: Array[RewardOption] = []
	if _active_offer == null:
		return result
	for option in _active_offer.remaining_options():
		if option.kind == RewardOption.Kind.ITEM and option.item != null and option.item.type == Item.ItemType.MARBLE:
			result.append(option)
	return result


func _gold_text(option: RewardOption) -> String:
	return "x %d" % option.gold_amount if option != null else ""


func _item_title(item: Item) -> String:
	return ItemTooltipScript.item_title(item)


func _bind_nodes() -> void:
	if _gold_button != null:
		return
	_gold_button = get_node_or_null("Center/Panel/Margin/Layout/RewardRows/GoldRewardButton") as Button
	_marble_button = get_node_or_null("Center/Panel/Margin/Layout/RewardRows/MarbleRewardButton") as Button
	_relic_button = get_node_or_null("Center/Panel/Margin/Layout/RewardRows/RelicRewardButton") as Button
	_next_floor_button = get_node_or_null("NextFloor") as Button
	_marble_selection = get_node_or_null("MarbleSelection") as Control
	_dismiss_button = get_node_or_null("MarbleSelection/DismissButton") as Button
	_back_button = get_node_or_null("MarbleSelection/Center/Panel/Margin/Layout/BackButton") as Button
	_skill_replace_dialog = get_node_or_null("SkillReplaceDialog") as SkillReplaceDialog
	var card_row := get_node_or_null("MarbleSelection/Center/Panel/Margin/Layout/CardRow") as HBoxContainer
	if card_row == null:
		return
	for child in card_row.get_children():
		if child is RewardMarbleCard:
			var card := child as RewardMarbleCard
			_marble_cards.append(card)


func _connect_nodes() -> void:
	if _gold_button != null and not _gold_button.pressed.is_connected(_on_gold_pressed):
		_gold_button.pressed.connect(_on_gold_pressed)
	if _marble_button != null and not _marble_button.pressed.is_connected(_on_marble_pressed):
		_marble_button.pressed.connect(_on_marble_pressed)
	if _relic_button != null and not _relic_button.pressed.is_connected(_on_relic_pressed):
		_relic_button.pressed.connect(_on_relic_pressed)
	if _next_floor_button != null and not _next_floor_button.pressed.is_connected(_on_next_floor_pressed):
		_next_floor_button.pressed.connect(_on_next_floor_pressed)
	if _dismiss_button != null and not _dismiss_button.pressed.is_connected(_marble_selection.hide):
		_dismiss_button.pressed.connect(_marble_selection.hide)
	if _back_button != null and not _back_button.pressed.is_connected(_marble_selection.hide):
		_back_button.pressed.connect(_marble_selection.hide)
	for index in range(_marble_cards.size()):
		var callback := Callable(self, "_on_marble_card_pressed").bind(index)
		if not _marble_cards[index].pressed.is_connected(callback):
			_marble_cards[index].pressed.connect(callback)
	if _skill_replace_dialog != null:
		if not _skill_replace_dialog.confirmed.is_connected(_on_skill_replace_confirmed):
			_skill_replace_dialog.confirmed.connect(_on_skill_replace_confirmed)
		if not _skill_replace_dialog.cancelled.is_connected(_on_skill_replace_cancelled):
			_skill_replace_dialog.cancelled.connect(_on_skill_replace_cancelled)


func _set_tree_paused(paused: bool) -> void:
	if is_inside_tree():
		get_tree().paused = paused
