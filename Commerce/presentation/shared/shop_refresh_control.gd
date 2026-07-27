extends Control
class_name ShopRefreshControl

signal refresh_requested

@onready var _refresh_button: Button = get_node_or_null("RefreshButton") as Button
@onready var _refresh_cost: Label = get_node_or_null("RefreshCost") as Label


func _ready() -> void:
	if _refresh_button != null and not _refresh_button.pressed.is_connected(_on_refresh_button_pressed):
		_refresh_button.pressed.connect(_on_refresh_button_pressed)


func set_refresh_state(cost: int, enabled: bool) -> void:
	if _refresh_button != null:
		_refresh_button.disabled = not enabled
	if _refresh_cost != null:
		_refresh_cost.text = tr("UI_SHOP_REFRESH_FREE") if cost == 0 \
			else tr("UI_SHOP_REFRESH_COST") % cost


func _on_refresh_button_pressed() -> void:
	refresh_requested.emit()
