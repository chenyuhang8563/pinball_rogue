extends Resource
class_name MarbleSpec

## 弹珠生成数据：把 "效果类型 ↔ Marble.MARBLE_TYPE ↔ 场景 ↔ 生成位置"
## 四元关系从 Main/main.gd 的硬编码字典+match 合并为可编辑资源。
##
## 由 [EffectRegistry] 按 Item.EffectType 查表得到，main.gd 启动/补球时读取。

@export var marble_type: Marble.MARBLE_TYPE = Marble.MARBLE_TYPE.DEFAULT
@export var scene: PackedScene
@export var spawn_position: Vector2 = Vector2(56, 48)