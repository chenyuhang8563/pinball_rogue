extends Control
class_name DraftRewardPanel

signal reward_intent(
	token: RunFlowToken,
	draft_id: StringName,
	offer_id: StringName
)
signal reward_replacement_intent(
	token: RunFlowToken,
	replacement_token: StringName,
	confirmed: bool
)

const RewardTooltipButtonScript: Script = preload("res://UI/reward_tooltip_button.gd")
const CoinTexture: Texture2D = preload("res://Assets/Items/Coin.png")

var _active_offer: RewardOffer = null
var _visible_options: Array[RewardOption] = []
var _pending_replacement: RewardResult = null
var _intent_pending: bool = false
var _buttons: Array[Button] = []
var _button_icons: Array[TextureRect] = []
var _title_label: Label = null
var _button_row: HBoxContainer = null
var _skill_replace_dialog: SkillReplaceDialog = null
var _loadout: RefCounted = null


## The loadout is presentation-only here: it supplies the currently equipped
## skill name for the existing replacement dialog. Reward settlement remains
## exclusively inside RewardService through RunFlowController commands.
func configure(
	loadout: RefCounted,
	_progression: RefCounted = null,
	_wallet: RefCounted = null
) -> bool:
	unconfigure()
	if loadout == null or not is_instance_valid(loadout) \
			or not loadout.has_method(&"current_skill"):
		return false
	_loadout = loadout
	return true


func unconfigure() -> void:
	clear_presentation()
	_loadout = null


func _ready() -> void:
	_bind_nodes()
	_connect_localization()
	_connect_buttons()
	_connect_skill_replace_dialog()
	_play_panel_visibility(false)


func present_offer(offer: RewardOffer) -> bool:
	_bind_nodes()
	_connect_buttons()
	_connect_skill_replace_dialog()
	if offer == null or offer.token == null or not offer.token.is_valid() \
			or offer.draft_id.is_empty() or offer.consumed or not _has_required_nodes():
		return false
	_pending_replacement = null
	_intent_pending = false
	_active_offer = offer
	_visible_options = offer.remaining_options()
	if _visible_options.is_empty():
		return false
	_render_offer()
	_play_panel_visibility(true)
	_set_tree_paused(true)
	_focus_first_available_button()
	return true


func present_replacement(result: RewardResult) -> bool:
	if result == null or not result.replacement_required() or result.token == null \
			or _active_offer == null or result.draft_id != _active_offer.draft_id \
			or not _active_offer.token.matches(result.token) \
			or _skill_replace_dialog == null or _loadout == null:
		return false
	var option: RewardOption = result.option
	var current_skill: Item = _loadout.call("current_skill") as Item
	if option == null or option.item == null or current_skill == null:
		return false
	_pending_replacement = result
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
	if not result.was_granted():
		return
	if active_offer == null or active_offer.completed:
		clear_presentation()
	else:
		present_offer(active_offer)


func clear_presentation() -> void:
	_pending_replacement = null
	_intent_pending = false
	if _skill_replace_dialog != null and _skill_replace_dialog.is_request_pending():
		_skill_replace_dialog.cancel_replace_request()
	_active_offer = null
	_visible_options.clear()
	_play_panel_visibility(false)
	_set_tree_paused(false)


func _on_button_pressed(index: int) -> void:
	if _active_offer == null or _active_offer.consumed \
			or index < 0 or index >= _visible_options.size() \
			or _pending_replacement != null or _intent_pending:
		return
	var option: RewardOption = _visible_options[index]
	if option == null or option.consumed:
		return
	_intent_pending = true
	_disable_buttons()
	reward_intent.emit(_active_offer.token, _active_offer.draft_id, option.offer_id)


func _on_skill_replace_confirmed(_item: Item) -> void:
	_emit_replacement_intent(true)


func _on_skill_replace_cancelled() -> void:
	_emit_replacement_intent(false)


func _emit_replacement_intent(confirmed: bool) -> void:
	if _pending_replacement == null or _pending_replacement.token == null:
		return
	var result: RewardResult = _pending_replacement
	_pending_replacement = null
	_intent_pending = true
	_disable_buttons()
	reward_replacement_intent.emit(
		result.token,
		result.replacement_token,
		confirmed
	)


func _render_offer() -> void:
	match _active_offer.mode:
		RewardOffer.Mode.NORMAL_EXCLUSIVE:
			_title_label.text = tr("UI_BATTLE_REWARD_CHOICE_TITLE")
		RewardOffer.Mode.ELITE_CLAIM_ALL:
			_title_label.text = tr("UI_BATTLE_REWARD_TITLE")
		_:
			_title_label.text = tr("UI_DRAFT_REWARD_TITLE")
	for index: int in range(_buttons.size()):
		var button: Button = _buttons[index]
		if index >= _visible_options.size():
			_set_button_icon(index, null)
			_play_button_visibility(button, false)
			continue
		var option: RewardOption = _visible_options[index]
		if option.kind == RewardOption.Kind.GOLD:
			_configure_gold_button(index, option.gold_amount)
		else:
			_configure_item_button(index, option.item)
		button.disabled = false
		_play_button_visibility(button, true)


