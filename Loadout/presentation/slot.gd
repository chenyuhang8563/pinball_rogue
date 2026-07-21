extends Panel

const ItemTooltipScene: PackedScene = preload("res://UI/shared/item_tooltip.tscn")

signal purchase_requested(offer_id: StringName)

var _is_affordable: bool = true
var offer: RefCounted = null


## 将报价数据写入场景中已有节点；布局和显隐由场景动画负责。
func set_offer(value: RefCounted) -> void:
	offer = value
	item = value.item if value != null else null
	if value == null:
		_clear_offer_content()
		_refresh_offer_presentation()
		return
	var icon: Node = get_node_or_null("Icon")
	if icon != null and icon.has_method("set_level"):
		icon.call("set_level", value.target_level)
	var price_label := get_node_or_null("Price") as Label
	if price_label != null:
		price_label.text = "$ " + str(value.price)
	_refresh_offer_presentation()


## 返回场景动画应使用的新商品、升级或折扣升级状态。
func get_offer_presentation_state() -> StringName:
	if offer == null or not bool(offer.is_upgrade):
		return &"regular"
	if int(offer.original_price) > int(offer.price):
		return &"discounted"
	return &"upgrade"


func _clear_offer_content() -> void:
	for node_name: String in ["Price", "OriginalCurrency", "OriginalPrice", "Title", "Type"]:
		var label := get_node_or_null(node_name) as Label
		if label != null:
			label.text = ""
	var icon: Node = get_node_or_null("Icon")
	if icon != null and icon.has_method("clear"):
		icon.call("clear")


func _refresh_offer_presentation() -> void:
	var is_upgrade: bool = offer != null and bool(offer.is_upgrade)
	var level_up := get_node_or_null("LevelUp") as Sprite2D
	if level_up != null:
		level_up.visible = is_upgrade
	var original_price_label := get_node_or_null("OriginalPrice") as Label
	var is_discounted: bool = is_upgrade and int(offer.original_price) > int(offer.price)
	if original_price_label != null:
		original_price_label.text = str(offer.original_price) if is_discounted else ""
	var presentation := get_node_or_null("OfferPresentationAnimation") as AnimationPlayer
	if presentation != null:
		var animation_name: StringName = &"discounted" if is_discounted else &"regular"
		if presentation.has_animation(animation_name):
			presentation.play(animation_name)


@export var item: Item = null:
	set(value):
		item = value

		if value == null:
			_set_icon_texture(null)
			_refresh_affordability()
			return

		_set_icon_texture(value.icon)
		$Price.text = "$ " + str(value.price)
		refresh_localized_content()
		_refresh_affordability()


func _ready() -> void:
		_connect_localization()
		refresh_localized_content()
		_refresh_affordability()


func refresh_localized_content() -> void:
	if item == null:
		return
	var title_label := get_node_or_null("Title") as Label
	if title_label != null:
		title_label.text = _item_title(item)
	var type_label := get_node_or_null("Type") as Label
	if type_label != null:
		type_label.text = _item_type_text(item)


func _connect_localization() -> void:
	var localization: Node = _get_autoload_node(&"Localization")
	if localization == null or not localization.has_signal(&"locale_changed"):
		return
	var callback := Callable(self, "_on_locale_changed")
	if not localization.is_connected(&"locale_changed", callback):
		localization.connect(&"locale_changed", callback)


func _on_locale_changed(_locale_code: String) -> void:
	refresh_localized_content()


func _refresh_affordability() -> void:
	var state_animation: AnimationPlayer = get_node_or_null("AffordabilityAnimation") as AnimationPlayer
	if state_animation != null:
		state_animation.play(&"affordable" if _is_affordable else &"unaffordable")


func set_affordable(value: bool) -> void:
	_is_affordable = value
	_refresh_affordability()

func _on_gui_input(event) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.is_pressed() or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _is_affordable:
		return

	if offer == null:
		return
	var raw_offer_id: Variant = offer.get("offer_id")
	if raw_offer_id == null or String(raw_offer_id) == "":
		return
	purchase_requested.emit(StringName(raw_offer_id))


func _get_autoload_node(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))


func _make_custom_tooltip(_for_text: String) -> Control:
	if item == null:
		return null
	var tooltip: ItemTooltip = ItemTooltipScene.instantiate() as ItemTooltip
	tooltip.set_item(item)
	return tooltip


func _set_icon_texture(texture: Texture2D) -> void:
	var icon: Node = get_node_or_null("Icon")
	if icon == null:
		return
	if icon.has_method("set_texture"):
		icon.call("set_texture", texture)
	elif icon is TextureRect:
		var texture_rect := icon as TextureRect
		texture_rect.texture = texture


func _item_title(value: Item) -> String:
	if value == null:
		return ""
	if value.skill_definition != null:
		return tr(String(value.skill_definition.get("name_key")))
	var key := "ITEM_%s_TITLE" % value.id.to_upper()
	var translated := tr(key)
	return translated if translated != key else tr(value.title)


func _item_type_text(value: Item) -> String:
	if value == null:
		return ""
	match value.type:
		Item.ItemType.SKILL:
			return tr("UI_SKILL_TYPE")
		Item.ItemType.RELIC:
			return tr("UI_RELIC_TYPE")
		Item.ItemType.MARBLE:
			return tr("UI_MARBLE_TYPE")
	return tr("UI_EMPTY")
