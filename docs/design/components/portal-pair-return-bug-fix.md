# 成对传送门回跳问题修复方案

## 1. 问题与结论

**现象：** Head 从 A 门进入，B 门只闪现一帧，随后回到 A 门并沿原轨迹继续运动。

这不是出口偏移量或冷却时长不足的问题，而是当前请求路径把三种不同结果混为“稍后再试”：

1. 传送已完成后的 `portal_lockout`；
2. 出口有实体占用、可以在 `0.2 s` 内等待的 `exit_unsafe`；
3. 配置无效、链已销毁等不可恢复失败。

当前 `PortalPairController._on_transfer_requested()` 在 `_try_transfer()` 返回 `false` 后一律写入 `_pending`。因此 B 门在锁定期收到的 `body_entered` 虽然没有立即回传，却会在锁定结束后以待传送请求再次执行 B → A。旧规则虽要求“锁定期忽略”，接口返回值却无法表达“已忽略且不得排队”，所以没有生效。

此外，`MarbleTeleportService.transfer()` 目前在移动链后才写入锁定；锁定与刚体位置/速度更新并非同一个提交点。任何由 Area2D 重叠、链轨迹更新或刚体积分产生的同帧回调，都可能观察到中间状态。

## 2. 外部实现依据

- [Godot 4.6 Area2D](https://docs.godotengine.org/en/4.6/classes/class_area2d.html)：`body_entered` 与 `body_exited` 分别只报告进入和离开检测区；它们不是“允许传送”的业务裁决。重叠状态仍应由业务层在物理帧中复核。
- [Godot 4.6 RigidBody2D](https://docs.godotengine.org/en/4.6/classes/class_rigidbody2d.html)：官方明确建议需要直接影响刚体时优先使用 `_integrate_forces()`；频繁直接改 `transform` 或 `linear_velocity` 可能产生不可预测行为。Head 必须在该回调的 [`PhysicsDirectBodyState2D`](https://docs.godotengine.org/en/4.6/classes/class_physicsdirectbodystate2d.html) 上写 `transform` 与 `linear_velocity`。
- [Unity OnTriggerEnter2D](https://docs.unity3d.com/ScriptReference/MonoBehaviour.OnTriggerEnter2D.html)：触发器只向相关的 `Collider2D`/`Rigidbody2D` 发送进入通知，并配套 `OnTriggerExit2D`；它同样应只作为候选与离开门槛的事件源。

### 2.1 开源实现对照与取舍

- [Pyxus 的 seamless portal](https://github.com/Pyxus/godot-seamless-portal-2d/blob/main/addons/seamless_portal_2d/portal_2d.gd#L69-L92) 在物理帧检测旅行者是否真正跨越门平面，并以 `TELEPORT_BUFFER` 推出出口；其双端共享的 [`_tracked_travelers` / `_is_in_either_portal`](https://github.com/Pyxus/godot-seamless-portal-2d/blob/main/addons/seamless_portal_2d/portal_2d.gd#L156-L201) 证明“对象尚在任一端时禁止重复登记”是可靠的防回传模型。该仓库基于 Godot 3，直接改刚体 transform 的实现不能照搬到 Godot 4.6。
- [JulianaGaibler 的 Portal 2D](https://github.com/JulianaGaibler/portal2d/blob/master/portal/Portal.gd#L229-L289) 以门平面另一侧的距离作为提交条件，同时变换位置与速度；可借鉴其“穿越而非仅重叠”的判定和向量变换，但其 Godot 3 的直接刚体赋值必须迁移到 Head 的 `_integrate_forces()`。
- [Janglee 的 Godot 2D portal](https://github.com/Janglee123/godot-2d-portal/blob/master/Portal/Portal.gd#L25-L99) 只有全局 `is_porting` 与离开入口后的克隆交换；它不支持多 Head、没有速度变换和请求结果语义，不能作为本项目防回传方案。
- [Godot 4.6 Smooth Portal Demo](https://github.com/AlligatorSoupStudiosAdministrative/Godot4.6.3-Smooth-Portal2D-Demo/blob/main/portals-demo/portal/portal.gd#L124-L143) 在 `_process()` 直接写 `body.global_position`，且未维护速度或出口抑制。它只适合展示裁切视觉，不能用于本项目的 `RigidBody2D` Head。

### 2.2 Unity 2D 对照

- [OteroCRRLL/Portal2DMechanicDemo](https://github.com/OteroCRRLL/Portal2DMechanicDemo/blob/bb975142a5b5664b83d2a7453b6dccfd6d1837ce/scripts/PortalBehaviour.cs#L13-L55) 演示了“出口法线偏移 + 最小速度 + 重设速度”的最小做法，但其 `isTeleporting`、`teleportCooldown` 没有实际写入或参与门控；不能把字段存在误认为已解决 B → A 回跳。
- [PlayCreatively/UnityTeleportKit2D](https://github.com/PlayCreatively/UnityTeleportKit2D/blob/5dd7032f6928607da82d18262d98bbbb7daf52b0/Portal.cs#L40-L75) 在 `FixedUpdate` 收集接触、确认越过门平面后才移动对象，并通过 [`Physics2D.IgnoreCollision` 直到不再重叠](https://github.com/PlayCreatively/UnityTeleportKit2D/blob/5dd7032f6928607da82d18262d98bbbb7daf52b0/EssentialFuncs.cs#L38-L48) 解除出口门控。这印证了“离开出口再解锁”；但它未重设 `Rigidbody2D` 速度，也没有通用出口形状查询，不能原样复用。

这些引擎的共同实践是：**触发器只报告候选，传送服务在单一物理提交点原子提交，离开出口检测区前保持单向抑制。**

## 3. 目标契约

### 3.1 状态机

```text
Idle
  └─ Head 进入端点 ─→ Candidate
Candidate
  ├─ 链已锁定 / 已在等待 ─→ Ignored（不创建 pending）
  ├─ 出口不安全 ─→ WaitingForSafeExit（最多 0.2 s，Head 必须仍重叠原入口）
  ├─ 出口安全 ─→ CommitQueued
  └─ 链、端点或配置无效 ─→ Cancelled
CommitQueued
  └─ 物理提交成功 ─→ ExitSuppressed
ExitSuppressed
  └─ Head 已离开出口检测区，且最少 0.35 s 已过去 ─→ Idle
```

`Ignored`、`Cancelled` 和超时的 `WaitingForSafeExit` 都是终态，**不得**回写 `_pending`。只有 `exit_unsafe` 能进入等待状态。

### 3.2 结果类型

`_try_transfer()` 不再返回 `bool`，改为显式结果：

| 结果 | 控制器动作 |
| --- | --- |
| `COMMIT_QUEUED` | 保留本帧的提交令牌；不创建 `_pending`。 |
| `EXIT_UNSAFE` | 首次请求才创建 `_pending`，记录入口、Head、截止物理时间。 |
| `LOCKED` | 立即丢弃本次事件；清除该 Head 已有的 `_pending`。 |
| `ALREADY_PENDING` | 立即丢弃重复事件。 |
| `INVALID` | 丢弃并记录一次诊断，不排队。 |

`PortalEndpoint` 仍只发出 `portal_transfer_requested`；它不拥有冷却、等待或传送状态。

### 3.3 最小修复伪代码

在完成刚体提交点改造前，控制器也必须先消除当前的错误排队语义。以下分支是必须保留的行为，不是代码格式要求：

```gdscript
func _on_transfer_requested(_pair_id: StringName, head: Marble, entry: PortalEndpoint) -> void:
    var result := _resolve_transfer(entry, head)
    match result:
        TransferResult.COMMIT_QUEUED:
            _pending.erase(head.get_instance_id())
        TransferResult.EXIT_UNSAFE:
            _queue_pending_once(head, entry)
        TransferResult.LOCKED, TransferResult.ALREADY_PENDING, TransferResult.INVALID:
            _pending.erase(head.get_instance_id())
```

`_resolve_transfer()` 必须先解析 `MarbleChain`，再检查该链的 `pair_id` 锁定；检查到锁定时直接返回 `LOCKED`。它**不得**先检查出口安全性，也不得调用 `_queue_pending_once()`。这样即使出口 B 在传送帧产生 `body_entered`，B 的事件也会被终止，而不是变成 `0.35 s` 后的 B → A 回传。

`_physics_process()` 重试已有请求时也必须按同一结果表处理：仅 `EXIT_UNSAFE` 可在剩余时间内保留原请求；`COMMIT_QUEUED`、`LOCKED`、`ALREADY_PENDING` 和 `INVALID` 均立即清除该请求。不得把“尚未提交成功”概括为“继续等待”，否则锁定期内已产生的 B → A 请求仍会在锁定到期后被重放。

### 3.4 原子物理提交

`MarbleTeleportService` 是唯一可移动 Head 的服务。一次提交必须按以下顺序在同一物理步完成：

1. 校验提交令牌仍对应当前入口、当前 Head 和同一条 `MarbleChain`。
2. 写入 `portal_lockout(chain_id, pair_id)`，状态为 `ExitSuppressed`。
3. 在 Head 的 `_integrate_forces(state)` 中写入 `state.transform` 与 `state.linear_velocity`；不在 `body_entered` 回调中直接改刚体位置。
4. 用**同一目的地与速度**重置 `MarbleChain` 轨迹历史和可视链段。
5. 清除入口的 `_pending`，发出一次 `component_activated`。

若第 3 步不能提交（Head 已释放、令牌过期），必须撤销锁定并取消，不得留下无位置变更的锁定状态。

### 3.5 出口抑制与空间要求

- 锁定以“物理提交成功”为起点，最短 `0.35 s`。
- 在锁定期内，A、B 两端的任何进入事件都返回 `LOCKED`；不得创建或保留 `_pending`，不得改写位置、速度或链轨迹。
- `0.35 s` 到期不是重新允许回传的充分条件：Head 必须先离开 B 的 `Area2D` 检测区。若仍重叠，保持 `ExitSuppressed` 到 `body_exited` 或重叠复核为否。
- 出口落点为 `PortalAnchor + exit_forward * exit_offset`。`exit_offset` 必须大于 Head 碰撞半径、出口检测区沿 `exit_forward` 的半径及 `2 px` 间隙之和；当前 Head 半径为 `8 px`、端点触发半径为 `12 px`，因此 `22 px` 为不合格临界值，默认采用 `24 px`。关卡验证不满足即禁用该对。这样正常出门不会在 B 门中心停留。
- `PortalEndpoint.is_exit_safe()` 的最终裁决必须在物理帧以 [`PhysicsDirectSpaceState2D.intersect_shape`](https://docs.godotengine.org/en/4.6/classes/class_physicsdirectspacestate2d.html#class-physicsdirectspacestate2d-method-intersect-shape) 查询 Head 的完整形状位于目标落点时是否与障碍相交，并排除 Head 自身的 RID；若还需验证到落点的扫掠路径，则追加 `cast_motion`。现有 `SafetySensor` 只能作早期拒绝，不能替代这个查询。
- **禁止**以 `call_deferred()` 代替物理提交：它只能推迟 Node 属性写入，不能保证该写入与 `RigidBody2D` 的积分是同一个原子状态。也**禁止**仅凭“冷却秒数到期”重新接收 B 门的旧重叠；必须有离开 B 后的新进入边沿。

## 4. 实施切片

1. **结果拆分：** 为 `PortalPairController` 增加传送结果枚举；只让 `EXIT_UNSAFE` 写入 `_pending`。这是本缺陷的最小修复，先以 GUT 锁定。
2. **提交令牌：** 用 `chain_id + pair_id + entry_instance_id + physics_frame` 表示一次候选，防止同一帧 A/B 的多个信号重复排队。
3. **刚体提交点：** 给 `Marble` 增加单槽的待传送命令，并在 `_integrate_forces()` 消费；`MarbleTeleportService` 在确认回执后重置链轨迹和发出激活事件。
4. **出口离开门槛：** `PortalEndpoint` 增加 `body_exited` 通知或在控制器物理帧复核 `is_overlapping_head()`；锁定到时但未离开出口时继续抑制。
5. **出口查询与关卡校验：** 在物理帧以 `intersect_shape`（必要时 `cast_motion`）验证完整 Head 形状在目标落点的净空；同时在编辑器/加载阶段校验 `exit_offset`，并报告具体端点路径和所需最小偏移。

第 1 步不得以“把 `lockout_seconds` 调大”替代；那只能推迟错误的待传送请求。

## 5. GUT 验收矩阵

| GUT 用例 | 初始条件 | 断言 |
| --- | --- | --- |
| `portal_locked_entry_is_not_queued` | A → B 后，在锁定内模拟 B 的 `body_entered` | `_pending` 不含该 Head；锁定结束后 Head 仍在 B 前方。 |
| `portal_lockout_expired_while_still_in_exit_is_suppressed` | B 的检测区足够大，Head 在 `0.35 s` 后仍重叠 | 不发生 B → A；直到 `body_exited` 后的新进入才可传送。 |
| `portal_exit_unsafe_is_the_only_pending_case` | 分别制造锁定、出口阻塞和无效链 | 仅出口阻塞创建 `_pending`。 |
| `portal_commit_updates_rigidbody_and_chain_once` | 正常 A → B | 一个物理帧内 Head 位置、速度、轨迹首点和所有链段均匹配 B 的出口；`component_activated` 恰好一次。 |
| `portal_pending_cannot_replay_after_transfer` | A 因出口阻塞进入等待，出口恢复后完成 A → B | 旧入口请求被清除；后续锁定结束也不发生 B → A。 |
| `portal_exit_offset_clears_trigger_geometry` | 使用最小合格偏移与小于最小值的偏移 | 前者通过校验且提交后不重叠 B；后者禁用该对并给出错误。 |

通过以上 GUT 后，再运行独立 `portal_chain_transfer` 场景：连续 3 次 A → B 进入、停在 B 门内超过锁定时长、离开 B、再从 B 重新进入。截图需分别证明 B 出口稳定、锁定期无回跳、离开后新进入才允许反向传送。

## 6. 影响范围与回滚

| 路径 | 处置 |
| --- | --- |
| `Combat/table_components/portal_pair/portal_pair_controller.gd` | 拆分结果、待传送队列和出口离开状态。 |
| `Combat/marbles/marble_teleport_service.gd` | 改为提交令牌与锁定提交；不再直接承担不受物理集成约束的刚体写入。 |
| `Combat/marbles/marble_chain.gd`、Head `Marble` 脚本 | 增加物理提交回执，并只在成功后重置链轨迹。 |
| `Combat/table_components/portal_pair/portal_endpoint.gd` | 保持事件源职责，补充离开通知/重叠复核入口。 |
| `tests/Combat/table_components/test_environment_components.gd` | 添加上述 GUT 用例；现有 `portal_chain_transfer` 仅保留为基础覆盖。 |

回滚只允许撤销这一整套状态机变更；不得恢复“`false` 即排队”的布尔接口，因为它无法区分锁定与出口阻塞，必然重现回跳。