func _configure_item_button(index: int, item: Item) -> void:
	var button: Button = _buttons[index]
	if button.get_script() == RewardTooltipButtonScript:
		button.call("set_item_tooltip", item)
	if item != null and item.icon != null:
		button.text = ""
		_set_button_icon(index, item.icon)
	else:
		button.text = _format_item_label(item)
		_set_button_icon(index, null)


func _configure_gold_button(index: int, amount: int) -> void:
	var button: Button = _buttons[index]
	button.text = ""
	if button.get_script() == RewardTooltipButtonScript:
		button.call("set_text_tooltip", tr("UI_TAKE_GOLD_TOOLTIP") % amount)
	_set_button_icon(index, CoinTexture)


func _format_item_label(item: Item) -> String:
	if item == null:
		return tr("UI_EMPTY")
	var item_type: String = tr("UI_RELIC_TYPE") if item.type == Item.ItemType.RELIC \
		else tr("UI_MARBLE_TYPE")
	if item.type == Item.ItemType.SKILL:
		item_type = tr("UI_SKILL_TYPE")
	return "%s\n%s" % [_item_title(item), item_type]


func _disable_buttons() -> void:
	for button: Button in _buttons:
		button.disabled = true


func _focus_first_available_button() -> void:
	if not is_inside_tree():
		return
	for button: Button in _buttons:
		if button.visible and not button.disabled:
			button.grab_focus()
			return


func _play_panel_visibility(should_show: bool) -> void:
	var player: AnimationPlayer = get_node_or_null("VisibilityPlayer") as AnimationPlayer
	if player == null:
		return
	player.play(&"show" if should_show else &"hide")
	player.advance(0.0)


func _play_button_visibility(button: Button, should_show: bool) -> void:
	var player: AnimationPlayer = button.get_node_or_null("VisibilityPlayer") as AnimationPlayer
	if player == null:
		return
	player.play(&"show" if should_show else &"hide")
	player.advance(0.0)


func _bind_nodes() -> void:
	if _button_row != null:
		return
	_title_label = get_node_or_null("Center/Panel/MarginContainer/Layout/TitleLabel") as Label
	_button_row = get_node_or_null("Center/Panel/MarginContainer/Layout/ButtonRow") as HBoxContainer
	_skill_replace_dialog = get_node_or_null("SkillReplaceDialog") as SkillReplaceDialog
	_buttons.clear()
	_button_icons.clear()
	if _button_row == null:
		return
	for child: Node in _button_row.get_children():
		if not child is Button:
			continue
		var button: Button = child as Button
		_buttons.append(button)
		_button_icons.append(button.get_node_or_null("ItemIcon") as TextureRect)


func _connect_buttons() -> void:
	for index: int in range(_buttons.size()):
		var callback: Callable = Callable(self, "_on_button_pressed").bind(index)
		if not _buttons[index].pressed.is_connected(callback):
			_buttons[index].pressed.connect(callback)


func _connect_skill_replace_dialog() -> void:
	if _skill_replace_dialog == null:
		_skill_replace_dialog = get_node_or_null("SkillReplaceDialog") as SkillReplaceDialog
	if _skill_replace_dialog == null:
		return
	if not _skill_replace_dialog.confirmed.is_connected(_on_skill_replace_confirmed):
		_skill_replace_dialog.confirmed.connect(_on_skill_replace_confirmed)
	if not _skill_replace_dialog.cancelled.is_connected(_on_skill_replace_cancelled):
		_skill_replace_dialog.cancelled.connect(_on_skill_replace_cancelled)


func _has_required_nodes() -> bool:
	if _title_label == null or _button_row == null or _buttons.is_empty() \
			or _button_icons.size() != _buttons.size():
		return false
	for icon: TextureRect in _button_icons:
		if icon == null:
			return false
	return true


func _set_button_icon(index: int, texture: Texture2D) -> void:
	if index < 0 or index >= _button_icons.size():
		return
	_button_icons[index].texture = texture


func _set_tree_paused(paused: bool) -> void:
	if is_inside_tree():
		get_tree().paused = paused


func _item_title(item: Item) -> String:
	if item == null:
		return ""
	if item.id.is_empty():
		return tr(item.title)
	var key: String = "ITEM_%s_TITLE" % item.id.to_upper()
	var translated: String = tr(key)
	return translated if translated != key else tr(item.title)


func _connect_localization() -> void:
	var localization: Node = _get_autoload_node(&"Localization")
	if localization == null or not localization.has_signal(&"locale_changed"):
		return
	var callback: Callable = Callable(self, "_on_locale_changed")
	if not localization.is_connected(&"locale_changed", callback):
		localization.connect(&"locale_changed", callback)


func _on_locale_changed(_locale_code: String) -> void:
	if _active_offer != null and visible:
		_render_offer()


func _get_autoload_node(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))
