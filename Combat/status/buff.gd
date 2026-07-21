extends Resource
class_name BuffDef

## Data definition for a buff.
##
## BuffHost owns runtime state such as remaining time and stacks. This resource
## stays read-only and describes how a buff should be applied; its inline
## lifecycle hooks are the sole extension mechanism.

enum BuffSource {
	SHOP,
	COMBAT_DROP,
	CHAIN_MECHANIC,
	RELIC,
}

enum ReapplyPolicy {
	REFRESH,
	IGNORE,
}

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var duration: float = -1.0
@export var stackable: bool = false
@export var max_stacks: int = 1
@export var source: BuffSource = BuffSource.SHOP
@export var params: Dictionary = {}
@export var reapply_policy: ReapplyPolicy = ReapplyPolicy.REFRESH


func is_permanent() -> bool:
	return duration < 0.0


## 从唯一定义源 BuffRegistry 构造指定 buff。供 buff 内部转化
## （如 frost→frozen、燃烧余烬扩散）共用，避免各自 preload。
func make_buff(buff_id: String) -> BuffDef:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var registry: Node = tree.root.get_node_or_null("BuffRegistry")
	if registry == null or not registry.has_method("get_buff_def"):
		return null
	return registry.call("get_buff_def", buff_id) as BuffDef


func on_apply(_host: Node, _state: Dictionary) -> void:
	pass


func on_process(_host: Node, _state: Dictionary, _delta: float) -> void:
	pass


func on_remove(_host: Node, _state: Dictionary) -> void:
	pass


func on_duration_appended(_host: Node, _state: Dictionary, _duration: float) -> void:
	pass


func on_host_death(_host: Node, _state: Dictionary) -> void:
	pass
