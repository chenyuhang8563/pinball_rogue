extends Button
class_name RewardMarbleCard

const ItemTooltipScript: GDScript = preload("res://UI/shared/item_tooltip.gd")

var _item: Item = null
var _target_level: int = 1
var _is_upgrade: bool = false
var _icon_view: ItemIconView = null
var _title_label: Label = null
var _description_label: RichTextLabel = null
var _state_player: AnimationPlayer = null


func _ready() -> void:
	_bind_nodes()
	_connect_localization()
	_refresh_content()


func set_reward(item: Item, target_level: int, is_upgrade: bool) -> void:
	_item = item
	_target_level = clampi(target_level, 1, 4)
	_is_upgrade = is_upgrade
	_bind_nodes()
	_refresh_content()


func clear_reward() -> void:
	_item = null
	_target_level = 1
	_is_upgrade = false
	_bind_nodes()
	_refresh_content()


func target_level() -> int:
	return _target_level


func is_upgrade_reward() -> bool:
	return _is_upgrade


func main_description_bbcode() -> String:
	return ItemTooltipScript.description_bbcode(_item, _target_level)


func _refresh_content() -> void:
	if _icon_view != null:
		if _item == null:
			_icon_view.clear()
		else:
			_icon_view.set_texture(_item.icon)
			_icon_view.set_level(_target_level)
	if _title_label != null:
		_title_label.text = ItemTooltipScript.item_title(_item)
	if _description_label != null:
		_description_label.text = main_description_bbcode()
	if _state_player != null:
		_state_player.play(&"upgrade" if _is_upgrade and _item != null else &"regular")
		_state_player.advance(0.0)


func _bind_nodes() -> void:
	if _icon_view != null:
		return
	_icon_view = get_node_or_null("Content/IconArea/Icon") as ItemIconView
	_title_label = get_node_or_null("Content/TitleLabel") as Label
	_description_label = get_node_or_null("Content/DescriptionLabel") as RichTextLabel
	_state_player = get_node_or_null("UpgradeStatePlayer") as AnimationPlayer


func _connect_localization() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var localization := tree.root.get_node_or_null(NodePath("Localization"))
	if localization == null or not localization.has_signal(&"locale_changed"):
		return
	var callback := Callable(self, "_on_locale_changed")
	if not localization.is_connected(&"locale_changed", callback):
		localization.connect(&"locale_changed", callback)


func _on_locale_changed(_locale_code: String) -> void:
	_refresh_content()
