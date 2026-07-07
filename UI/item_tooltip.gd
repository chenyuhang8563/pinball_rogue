extends Control
class_name ItemTooltip

const UI_LABEL_SETTINGS: LabelSettings = preload("res://Themes/new_label_settings.tres")
const PADDING: Vector2 = Vector2(8, 4)
const GAP: float = 4.0

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
	_build_ui()
	hide()


func show_item_for_control(item: Item, target: Control) -> void:
	if item == null:
		hide_tooltip()
		return
	show_text_for_control(item.title, target)


func show_text_for_control(text: String, target: Control, placement: Placement = Placement.ABOVE) -> void:
	if text.is_empty() or target == null:
		hide_tooltip()
		return

	_build_ui()
	_label.text = text
	var tooltip_size: Vector2 = _calculate_tooltip_size(text)
	_panel.custom_minimum_size = tooltip_size
	_panel.size = tooltip_size

	show()
	_panel.show()
	move_to_front()

	var target_rect: Rect2 = target.get_global_rect()
	var viewport_size: Vector2 = get_viewport_rect().size
	var target_position: Vector2 = _get_target_position(target_rect, tooltip_size, placement)
	target_position.x = clampf(target_position.x, 0.0, maxf(0.0, viewport_size.x - tooltip_size.x))
	target_position.y = clampf(target_position.y, 0.0, maxf(0.0, viewport_size.y - tooltip_size.y))

	_panel.global_position = target_position


func hide_tooltip() -> void:
	hide()
	if _panel != null:
		_panel.hide()


func _build_ui() -> void:
	if _panel != null:
		return

	_panel = PanelContainer.new()
	_panel.name = "TooltipPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "TooltipMargin"
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 2)
	_panel.add_child(margin)

	_label = Label.new()
	_label.name = "TooltipLabel"
	_label.label_settings = UI_LABEL_SETTINGS
	margin.add_child(_label)


func _calculate_tooltip_size(text: String) -> Vector2:
	if UI_LABEL_SETTINGS.font == null:
		return Vector2(maxf(48.0, float(text.length() * UI_LABEL_SETTINGS.font_size)), 18.0)
	var text_size: Vector2 = UI_LABEL_SETTINGS.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UI_LABEL_SETTINGS.font_size)
	return Vector2(maxf(48.0, text_size.x + PADDING.x), maxf(18.0, text_size.y + PADDING.y))


func _get_target_position(target_rect: Rect2, tooltip_size: Vector2, placement: Placement) -> Vector2:
	match placement:
		Placement.BOTTOM_RIGHT:
			return target_rect.position + Vector2(target_rect.size.x + GAP, target_rect.size.y + GAP)
		_:
			return target_rect.position + Vector2(0.0, -(tooltip_size.y + GAP))
