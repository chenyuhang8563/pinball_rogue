extends Control
class_name MarbleUpgradePanel

signal upgrade_selected(option: Dictionary)

const UI_LABEL_SETTINGS: LabelSettings = preload("res://Themes/new_label_settings.tres")
const ItemLevelResolverScript: GDScript = preload("res://UI/item_level_resolver.gd")
const ITEM_OPTION_SIZE: Vector2 = Vector2(68, 98)

var _options: Array[Dictionary] = []
var _buttons: Array[Button] = []
var _title_label: Label
var _description_label: Label
var _button_row: HBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind_nodes()
	_connect_localization()
	_connect_buttons()
	hide()


func show_upgrades(options: Array[Dictionary]) -> void:
	_bind_nodes()
	_connect_buttons()
	if not _has_required_nodes():
		return
	_options = options
	_title_label.text = tr("UI_UPGRADE_MARBLE_TITLE")
	_description_label.text = tr("UI_UPGRADE_MARBLE_DESC")

	for index: int in range(_buttons.size()):
		var button: Button = _buttons[index]
		if index < _options.size():
			var option: Dictionary = _options[index]
			if button.has_method("set_option"):
				button.call(
					"set_option",
					option.get("icon") as Texture2D,
					_translate_option_text(String(option.get("title", "UI_MARBLE_TYPE"))),
					_translate_option_text(String(option.get("description", ""))),
					ItemLevelResolverScript.get_upgrade_option_level(option)
				)
			button.disabled = false
			button.show()
		else:
			if button.has_method("clear_option"):
				button.call("clear_option")
			button.hide()

	show()
	_set_tree_paused(true)
	if is_inside_tree() and not _buttons.is_empty():
		_buttons[0].grab_focus()


func _on_button_pressed(index: int) -> void:
	if index < 0 or index >= _options.size():
		return
	var option: Dictionary = _options[index]
	hide()
	_set_tree_paused(false)
	upgrade_selected.emit(option)


func _bind_nodes() -> void:
	if _button_row != null:
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title_label = get_node_or_null("Center/Panel/MarginContainer/Layout/TitleLabel") as Label
	_description_label = get_node_or_null("Center/Panel/MarginContainer/Layout/DescriptionLabel") as Label
	_button_row = get_node_or_null("Center/Panel/MarginContainer/Layout/ButtonRow") as HBoxContainer
	_buttons.clear()
	if _button_row == null:
		return
	for child: Node in _button_row.get_children():
		if child is Button:
			var button: Button = child as Button
			button.custom_minimum_size = ITEM_OPTION_SIZE
			button.focus_mode = Control.FOCUS_ALL
			_apply_button_font(button)
			_buttons.append(button)


func _connect_buttons() -> void:
	for index: int in range(_buttons.size()):
		var callback := Callable(self, "_on_button_pressed").bind(index)
		if not _buttons[index].pressed.is_connected(callback):
			_buttons[index].pressed.connect(callback)


func _has_required_nodes() -> bool:
	return _title_label != null and _description_label != null and _button_row != null and _buttons.size() > 0


func _apply_label_settings(label: Label) -> void:
	label.label_settings = UI_LABEL_SETTINGS


func _apply_button_font(button: Button) -> void:
	if UI_LABEL_SETTINGS.font != null:
		button.add_theme_font_override("font", UI_LABEL_SETTINGS.font)
	button.add_theme_font_size_override("font_size", max(6, UI_LABEL_SETTINGS.font_size - 1))


func _set_tree_paused(paused: bool) -> void:
	if not is_inside_tree():
		return
	get_tree().paused = paused


func _translate_option_text(key_or_text: String) -> String:
	if key_or_text.is_empty():
		return ""
	return tr(key_or_text)


func _connect_localization() -> void:
	var localization := _get_autoload_node(&"Localization")
	if localization == null or not localization.has_signal(&"locale_changed"):
		return
	var callback := Callable(self, "_on_locale_changed")
	if not localization.is_connected(&"locale_changed", callback):
		localization.connect(&"locale_changed", callback)


func _on_locale_changed(_locale_code: String) -> void:
	if visible:
		show_upgrades(_options)


func _get_autoload_node(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))
