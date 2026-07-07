extends Control
class_name DraftRewardPanel

signal reward_selected(item: Item)
signal draft_closed

const UI_LABEL_SETTINGS: LabelSettings = preload("res://Themes/new_label_settings.tres")
const ItemTooltipScene: PackedScene = preload("res://UI/item_tooltip.tscn")
const CoinTexture: Texture2D = preload("res://Assets/Items/Coin.png")
const ItemLevelBadgeScript: GDScript = preload("res://UI/item_level_badge.gd")
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
	_build_ui()
	hide()


func show_item_draft(items: Array[Item]) -> void:
	_build_ui()
	_is_battle_reward_mode = false
	_items = items
	_title_label.text = "Draft Reward"
	var all_blocked: bool = _all_visible_rewards_blocked()

	for index: int in range(_buttons.size()):
		var button: Button = _buttons[index]
		if all_blocked and index == 0:
			_configure_gold_compensation_button(index)
			button.show()
		elif all_blocked:
			button.set_meta("tooltip_text", "")
			ItemLevelBadgeScript.update_badge(button, 0)
			button.hide()
		elif index < _items.size():
			var item: Item = _items[index]
			_configure_item_button(index, item)
			button.disabled = not _can_add_item(item)
			button.show()
		else:
			button.set_meta("tooltip_text", "")
			_set_button_icon(index, null)
			ItemLevelBadgeScript.update_badge(button, 0)
			button.hide()

	show()
	_set_tree_paused(true)
	if is_inside_tree() and not _buttons.is_empty():
		_buttons[0].grab_focus()


func show_battle_rewards(items: Array[Item], gold_amount: int) -> void:
	_build_ui()
	_is_battle_reward_mode = true
	_battle_reward_items = items
	_battle_item_claimed.clear()
	for _item: Item in _battle_reward_items:
		_battle_item_claimed.append(false)
	_battle_reward_gold = gold_amount
	_battle_gold_claimed = gold_amount <= 0
	_title_label.text = "Battle Reward"
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
		return "Empty"
	var item_type: String = "Relic" if item.type == Item.ItemType.RELIC else "Marble"
	return "%s\n%s" % [item.title, item_type]


func _configure_item_button(index: int, item: Item) -> void:
	var button: Button = _buttons[index]
	button.tooltip_text = ""
	button.set_meta("tooltip_text", item.title if item != null else "")
	if item != null and item.icon != null:
		button.text = ""
		_set_button_icon(index, item.icon)
	else:
		button.text = _format_item_label(item)
		_set_button_icon(index, null)
	ItemLevelBadgeScript.update_badge(button, _get_item_award_level(item))


func _configure_gold_compensation_button(index: int) -> void:
	_configure_gold_button(index, _format_gold_compensation_tooltip())


func _configure_gold_button(index: int, custom_tooltip_text: String) -> void:
	var button: Button = _buttons[index]
	button.text = ""
	button.disabled = false
	button.tooltip_text = ""
	button.set_meta("tooltip_text", custom_tooltip_text)
	_set_button_icon(index, CoinTexture)
	ItemLevelBadgeScript.update_badge(button, 0)


func _format_gold_compensation_tooltip() -> String:
	return "Inventory full: take +%d Gold" % compensation_gold


func _format_gold_reward_tooltip(gold_amount: int) -> String:
	return "Take +%d Gold" % gold_amount


func _refresh_battle_reward_buttons() -> void:
	var gold_index: int = _get_battle_gold_button_index()
	for index: int in range(_buttons.size()):
		var button: Button = _buttons[index]
		button.set_meta("tooltip_text", "")
		if index < _battle_reward_items.size():
			if _battle_item_claimed[index]:
				_set_button_icon(index, null)
				ItemLevelBadgeScript.update_badge(button, 0)
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
			ItemLevelBadgeScript.update_badge(button, 0)
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


func _build_ui() -> void:
	if _button_row != null:
		return

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 98)
	center.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	_title_label = Label.new()
	_apply_label_settings(_title_label)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(_title_label)

	_button_row = HBoxContainer.new()
	_button_row.add_theme_constant_override("separation", 4)
	layout.add_child(_button_row)

	for index: int in range(3):
		var button: Button = Button.new()
		button.custom_minimum_size = ITEM_OPTION_SIZE
		button.focus_mode = Control.FOCUS_ALL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_apply_button_font(button)
		button.pressed.connect(Callable(self, "_on_button_pressed").bind(index))
		button.mouse_entered.connect(Callable(self, "_on_reward_button_mouse_entered").bind(button))
		button.mouse_exited.connect(_hide_custom_tooltip)
		_button_row.add_child(button)
		_buttons.append(button)

		var icon: TextureRect = TextureRect.new()
		icon.name = "ItemIcon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = ITEM_OPTION_SIZE
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.hide()
		button.add_child(icon)
		_button_icons.append(icon)

	_tooltip = ItemTooltipScene.instantiate() as Control
	_tooltip.name = "ItemTooltip"
	add_child(_tooltip)


func _apply_label_settings(label: Label) -> void:
	label.label_settings = UI_LABEL_SETTINGS


func _apply_button_font(button: Button) -> void:
	if UI_LABEL_SETTINGS.font != null:
		button.add_theme_font_override("font", UI_LABEL_SETTINGS.font)
	button.add_theme_font_size_override("font_size", UI_LABEL_SETTINGS.font_size)


func _on_reward_button_mouse_entered(button: Button) -> void:
	if _tooltip == null:
		return
	var text: String = str(button.get_meta("tooltip_text", ""))
	if text.is_empty():
		_hide_custom_tooltip()
		return
	if _tooltip.has_method("show_text_for_control"):
		if _is_battle_reward_mode:
			_tooltip.call("show_text_for_control", text, button, ItemTooltip.Placement.BOTTOM_RIGHT)
		else:
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


func _get_item_award_level(item: Item) -> int:
	if item == null or item.type != Item.ItemType.RELIC:
		return 0
	var inventory: Node = _get_autoload_node(&"Inventory")
	if inventory != null and inventory.has_method("get_relic_award_level"):
		return int(inventory.call("get_relic_award_level", item))
	return 1


func _get_autoload_node(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))


func _set_tree_paused(paused: bool) -> void:
	if not is_inside_tree():
		return
	get_tree().paused = paused
