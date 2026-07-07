extends Control
class_name ItemTooltip

const UI_LABEL_SETTINGS: LabelSettings = preload("res://Themes/new_label_settings.tres")
const PADDING: Vector2 = Vector2(8, 4)
const SCREEN_MARGIN: Vector2 = Vector2(4.0, 4.0)

enum Placement {
	ABOVE,
	BOTTOM_RIGHT,
}

var _panel: PanelContainer
var _label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bind_nodes()
	hide()


func show_item_for_control(item: Item, target: Control) -> void:
	if item == null:
		hide_tooltip()
		return
	show_text_for_control(item.title, target)


func show_text_for_control(text: String, _target: Control = null, _placement: Placement = Placement.ABOVE) -> void:
	if text.is_empty():
		hide_tooltip()
		return

	_bind_nodes()
	if _panel == null or _label == null:
		return
	_label.text = text
	var tooltip_size: Vector2 = _calculate_tooltip_size(text)
	_panel.custom_minimum_size = tooltip_size
	_panel.size = tooltip_size

	show()
	_panel.show()
	move_to_front()
	_panel.global_position = _get_ui_bottom_right_position(tooltip_size)


func hide_tooltip() -> void:
	hide()
	if _panel != null:
		_panel.hide()


func _bind_nodes() -> void:
	if _panel != null:
		return
	_panel = get_node_or_null("TooltipPanel") as PanelContainer
	_label = get_node_or_null("TooltipPanel/TooltipMargin/TooltipLabel") as Label
	if _label != null:
		_label.label_settings = UI_LABEL_SETTINGS


func _calculate_tooltip_size(text: String) -> Vector2:
	if UI_LABEL_SETTINGS.font == null:
		return Vector2(maxf(48.0, float(text.length() * UI_LABEL_SETTINGS.font_size)), 18.0)
	var text_size: Vector2 = UI_LABEL_SETTINGS.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UI_LABEL_SETTINGS.font_size)
	return Vector2(maxf(48.0, text_size.x + PADDING.x), maxf(18.0, text_size.y + PADDING.y))


func _get_ui_bottom_right_position(tooltip_size: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	return Vector2(
		maxf(0.0, viewport_size.x - tooltip_size.x - SCREEN_MARGIN.x),
		maxf(0.0, viewport_size.y - tooltip_size.y - SCREEN_MARGIN.y)
	)
