extends Control
class_name NodeChoicePanel

signal option_selected(option: RunNodeOption)
signal message_dismissed

const UI_LABEL_SETTINGS: LabelSettings = preload("res://Themes/new_label_settings.tres")

var _options: Array[RunNodeOption] = []
var _buttons: Array[Button] = []
var _title_label: Label
var _description_label: Label
var _button_row: HBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide()


func show_options(options: Array[RunNodeOption]) -> void:
	_build_ui()
	_options = options
	_title_label.text = "Choose Next Node"
	_description_label.text = "Pick one path for the next step."

	for index: int in range(_buttons.size()):
		var button: Button = _buttons[index]
		if index < _options.size():
			var option: RunNodeOption = _options[index]
			button.text = option.title
			button.disabled = false
			button.show()
		else:
			button.hide()

	show()
	_set_tree_paused(true)
	if is_inside_tree() and not _buttons.is_empty():
		_buttons[0].grab_focus()


func show_message(title: String, description: String) -> void:
	_build_ui()
	_options.clear()
	_title_label.text = title
	_description_label.text = description
	for index: int in range(_buttons.size()):
		var button: Button = _buttons[index]
		button.text = "OK" if index == 0 else ""
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


func _build_ui() -> void:
	if _button_row != null:
		return

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 1.0)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 150)
	center.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)

	_title_label = Label.new()
	_apply_label_settings(_title_label)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(_title_label)

	_description_label = Label.new()
	_apply_label_settings(_description_label)
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_description_label)

	_button_row = HBoxContainer.new()
	_button_row.add_theme_constant_override("separation", 4)
	layout.add_child(_button_row)

	for index: int in range(3):
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(66, 64)
		button.focus_mode = Control.FOCUS_ALL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_apply_button_font(button)
		button.pressed.connect(Callable(self, "_on_button_pressed").bind(index))
		_button_row.add_child(button)
		_buttons.append(button)


func _apply_label_settings(label: Label) -> void:
	label.label_settings = UI_LABEL_SETTINGS


func _apply_button_font(button: Button) -> void:
	if UI_LABEL_SETTINGS.font != null:
		button.add_theme_font_override("font", UI_LABEL_SETTINGS.font)
	button.add_theme_font_size_override("font_size", UI_LABEL_SETTINGS.font_size)


func _set_tree_paused(paused: bool) -> void:
	if not is_inside_tree():
		return
	get_tree().paused = paused
