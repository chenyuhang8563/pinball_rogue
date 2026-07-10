extends Control
class_name DraftRewardPanel

signal reward_selected(item: Item)
signal draft_closed

const UIFontsScript: GDScript = preload("res://UI/fonts.gd")
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
var _buttons: Array[Button] = []
var _button_icons: Array[TextureRect] = []
var _title_label: Label
var _button_row: HBoxContainer
var _tooltip: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind_nodes()
	_connect_localization()
	_connect_buttons()
	hide()


func show_item_draft(items: Array[Item]) -> void:
	_bind_nodes()
	_connect_buttons()
	if not _has_required_nodes():
		return
	_is_battle_reward_mode = false
	_items = items
	_title_label.text = tr("UI_DRAFT_REWARD_TITLE")
	var all_blocked: bool = _all_visible_rewards_blocked()

	for index: int in range(_buttons.size()):
		var button: Button = _buttons[index]
		if all_blocked and index == 0:
			_configure_gold_compensation_button(index)
			button.show()
		elif all_blocked:
			button.set_meta("tooltip_text", "")
			button.hide()
		elif index < _items.size():
			var item: Item = _items[index]
			_configure_item_button(index, item)
			button.disabled = not _can_add_item(item)
			button.show()
		else:
			button.set_meta("tooltip_text", "")
			_set_button_icon(index, null)
			button.hide()

	show()
	_set_tree_paused(true)
	if is_inside_tree() and not _buttons.is_empty():
		_buttons[0].grab_focus()


func show_battle_rewards(items: Array[Item], gold_amount: int) -> void:
	_bind_nodes()
	_connect_buttons()
	if not _has_required_nodes():
		return
	_is_battle_reward_mode = true
	_battle_reward_items = items
	_battle_item_claimed.clear()
	for _item: Item in _battle_reward_items:
		_battle_item_claimed.append(false)
	_battle_reward_gold = gold_amount
	_battle_gold_claimed = gold_amount <= 0
	_title_label.text = tr("UI_BATTLE_REWARD_TITLE")
	_refresh_battle_reward_buttons()

	show()
	_set_tree_paused(true)
	for button: Button in _buttons:
		if button.visible and not button.disabled:
			button.grab_focus()
			break


func choose_reward(index: int) -> void:
	if _is_battle_reward_mode:
		choose_battle_reward(index)
		return

	if _all_visible_rewards_blocked():
		_grant_gold_compensation()
		hide()
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

	hide()
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
	var inventory: Node = _get_autoload_node(&"Inventory")
	if inventory == null or not inventory.has_method("add_item"):
		return false
	if inventory.has_method("can_add_item") and not bool(inventory.call("can_add_item", item)):
		return false
	return bool(inventory.call("add_item", item))


func _can_add_item(item: Item) -> bool:
	var inventory: Node = _get_autoload_node(&"Inventory")
	if inventory == null:
		return false
	if inventory.has_method("can_add_item"):
		return bool(inventory.call("can_add_item", item))
	return inventory.has_method("add_item")


func _grant_gold_compensation() -> void:
	_grant_gold(compensation_gold)


func _grant_gold(amount: int) -> void:
	var shop: Node = _get_autoload_node(&"Shop")
	if shop != null:
		shop.set("gold", int(shop.get("gold")) + amount)


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
	return "%s\n%s" % [_item_title(item), item_type]


func _configure_item_button(index: int, item: Item) -> void:
	var button: Button = _buttons[index]
	button.tooltip_text = ""
	button.set_meta("tooltip_text", _item_title(item) if item != null else "")
	if item != null:
		button.set_meta("tooltip_item", item)
	elif button.has_meta("tooltip_item"):
		button.remove_meta("tooltip_item")
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
	button.tooltip_text = ""
	button.set_meta("tooltip_text", custom_tooltip_text)
	if button.has_meta("tooltip_item"):
		button.remove_meta("tooltip_item")
	_set_button_icon(index, CoinTexture)


func _format_gold_compensation_tooltip() -> String:
	return tr("UI_INVENTORY_FULL_GOLD_TOOLTIP") % compensation_gold


func _format_gold_reward_tooltip(gold_amount: int) -> String:
	return tr("UI_TAKE_GOLD_TOOLTIP") % gold_amount


func _refresh_battle_reward_buttons() -> void:
	var gold_index: int = _get_battle_gold_button_index()
	for index: int in range(_buttons.size()):
		var button: Button = _buttons[index]
		button.set_meta("tooltip_text", "")
		if index < _battle_reward_items.size():
			if _battle_item_claimed[index]:
				_set_button_icon(index, null)
				button.hide()
				continue
			var item: Item = _battle_reward_items[index]
			if _can_add_item(item):
				_configure_item_button(index, item)
			else:
				_configure_gold_compensation_button(index)
			button.disabled = false
			button.show()
		elif index == gold_index and not _battle_gold_claimed:
			_configure_gold_button(index, _format_gold_reward_tooltip(_battle_reward_gold))
			button.show()
		else:
			_set_button_icon(index, null)
			button.hide()


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
	hide()
	_set_tree_paused(false)
	draft_closed.emit()


func _bind_nodes() -> void:
	if _button_row != null:
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title_label = get_node_or_null("Center/Panel/MarginContainer/Layout/TitleLabel") as Label
	_button_row = get_node_or_null("Center/Panel/MarginContainer/Layout/ButtonRow") as HBoxContainer
	_tooltip = get_node_or_null("ItemTooltip") as Control
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
		var entered_callback := Callable(self, "_on_reward_button_mouse_entered").bind(button)
		if not button.mouse_entered.is_connected(entered_callback):
			button.mouse_entered.connect(entered_callback)
		if not button.mouse_exited.is_connected(_hide_custom_tooltip):
			button.mouse_exited.connect(_hide_custom_tooltip)


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


func _on_reward_button_mouse_entered(button: Button) -> void:
	if _tooltip == null:
		return
	var item: Item = null
	if button.has_meta("tooltip_item"):
		item = button.get_meta("tooltip_item") as Item
	if item != null and _tooltip.has_method("show_item_for_control"):
		_tooltip.call("show_item_for_control", item, button)
		return
	var text: String = str(button.get_meta("tooltip_text", ""))
	if text.is_empty():
		_hide_custom_tooltip()
		return
	if _tooltip.has_method("show_text_for_control"):
		_tooltip.call("show_text_for_control", text, button)


func _hide_custom_tooltip() -> void:
	if _tooltip != null:
		if _tooltip.has_method("hide_tooltip"):
			_tooltip.call("hide_tooltip")


func _set_button_icon(index: int, texture: Texture2D) -> void:
	if index < 0 or index >= _button_icons.size():
		return
	var icon: TextureRect = _button_icons[index]
	icon.texture = texture
	icon.visible = texture != null


func _get_autoload_node(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))


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
	if _is_battle_reward_mode:
		_title_label.text = tr("UI_BATTLE_REWARD_TITLE")
		_refresh_battle_reward_buttons()
	else:
		show_item_draft(_items)
