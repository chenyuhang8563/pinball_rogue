extends Button
class_name IconOptionButton

var _icon_view: Control
var _title_label: Label
var _description_label: Label


func _ready() -> void:
	_bind_nodes()
	if not _has_required_nodes():
		return
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
