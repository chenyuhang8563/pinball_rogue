extends Node

## 构筑系统的唯一登记簿。
##
## 把原先散落在 [Main/main.gd]（弹珠 effect_type→场景的关系）与
## [Effects/effect_manager.gd]（遗物 effect_type→效果脚本的关系）里的两处硬编码字典，
## 收敛为这里的一处数据驱动注册表。新增构筑内容时，只需在本表登记一行，无需改
## main.gd / effect_manager.gd 的主逻辑。
##
## - [constant RELIC_EFFECT_SCRIPTS]：遗物效果类型 → 效果脚本（RefCounted，挂战斗回调）。
##   EffectManager 据此创建/销毁活动效果实例并分发事件。
## - [constant MARBLE_SPECS]：弹珠解锁效果类型 → MarbleSpec 资源（场景+生成位置）。
##   main.gd 据此决定开场与补球时实例化哪种弹珠。

# 遗物效果：effect_type -> RefCounted 脚本
const RELIC_EFFECT_SCRIPTS: Dictionary = {
	Item.EffectType.LIGHTNING_CHAIN: preload("res://Effects/lightning_effect/lightning.gd"),
}

# 弹珠解锁：effect_type -> MarbleSpec 资源
const MARBLE_SPECS: Dictionary = {
	Item.EffectType.BOMB_MARBLE: preload("res://Resources/marble_specs/bomb_marble_spec.tres"),
	Item.EffectType.BROWN_MARBLE: preload("res://Resources/marble_specs/brown_marble_spec.tres"),
	Item.EffectType.DARK_MARBLE: preload("res://Resources/marble_specs/dark_marble_spec.tres"),
}


func _ready() -> void:
	# 仅作存在性自检：自动加载单例在场景之前就绪，若无库存效果则表为空属正常。
	pass


## 查询遗物效果脚本；未注册时返回 null。
func get_relic_script(effect_type: int) -> GDScript:
	if not RELIC_EFFECT_SCRIPTS.has(effect_type):
		return null
	return RELIC_EFFECT_SCRIPTS[effect_type] as GDScript


## 查询弹珠解锁的生成数据；未注册时返回 null。
func get_marble_spec(effect_type: int) -> MarbleSpec:
	if not MARBLE_SPECS.has(effect_type):
		return null
	return MARBLE_SPECS[effect_type] as MarbleSpec


## 当前库存拥有的弹珠解锁效果类型集合（按注册表顺序，去重）。
func get_marble_effect_types(inventory: Node) -> Array[int]:
	var owned: Array[int] = []
	if inventory == null or not inventory.has_method("has_effect"):
		return owned
	for effect_type in MARBLE_SPECS.keys():
		if inventory.call("has_effect", effect_type):
			owned.append(effect_type)
	return owned


## 当前库存拥有的遗物效果类型集合（按注册表顺序，去重）。
func get_relic_effect_types(inventory: Node) -> Array[int]:
	var owned: Array[int] = []
	if inventory == null or not inventory.has_method("get") or not inventory.has("relic_items"):
		return owned
	var relic_items: Array = inventory.get("relic_items")
	for item in relic_items:
		if item == null:
			continue
		if item.effect_type == Item.EffectType.NONE:
			continue
		if not RELIC_EFFECT_SCRIPTS.has(item.effect_type):
			continue
		if not owned.has(item.effect_type):
			owned.append(item.effect_type)
	return owned