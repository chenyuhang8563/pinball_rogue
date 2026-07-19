extends Control
class_name DraftRewardPanel

signal reward_selected(item: Item)
signal draft_closed

enum RewardMode {
	ITEM_DRAFT,
	NORMAL_EXCLUSIVE,
	ELITE_CLAIM_ALL,
}

const UIFontsScript: GDScript = preload("res://UI/fonts.gd")
const RewardTooltipButtonScript: Script = preload("res://UI/reward_tooltip_button.gd")
const UI_FONT_SIZE: int = 12
const CoinTexture: Texture2D = preload("res://Assets/Items/Coin.png")
const ITEM_OPTION_SIZE: Vector2 = Vector2(32, 32)

@export var compensation_gold: int = 15

var _items: Array[Item] = []
var _battle_reward_items: Array[Item] = []
var _battle_item_claimed: Array[bool] = []
var _battle_reward_gold: int = 0
var _battle_gold_claimed: bool = false
var _is_battle_reward_mode: bool = false
var _reward_mode: RewardMode = RewardMode.ITEM_DRAFT
var _normal_options: Array[BattleRewardOption] = []
var _pending_normal_skill_index: int = -1
var _normal_choice_resolved: bool = false
var _buttons: Array[Button] = []
var _button_icons: Array[TextureRect] = []
var _title_label: Label
var _button_row: HBoxContainer
var _skill_replace_dialog: SkillReplaceDialog
var _loadout: RefCounted = null
var _progression: RefCounted = null
var _wallet: RefCounted = null


func configure(loadout: RefCounted, progression: RefCounted, wallet: RefCounted) -> bool:
	if not _has_port_api(loadout, [&"find_owned", &"can_add", &"add", &"current_skill", &"replace_skill"]) \
			or not _has_port_api(progression, [&"can_upgrade", &"upgrade_one", &"reset_skill"]) \
			or not _has_port_api(wallet, [&"credit"]):
		return false
	_loadout = loadout
	_progression = progression
	_wallet = wallet
	return true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind_nodes()
	_connect_localization()
	_connect_buttons()
	_connect_skill_replace_dialog()
	_play_panel_visibility(false)


func show_item_draft(items: Array[Item]) -> void:
	_bind_nodes()
	_connect_buttons()
	if not _has_required_nodes():
		return
	_is_battle_reward_mode = false
	_reward_mode = RewardMode.ITEM_DRAFT
	_items = items
	_title_label.text = tr("UI_DRAFT_REWARD_TITLE")
	var all_blocked: bool = _all_visible_rewards_blocked()

	for index: int in range(_buttons.size()):
		var button: Button = _buttons[index]
		if all_blocked and index == 0:
			_configure_gold_compensation_button(index)
			_play_button_visibility(button, true)
		elif all_blocked:
			_play_button_visibility(button, false)
		elif index < _items.size():
			var item: Item = _items[index]
			_configure_item_button(index, item)
			button.disabled = not _can_add_item(item)
			_play_button_visibility(button, true)
		else:
			_configure_gold_button(index, "")
			_set_button_icon(index, null)
			_play_button_visibility(button, false)

	_play_panel_visibility(true)
	_set_tree_paused(true)
	if is_inside_tree() and not _buttons.is_empty():
		_buttons[0].grab_focus()


func show_battle_rewards(items: Array[Item], gold_amount: int) -> void:
	_bind_nodes()
	_connect_buttons()
	if not _has_required_nodes():
		return
	_is_battle_reward_mode = true
	_reward_mode = RewardMode.ELITE_CLAIM_ALL
	_battle_reward_items = items
	_battle_item_claimed.clear()
	for _item: Item in _battle_reward_items:
		_battle_item_claimed.append(false)
	_battle_reward_gold = gold_amount
	_battle_gold_claimed = gold_amount <= 0
	_title_label.text = tr("UI_BATTLE_REWARD_TITLE")
	_refresh_battle_reward_buttons()

	_play_panel_visibility(true)
	_set_tree_paused(true)
	for button: Button in _buttons:
		if button.visible and not button.disabled:
			button.grab_focus()
			break


