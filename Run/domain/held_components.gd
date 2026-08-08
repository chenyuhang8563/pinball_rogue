extends RefCounted

## 持有组件（Held Components）
##
## 玩家当前持有的桌面组件（桶 / 弹力板 / 传送门）计数集合。持有组件是 RunScope
## 的持有资产：布设不消耗、可重复布设，跨战斗保留。第一版以初始套件起步，
## 获得途径（掉落 / 商店）为后续切片。
##
## 种类身份用稳定 StringName kind id（如 &"barrel"），与每实例的 component_id 无关；
## kind -> 场景的映射由后续「布设接口」切片负责。

signal changed

const KIND_BARREL: StringName = &"barrel"
const KIND_BOOSTER: StringName = &"booster"
const KIND_PORTAL: StringName = &"portal"

## 初始套件：桶×1、弹力板×1、传送门×1。
const INITIAL_KIT: Dictionary = {
	KIND_BARREL: 1,
	KIND_BOOSTER: 1,
	KIND_PORTAL: 1,
}

var _counts: Dictionary[StringName, int] = {}


## 注入初始套件。返回是否注入了至少一种组件。
func seed_initial_kit() -> bool:
	_counts.clear()
	for kind: StringName in INITIAL_KIT:
		_counts[kind] = int(INITIAL_KIT[kind])
	changed.emit()
	return not _counts.is_empty()


## 查询某组件种类的持有数量；未持有的种类返回 0。
func count_of(kind: StringName) -> int:
	return int(_counts.get(kind, 0))


## 遍历已持有组件种类（按注入顺序）。
func kinds() -> Array[StringName]:
	return _counts.keys()


## 遍历已持有组件条目（kind + count，按注入顺序）。
func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for kind: StringName in _counts:
		result.append({&"kind": kind, &"count": _counts[kind]})
	return result


## 快照当前持有状态（供 RunScope 存档/恢复使用）。
func snapshot() -> Dictionary:
	return {&"counts": _counts.duplicate(), &"revision": revision()}


## 从快照恢复持有状态。counts 形状非法时返回 false，且不改变现有持有。
func restore(state: Dictionary) -> bool:
	if not state.has(&"counts") or not state[&"counts"] is Dictionary:
		return false
	var restored: Dictionary[StringName, int] = {}
	for kind: StringName in state[&"counts"]:
		var count := int(state[&"counts"][kind])
		if count < 0:
			return false
		restored[kind] = count
	_counts = restored
	changed.emit()
	return revision() == int(state.get(&"revision", revision()))


## 持有状态指纹。按 kind 排序后哈希，顺序无关（字典插入顺序不参与指纹）。
func revision() -> int:
	var pairs: Array = []
	for kind: StringName in _counts:
		pairs.append([String(kind), _counts[kind]])
	pairs.sort()
	return str(pairs).hash()
