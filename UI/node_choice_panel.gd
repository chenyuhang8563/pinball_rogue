extends Control
class_name NodeChoicePanel

signal option_selected(option: RunNodeOption)
signal message_dismissed

const UI_LABEL_SETTINGS: LabelSettings = preload("res://Themes/new_label_settings.tres")
const LocaleFontSettingsScript: GDScript = preload("res://UI/locale_font_settings.gd")

var _options: Array[RunNodeOption] = []
var _buttons: Array[Button] = []
var _title_label: Label
var _description_label: Label
var _button_row: HBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind_nodes()
	_connect_buttons()
	_connect_locale_changed()
	hide()


func show_options(options: Array[RunNodeOption]) -> void:
	_bind_nodes()
	_connect_buttons()
	_apply_button_fonts()
	if not _has_required_nodes():
		return
	_options = options
	_title_label.text = tr("UI_CHOOSE_NEXT_NODE_TITLE")
	_description_label.text = ""
	_description_label.hide()

	for index: int in range(_buttons.size()):
		var button: Button = _buttons[index]
		if index < _options.size():
			var option: RunNodeOption = _options[index]
			button.text = tr(option.title)
			button.disabled = false
			button.show()
		else:
			button.hide()

	show()
	_set_tree_paused(true)
	if is_inside_tree() and not _buttons.is_empty():
		_buttons[0].grab_focus()


func show_message(title: String, description: String) -> void:
	_bind_nodes()
	_connect_buttons()
	_apply_button_fonts()
	if not _has_required_nodes():
		return
	_options.clear()
	_title_label.text = tr(title)
	_description_label.text = tr(description)
	_description_label.visible = not _description_label.text.is_empty()
	for index: int in range(_buttons.size()):
		var button: Button = _buttons[index]
		button.text = tr("UI_OK") if index == 0 else ""
		button.visible = index == 0
		button.disabled = false
	show()
	_set_tree_paused(true)
	if is_inside_tree() and not _buttons.is_empty():
		_buttons[0].grab_focus()


func _on_button_pressed(index: int) -> void:
	if index >= _options.size():
		hide()
		_set_tree_paused(false)
		message_dismissed.emit()
		return

	var option: RunNodeOption = _options[index]
	hide()
	_set_tree_paused(false)
	option_selected.emit(option)


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
	LocaleFontSettingsScript.apply_button_font(button, UI_LABEL_SETTINGS.font_size)


func _apply_button_fonts() -> void:
	for button: Button in _buttons:
		_apply_button_font(button)


func _connect_locale_changed() -> void:
	var localization: Node = get_node_or_null("/root/Localization")
	if localization == null or not localization.has_signal(&"locale_changed"):
		return
	var callback := Callable(self, "_on_locale_changed")
	if not localization.is_connected(&"locale_changed", callback):
		localization.connect(&"locale_changed", callback)


func _on_locale_changed(_locale_code: String = "") -> void:
	if visible and not _options.is_empty():
		show_options(_options)
	elif visible:
		_apply_button_fonts()


func _set_tree_paused(paused: bool) -> void:
	if not is_inside_tree():
		return
	get_tree().paused = paused