func show_normal_battle_rewards(options: Array[BattleRewardOption]) -> void:
	_bind_nodes()
	_connect_buttons()
	_connect_skill_replace_dialog()
	if not _has_required_nodes():
		return
	_reward_mode = RewardMode.NORMAL_EXCLUSIVE
	_is_battle_reward_mode = true
	_normal_options = options.duplicate()
	_pending_normal_skill_index = -1
	_normal_choice_resolved = false
	_title_label.text = tr("UI_BATTLE_REWARD_CHOICE_TITLE")
	_refresh_normal_reward_buttons()
	_play_panel_visibility(true)
	_set_tree_paused(true)
	for button: Button in _buttons:
		if button.visible and not button.disabled:
			button.grab_focus()
			break


func choose_reward(index: int) -> void:
	if _reward_mode == RewardMode.NORMAL_EXCLUSIVE:
		_choose_normal_reward(index)
		return
	if _reward_mode == RewardMode.ELITE_CLAIM_ALL:
		choose_battle_reward(index)
		return

	if _all_visible_rewards_blocked():
		_grant_gold_compensation()
		_play_panel_visibility(false)
		_set_tree_paused(false)
		draft_closed.emit()
		return

	if index < 0 or index >= _items.size():
		return

	var item: Item = _items[index]
	if _grant_item(item):
		reward_selected.emit(item)
	else:
		_grant_gold_compensation()

	_play_panel_visibility(false)
	_set_tree_paused(false)
	draft_closed.emit()


func choose_battle_reward(index: int) -> void:
	if index < 0 or index >= _buttons.size():
		return

	if index < _battle_reward_items.size():
		if _battle_item_claimed[index]:
			return
		var item: Item = _battle_reward_items[index]
		if _grant_item(item):
			reward_selected.emit(item)
		else:
			_grant_gold_compensation()
		_battle_item_claimed[index] = true
	elif index == _get_battle_gold_button_index():
		if _battle_gold_claimed:
			return
		_grant_gold(_battle_reward_gold)
		_battle_gold_claimed = true
	else:
		return

	if _all_battle_rewards_claimed():
		_close_panel()
		return

	_refresh_battle_reward_buttons()


func _grant_item(item: Item) -> bool:
	if item == null or _loadout == null or not is_instance_valid(_loadout):
		return false
	var owned: Item = _loadout.call("find_owned", item) as Item
	if owned != null:
		return owned.type == Item.ItemType.RELIC \
			and _progression != null and is_instance_valid(_progression) \
			and bool(_progression.call("can_upgrade", owned)) \
			and bool(_progression.call("upgrade_one", owned))
	return bool(_loadout.call("can_add", item)) and bool(_loadout.call("add", item))


func _can_add_item(item: Item) -> bool:
	if item == null or _loadout == null or not is_instance_valid(_loadout):
		return false
	var owned: Item = _loadout.call("find_owned", item) as Item
	if owned != null:
		return owned.type == Item.ItemType.RELIC \
			and _progression != null and is_instance_valid(_progression) \
			and bool(_progression.call("can_upgrade", owned))
	return bool(_loadout.call("can_add", item))


func _grant_gold_compensation() -> void:
	_grant_gold(compensation_gold)


func _grant_gold(amount: int) -> void:
	if _wallet != null and is_instance_valid(_wallet):
		_wallet.call("credit", amount)


func _all_visible_rewards_blocked() -> bool:
	for item: Item in _items:
		if _can_add_item(item):
			return false
	return not _items.is_empty()


func _on_button_pressed(index: int) -> void:
	choose_reward(index)


func _format_item_label(item: Item) -> String:
	if item == null:
		return tr("UI_EMPTY")
	var item_type: String = tr("UI_RELIC_TYPE") if item.type == Item.ItemType.RELIC else tr("UI_MARBLE_TYPE")
	if item.type == Item.ItemType.SKILL:
		item_type = tr("UI_SKILL_TYPE")
	return "%s\n%s" % [_item_title(item), item_type]


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


func _configure_gold_compensation_button(index: int) -> void:
	_configure_gold_button(index, _format_gold_compensation_tooltip())


