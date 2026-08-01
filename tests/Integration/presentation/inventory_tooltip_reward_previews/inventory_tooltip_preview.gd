extends Node

const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")
const WalletScript: GDScript = preload("res://Commerce/application/run_wallet.gd")

enum PreviewKind {
	INVENTORY,
	UPGRADE_SELECTION,
	SHOP,
}

@export var preview_kind: PreviewKind = PreviewKind.INVENTORY
@export var locale_code: String = "zh_CN"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_locale(locale_code)
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var wallet: RefCounted = WalletScript.new()
	wallet.call("set_balance", 120)
	var marble := (load("res://Content/data/fire_marble.tres") as Item).duplicate(true) as Item
	var relic := (load("res://Content/data/fire_bellows.tres") as Item).duplicate(true) as Item
	var skill := (load("res://Content/data/magic_missile_skill.tres") as Item).duplicate(true) as Item
	for item: Item in [marble, relic, skill]:
		loadout.call("add", item)
		progression.call("upgrade_one", item)

	if preview_kind == PreviewKind.SHOP:
		var shop := $Shop
		shop.call("configure", loadout, progression, wallet)
		shop.set("mode", 0)
		await get_tree().process_frame
		_hover(shop.get_node("UI/Panel/CollectionRows/MarbleBox/MarbleSlot1") as Control)
		return

	var inventory := $InventoryPanel as InventoryPanel
	inventory.configure(loadout, progression)
	if preview_kind == PreviewKind.UPGRADE_SELECTION:
		inventory.set("_upgrade_selection_active", true)
	inventory.mode = InventoryPanel.MODE.ON
	await get_tree().process_frame
	_hover(inventory.get_node(
		"UI/Panel/MarginContainer/Layout/Content/CollectionRows/MarbleBox/MarbleSlot1"
	) as Control)


func _hover(control: Control) -> void:
	if control != null:
		Input.warp_mouse(control.get_global_rect().get_center())


func _set_locale(value: String) -> void:
	var localization := get_node_or_null("/root/Localization")
	if localization != null and localization.has_method("set_locale"):
		localization.call("set_locale", value)

