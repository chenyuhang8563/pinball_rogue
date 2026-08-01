# 蛇形弹珠链的身体段——纯视觉节点，不参与物理模拟。
# 仅 Head（Marble/RigidBody2D）参与物理；Body 段通过路径历史轨迹跟随 Head。
#
# 爆炸（BOMB）逻辑由 [MarbleChain] 统一调度，本段仅作为类型标记存在。
# 回响蓄力已迁移到表级 EchoFlipperChargeController，本段不再持有任何回响状态。

extends Node2D
class_name ChainSegment


## 本段对应的弹珠类型。
@export var segment_type: Marble.MARBLE_TYPE = Marble.MARBLE_TYPE.DEFAULT

## 本段贡献的接触伤害（BOMB 类型自身不贡献接触伤害，由爆炸替代）。
@export var damage: int = 1