func _configure_gold_button(index: int, custom_tooltip_text: String) -> void:
	var button: Button = _buttons[index]
	button.text = ""
	button.disabled = false
	if button.get_script() == RewardTooltipButtonScript:
		button.call("set_text_tooltip", custom_tooltip_text)
	_set_button_icon(index, CoinTexture)


func _format_gold_compensation_tooltip() -> String:
	return tr("UI_INVENTORY_FULL_GOLD_TOOLTIP") % compensation_gold


func _format_gold_reward_tooltip(gold_amount: int) -> String:
	return tr("UI_TAKE_GOLD_TOOLTIP") % gold_amount


func _refresh_battle_reward_buttons() -> void:
	var gold_index: int = _get_battle_gold_button_index()
	for index: int in range(_buttons.size()):
		var button: Button = _buttons[index]
		if index < _battle_reward_items.size():
			if _battle_item_claimed[index]:
				_set_button_icon(index, null)
				_play_button_visibility(button, false)
				continue
			var item: Item = _battle_reward_items[index]
			if _can_add_item(item):
				_configure_item_button(index, item)
			else:
				_configure_gold_compensation_button(index)
			button.disabled = false
			_play_button_visibility(button, true)
		elif index == gold_index and not _battle_gold_claimed:
			_configure_gold_button(index, _format_gold_reward_tooltip(_battle_reward_gold))
			_play_button_visibility(button, true)
		else:
			_configure_gold_button(index, "")
			_set_button_icon(index, null)
			_play_button_visibility(button, false)


func _refresh_normal_reward_buttons() -> void:
	for index: int in range(_buttons.size()):
		var button := _buttons[index]
		if index >= _normal_options.size():
			_configure_gold_button(index, "")
			_set_button_icon(index, null)
			_play_button_visibility(button, false)
			continue
		var option := _normal_options[index]
		if option.kind == BattleRewardOption.Kind.GOLD:
			_configure_gold_button(index, _format_gold_reward_tooltip(option.gold_amount))
		else:
			_configure_item_button(index, option.item)
		button.disabled = false
		_play_button_visibility(button, true)


func _choose_normal_reward(index: int) -> void:
	if _normal_choice_resolved or index < 0 or index >= _normal_options.size() or _pending_normal_skill_index >= 0:
		return
	var option := _normal_options[index]
	if option.kind == BattleRewardOption.Kind.GOLD:
		_normal_choice_resolved = true
		_grant_gold(option.gold_amount)
		_close_panel()
		return
	var item := option.item
	if item == null:
		return
	if item.type == Item.ItemType.SKILL:
		var current_skill: Item = _loadout.call("current_skill") as Item \
			if _loadout != null and is_instance_valid(_loadout) else null
		if current_skill != null:
			_pending_normal_skill_index = index
			if _skill_replace_dialog != null:
				_skill_replace_dialog.request_replace(current_skill, item)
			return
	if _grant_item(item):
		_normal_choice_resolved = true
		reward_selected.emit(item)
		_close_panel()
	elif item.type == Item.ItemType.RELIC \
			and _loadout != null and is_instance_valid(_loadout) \
			and _loadout.call("find_owned", item) != null:
		_normal_choice_resolved = true
		_grant_gold_compensation()
		_close_panel()


func _get_battle_gold_button_index() -> int:
	if _battle_reward_gold <= 0:
		return -1
	return _battle_reward_items.size()


func _all_battle_rewards_claimed() -> bool:
	for claimed: bool in _battle_item_claimed:
		if not claimed:
			return false
	return _battle_gold_claimed


func _close_panel() -> void:
	_play_panel_visibility(false)
	_set_tree_paused(false)
	draft_closed.emit()


func _play_panel_visibility(should_show: bool) -> void:
	var player := get_node_or_null("VisibilityPlayer") as AnimationPlayer
	if player == null:
		return
	player.play(&"show" if should_show else &"hide")
	player.advance(0.0)


func _play_button_visibility(button: Button, should_show: bool) -> void:
	var player := button.get_node_or_null("VisibilityPlayer") as AnimationPlayer
	if player == null:
		return
	player.play(&"show" if should_show else &"hide")
	player.advance(0.0)


