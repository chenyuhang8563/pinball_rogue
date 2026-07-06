extends Control
class_name MarbleUpgradePanel

signal upgrade_selected(option: Dictionary)

const UI_LABEL_SETTINGS: LabelSettings = preload("res://Themes/new_label_settings.tres")
const ITEM_OPTION_SIZE: Vector2 = Vector2(66, 72)

var _options: Array[Dictionary] = []
var _buttons: Array[Button] = []
var _button_icons: Array[TextureRect] = []
var _title_label: Label
var _description_label: Label
var _button_row: HBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide()


func show_upgrades(options: Array[Dictionary]) -> void:
	_build_ui()
	_options = options
	_title_label.text = "Upgrade Marble"
	_description_label.text = "Choose one marble to upgrade."

	for index: int in range(_buttons.size()):
		var button: Button = _buttons[index]
		if index < _options.size():
			var option: Dictionary = _options[index]
			button.text = _format_button_text(option)
			button.disabled = false
			_set_button_icon(index, option.get("icon") as Texture2D)
			button.show()
		else:
			button.text = ""
			_set_button_icon(index, null)
			button.hide()

	show()
	_set_tree_paused(true)
	if is_inside_tree() and not _buttons.is_empty():
		_buttons[0].grab_focus()


func _format_button_text(option: Dictionary) -> String:
	var title: String = String(option.get("title", "Marble"))
	var next_level: int = int(option.get("next_level", 1))
	var description: String = String(option.get("description", ""))
	return "%s\nLv.%d\n%s" % [title, next_level, description]


func _on_button_pressed(index: int) -> void:
	if index < 0 or index >= _options.size():
		return
	var option: Dictionary = _options[index]
	hide()
	_set_tree_paused(false)
	upgrade_selected.emit(option)


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
	panel.custom_minimum_size = Vector2(240, 146)
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
		button.custom_minimum_size = ITEM_OPTION_SIZE
		button.focus_mode = Control.FOCUS_ALL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_apply_button_font(button)
		button.pressed.connect(Callable(self, "_on_button_pressed").bind(index))
		_button_row.add_child(button)
		_buttons.append(button)

		var icon: TextureRect = TextureRect.new()
		icon.name = "MarbleIcon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(24, 24)
		icon.anchor_left = 0.5
		icon.anchor_right = 0.5
		icon.offset_left = -12.0
		icon.offset_right = 12.0
		icon.offset_top = 4.0
		icon.offset_bottom = 28.0
		icon.hide()
		button.add_child(icon)
		_button_icons.append(icon)


func _apply_label_settings(label: Label) -> void:
	label.label_settings = UI_LABEL_SETTINGS


func _apply_button_font(button: Button) -> void:
	if UI_LABEL_SETTINGS.font != null:
		button.add_theme_font_override("font", UI_LABEL_SETTINGS.font)
	button.add_theme_font_size_override("font_size", max(6, UI_LABEL_SETTINGS.font_size - 1))


func _set_button_icon(index: int, texture: Texture2D) -> void:
	if index < 0 or index >= _button_icons.size():
		return
	var icon: TextureRect = _button_icons[index]
	icon.texture = texture
	icon.visible = texture != null


func _set_tree_paused(paused: bool) -> void:
	if not is_inside_tree():
		return
	get_tree().paused = paused
