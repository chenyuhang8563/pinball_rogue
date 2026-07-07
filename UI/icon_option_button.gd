extends Button
class_name IconOptionButton

const UI_LABEL_SETTINGS: LabelSettings = preload("res://Themes/new_label_settings.tres")

var _icon_view: Control
var _title_label: Label
var _description_label: Label


func _ready() -> void:
	_bind_nodes()
	if not _has_required_nodes():
		return
	_apply_label_settings(_title_label, -2)
	_apply_label_settings(_description_label, -3)
	text = ""
	clip_text = true
	focus_mode = Control.FOCUS_ALL


func set_option(texture: Texture2D, title: String, description: String, level: int) -> void:
	_bind_nodes()
	if not _has_required_nodes():
		return
	text = ""
	_set_icon_texture(texture)
	_title_label.text = title
	_description_label.text = description
	_set_icon_level(level)


func clear_option() -> void:
	_bind_nodes()
	if not _has_required_nodes():
		return
	text = ""
	_clear_icon()
	_title_label.text = ""
	_description_label.text = ""


func _bind_nodes() -> void:
	if _icon_view != null:
		return
	_icon_view = get_node_or_null("OptionContent/OptionLayout/OptionIconArea/Icon") as Control
	_title_label = get_node_or_null("OptionContent/OptionLayout/OptionTitle") as Label
	_description_label = get_node_or_null("OptionContent/OptionLayout/OptionDescription") as Label


func _has_required_nodes() -> bool:
	return _icon_view != null and _title_label != null and _description_label != null


func _set_icon_texture(texture: Texture2D) -> void:
	if _icon_view != null and _icon_view.has_method("set_texture"):
		_icon_view.call("set_texture", texture)


func _set_icon_level(level: int) -> void:
	if _icon_view != null and _icon_view.has_method("set_level"):
		_icon_view.call("set_level", level)


func _clear_icon() -> void:
	if _icon_view != null and _icon_view.has_method("clear"):
		_icon_view.call("clear")


func _apply_label_settings(label: Label, size_delta: int) -> void:
	if label == null:
		return
	var settings := LabelSettings.new()
	settings.font = UI_LABEL_SETTINGS.font
	settings.font_size = max(6, UI_LABEL_SETTINGS.font_size + size_delta)
	settings.font_color = UI_LABEL_SETTINGS.font_color
	settings.outline_color = UI_LABEL_SETTINGS.outline_color
	settings.outline_size = UI_LABEL_SETTINGS.outline_size
	label.label_settings = settings