func _bind_nodes() -> void:
	if _button_row != null:
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
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
		_apply_button_font(button)
		_buttons.append(button)
		var icon: TextureRect = button.get_node_or_null("ItemIcon") as TextureRect
		_button_icons.append(icon)


func _connect_buttons() -> void:
	for index: int in range(_buttons.size()):
		var button: Button = _buttons[index]
		var pressed_callback := Callable(self, "_on_button_pressed").bind(index)
		if not button.pressed.is_connected(pressed_callback):
			button.pressed.connect(pressed_callback)


func _connect_skill_replace_dialog() -> void:
	if _skill_replace_dialog == null:
		_skill_replace_dialog = get_node_or_null("SkillReplaceDialog") as SkillReplaceDialog
	if _skill_replace_dialog == null:
		return
	var confirm_callback := Callable(self, "_on_normal_skill_replace_confirmed")
	if not _skill_replace_dialog.confirmed.is_connected(confirm_callback):
		_skill_replace_dialog.confirmed.connect(confirm_callback)
	var cancel_callback := Callable(self, "_on_normal_skill_replace_cancelled")
	if not _skill_replace_dialog.cancelled.is_connected(cancel_callback):
		_skill_replace_dialog.cancelled.connect(cancel_callback)


func _on_normal_skill_replace_confirmed(item: Item) -> void:
	if _pending_normal_skill_index < 0:
		return
	if _loadout == null or not is_instance_valid(_loadout):
		_pending_normal_skill_index = -1
		return
	var previous_skill := _loadout.call("current_skill") as Item
	if bool(_loadout.call("replace_skill", item)):
		if previous_skill != null and _progression != null and is_instance_valid(_progression):
			_progression.call("reset_skill", previous_skill.id)
		_normal_choice_resolved = true
		reward_selected.emit(item)
		_pending_normal_skill_index = -1
		_close_panel()
		return
	_pending_normal_skill_index = -1


func _on_normal_skill_replace_cancelled() -> void:
	_pending_normal_skill_index = -1
	_refresh_normal_reward_buttons()


func _has_required_nodes() -> bool:
	if _title_label == null or _button_row == null or _buttons.is_empty() or _button_icons.size() != _buttons.size():
		return false
	for icon: TextureRect in _button_icons:
		if icon == null:
			return false
	return true


func _apply_label_settings(label: Label) -> void:
		UIFontsScript.apply_label_settings(label, UI_FONT_SIZE)


func _apply_button_font(button: Button) -> void:
		UIFontsScript.apply_button_font(button, UI_FONT_SIZE)


func _set_button_icon(index: int, texture: Texture2D) -> void:
	if index < 0 or index >= _button_icons.size():
		return
	var icon: TextureRect = _button_icons[index]
	icon.texture = texture


func _get_autoload_node(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))


func _has_port_api(port: RefCounted, methods: Array[StringName]) -> bool:
	if port == null or not is_instance_valid(port):
		return false
	for method: StringName in methods:
		if not port.has_method(method):
			return false
	return true


func _set_tree_paused(paused: bool) -> void:
	if not is_inside_tree():
		return
	get_tree().paused = paused


func _item_title(item: Item) -> String:
	if item == null:
		return ""
	if item.id.is_empty():
		return tr(item.title)
	var key := "ITEM_%s_TITLE" % item.id.to_upper()
	var translated := tr(key)
	return translated if translated != key else tr(item.title)


func _connect_localization() -> void:
	var localization := _get_autoload_node(&"Localization")
	if localization == null or not localization.has_signal(&"locale_changed"):
		return
	var callback := Callable(self, "_on_locale_changed")
	if not localization.is_connected(&"locale_changed", callback):
		localization.connect(&"locale_changed", callback)


func _on_locale_changed(_locale_code: String) -> void:
	if not visible:
		return
	if _reward_mode == RewardMode.NORMAL_EXCLUSIVE:
		_title_label.text = tr("UI_BATTLE_REWARD_CHOICE_TITLE")
		_refresh_normal_reward_buttons()
	elif _reward_mode == RewardMode.ELITE_CLAIM_ALL:
		_title_label.text = tr("UI_BATTLE_REWARD_TITLE")
		_refresh_battle_reward_buttons()
	else:
		show_item_draft(_items)
