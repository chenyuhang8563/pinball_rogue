extends Control
class_name ItemTooltip

const UI_LABEL_SETTINGS: LabelSettings = preload("res://Themes/new_label_settings.tres")
const PADDING: Vector2 = Vector2(8, 4)
const SCREEN_MARGIN: Vector2 = Vector2(4.0, 4.0)
const MIN_WRAP_WIDTH: float = 160.0

enum Placement {
	ABOVE,
	BOTTOM_RIGHT,
}

var _panel: PanelContainer
var _label: Label
var _description_label: Label


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
	var title: String = _translated_item_text(item, "TITLE", item.title)
	var description: String = _translated_item_text(item, "DESC", item.description)
	show_text_for_control(title, target, Placement.ABOVE, description)


func show_text_for_control(
	text: String,
	_target: Control = null,
	_placement: Placement = Placement.ABOVE,
	description: String = ""
) -> void:
	if text.is_empty():
		hide_tooltip()
		return

	_bind_nodes()
	if _panel == null or _label == null:
		return
	var tooltip_size: Vector2 = _calculate_tooltip_size(text, description)
	var display_description: String = _wrap_text_to_width(description, tooltip_size.x - PADDING.x)
	_label.text = text
	if _description_label != null:
		_description_label.text = display_description
		_description_label.visible = not description.is_empty()
		_description_label.custom_minimum_size = Vector2(
			tooltip_size.x - PADDING.x,
			_text_height(display_description, tooltip_size.x - PADDING.x)
		) if not description.is_empty() else Vector2.ZERO
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
	_label = get_node_or_null("TooltipPanel/TooltipMargin/TooltipLayout/TooltipLabel") as Label
	_description_label = get_node_or_null("TooltipPanel/TooltipMargin/TooltipLayout/DescriptionLabel") as Label
	if _label != null:
		_label.label_settings = UI_LABEL_SETTINGS
	if _description_label != null:
		_description_label.label_settings = UI_LABEL_SETTINGS
		_description_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		_description_label.clip_text = true


func _calculate_tooltip_size(text: String, description: String = "") -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var max_width: float = maxf(MIN_WRAP_WIDTH, viewport_size.x - (SCREEN_MARGIN.x * 2.0) - PADDING.x)
	if UI_LABEL_SETTINGS.font == null:
		var fallback_width: float = minf(max_width, maxf(48.0, float(maxi(text.length(), description.length()) * UI_LABEL_SETTINGS.font_size)))
		var fallback_lines: int = 1 + (0 if description.is_empty() else 1)
		return Vector2(fallback_width + PADDING.x, maxf(18.0, float(fallback_lines * UI_LABEL_SETTINGS.font_size) + PADDING.y))
	var title_size: Vector2 = UI_LABEL_SETTINGS.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UI_LABEL_SETTINGS.font_size)
	var content_width: float = minf(max_width, maxf(48.0, title_size.x))
	var content_height: float = maxf(float(UI_LABEL_SETTINGS.font_size), title_size.y)
	if not description.is_empty():
		var description_size: Vector2 = UI_LABEL_SETTINGS.font.get_multiline_string_size(
			description,
			HORIZONTAL_ALIGNMENT_LEFT,
			max_width,
			UI_LABEL_SETTINGS.font_size,
			-1,
			TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_GRAPHEME_BOUND
		)
		content_width = minf(max_width, maxf(content_width, description_size.x))
		var wrapped_description: String = _wrap_text_to_width(description, content_width)
		content_height += maxf(description_size.y, _text_height(wrapped_description, content_width)) + 2.0
	return Vector2(content_width + PADDING.x, maxf(18.0, content_height + PADDING.y))


func _translated_item_text(item: Item, suffix: String, fallback: String) -> String:
	if item.id.is_empty():
		return tr(fallback)
	var key: String = "ITEM_%s_%s" % [item.id.to_upper(), suffix]
	var translated: String = tr(key)
	if translated != key:
		return translated
	return tr(fallback)


func _wrap_text_to_width(text: String, max_width: float) -> String:
	if text.is_empty() or UI_LABEL_SETTINGS.font == null:
		return text
	var lines: Array[String] = []
	var current_line: String = ""
	for index: int in range(text.length()):
		var character: String = text.substr(index, 1)
		if character == "\n":
			lines.append(current_line)
			current_line = ""
			continue
		var candidate: String = current_line + character
		var candidate_size: Vector2 = UI_LABEL_SETTINGS.font.get_string_size(
			candidate,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			UI_LABEL_SETTINGS.font_size
		)
		if not current_line.is_empty() and candidate_size.x > max_width:
			lines.append(current_line)
			current_line = character.strip_edges(true, false)
		else:
			current_line = candidate
	lines.append(current_line)
	return "\n".join(lines)


func _text_height(text: String, width: float) -> float:
	if text.is_empty():
		return 0.0
	var line_count := text.count("\n") + 1
	var fallback_height := float(line_count) * float(UI_LABEL_SETTINGS.font_size + 2)
	if UI_LABEL_SETTINGS.font == null:
		return fallback_height
	var measured_size := UI_LABEL_SETTINGS.font.get_multiline_string_size(
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		width,
		UI_LABEL_SETTINGS.font_size,
		-1,
		TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_GRAPHEME_BOUND
	)
	return maxf(fallback_height, measured_size.y + 2.0)


func _get_ui_bottom_right_position(tooltip_size: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	return Vector2(
		maxf(0.0, viewport_size.x - tooltip_size.x - SCREEN_MARGIN.x),
		maxf(0.0, viewport_size.y - tooltip_size.y - SCREEN_MARGIN.y)
	)
