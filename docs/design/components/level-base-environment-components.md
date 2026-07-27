# Level Base 战斗环境组件设计（第一期）

> 状态：提案（仅设计，未实现）  
> 目标版本：Godot 4.6.1  
> 本文只约束战斗桌面的可摆放环境物，不改变角色、遗物、技能或 UI 的结构。

## 1. 目标与边界

本期为 `level_base` 类战斗场景补充可复用的桌面组件：让弹珠的路线、风险和金币获取都能由玩家操作影响，而不是只依赖敌人碰撞与挡板。

本期目标：

- 新增单侧弹力板、木桶、战斗金币、弹弓与成对传送门的完整规格。
- 提供一组可选的后续组件，并给出优先级。
- 统一场景结构、碰撞约定、事件边界、数值锚点与验收场景。

非目标：

- 本期不实现组件、不绘制缺失素材、不修改当前经济数值。
- 不把所有组件继承为 `Platform`：静态碰撞体、可破坏物、触发器、掉落物各自独立。
- 不引入“分段弹珠也具有物理碰撞”的新模型。现状中只有 `MarbleChain.head` 是物理 `Marble`；以下“弹珠碰到”均指 Head，链段仅随轨迹表现。

## 2. 现状约束与公共约定

### 2.1 已确认的接入点

| 现有对象 | 可利用的契约 | 本期使用方式 |
| --- | --- | --- |
| `MarbleChain`（`res://Combat/marbles/marble_chain.gd`） | `head` 为唯一刚体；`chain_collision(collider, collision_type)` | 组件对 Head 生效；传送由链级服务整体搬运 Head 与可视段。 |
| `Marble` | `RigidBody2D`，可读取 `linear_velocity`、调用 `apply_central_impulse()` | 弹力、弹弓与加速类组件统一以冲量改变速度。 |
| `Enemy`（`res://Combat/battle/enemies/enemy.gd`） | `defeated(enemy, cause)`，且同一敌人只会触发一次 | 掉落导演订阅此信号生成金币，不在敌人脚本中写经济。 |
| `RunWallet`（`res://Commerce/application/run_wallet.gd`） | `credit(amount)` 与 `changed(value)` | 仅金币成功拾取后调用；HUD 已能由钱包信号刷新。 |
| `BattleSession` / `BattleGateway`（`res://Combat/battle/battle_gateway.gd`） | 战斗完成与场景清理边界 | 最后一只敌人的掉落必须经过“拾取宽限”后再允许结束战斗。 |

### 2.2 组件分类

| 类别 | 根节点 | 例子 | 职责 |
| --- | --- | --- | --- |
| 静态/弹性碰撞体 | `StaticBody2D` 或 `AnimatableBody2D` | 平台、弹力板、弹弓可选导轨 | 阻挡、反弹、施加一次性冲量。 |
| 可破坏环境物 | `StaticBody2D` + 命中 `Area2D` | 木桶、后续可破坏墙 | 有一次性生命周期；破坏后撤销实体碰撞并产生事件。 |
| 触发器 | `Area2D` | 传送门、加速轨道、磁力井 | 不承担实体阻挡；检测后委托服务改变物理状态。 |
| 战斗掉落物 | `Area2D` | 金币 | 在场上存在、可错过；只有拾取事件才能结算资源。 |

### 2.3 碰撞层约定

沿用已存在的位掩码：桌面静态体在层 `1`，弹珠在层 `2`，挡板在层 `4`，敌人在层 `8`。新组件不得改写这些既有层的语义。

| 对象 | `collision_layer` | `collision_mask` | 说明 |
| --- | ---: | ---: | --- |
| 弹力板 / 木桶实体 / 弹弓可选导轨 | 1 | 2 | 只和 Head 实体碰撞。 |
| 金币 / 传送入口 / 加速轨道等 `Area2D` | 0 | 2 | 只侦测 Head，不挡球。 |
| 组件的辅助感应区 | 0 | 2 | 用于防抖和触发，不与其他组件互相感应。 |

每个场景均需用组而非硬编码节点路径识别对象：`marbles`、`enemies`、`table_component`、以及按需的 `coin_pickups`。组件脚本应从 `/root` 解析 Autoload，不假设其为编译期全局。

## 3. 第一批必做组件

数值均为未经实机验证的首轮假设，不代表最终平衡值。所有可调数值以场景导出属性或组件资源保存；桌面布局、尺寸、贴图、动画与可见性全部在 `.tscn` / `.tres` 中编辑，不由脚本拼装 UI 或硬编码布局。

### 3.1 单侧弹力板 `one_way_booster`

**玩家感受：** 从正面撞上像被“拍回去”，背面则只是普通障碍；用于把危险区域的球送回上方路线。

| 项目 | 规格 |
| --- | --- |
| 场景根 | `StaticBody2D`，子节点为 `Sprite2D`、`CollisionShape2D`、`FrontTrigger: Area2D`。素材暂缺，先在场景中使用明确的占位预制体。 |
| 有效面 | 本地 `forward` 轴定义为正面；仅当 `dot(-incoming_velocity.normalized(), forward) >= 0.35` 才触发。背面仍由实体碰撞自然反弹，但不加冲量。 |
| 效果 | 向 `forward` 施加冲量；首轮值为额外速度 `+180 px/s`，但结果速度上限 `520 px/s`。 |
| 防抖 | 同一 Head 的触发冷却 `0.18 s`；静止或速度低于 `60 px/s` 时不触发。 |
| 摆放规则 | 需留出正面至少 `64 px` 的空域；不得紧贴传送出口或 kill zone。 |

**区别：** 它是定向、被动、一次冲量；不替代挡板的输入时机，也不同于弹弓“射入核心后沿反作用方向弹出”的机制。

### 3.2 木桶 `barrel`

**玩家感受：** 是稍软的障碍物：轻撞会有小回弹，每次 Head 碰撞都会掉出一枚需要自己捡的金币；累计碰撞足够多次后破裂。

| 项目 | 规格 |
| --- | --- |
| 素材 | 使用 `res://Assets/Barrel/Barrel Sprite.png`；该素材当前在原工作树中未跟踪，合并实现前须一并纳入版本控制。 |
| 场景根 | `StaticBody2D`；含可见精灵、实体 `CollisionShape2D`、`ImpactSensor: Area2D`、破裂动画节点与 `DropAnchor: Marker2D`。 |
| 轻微弹力 | 物理材质首轮 `bounce = 0.15`；比普通硬墙更柔和，但不额外加速。 |
| 碰撞计数 | Head 每次进入 `ImpactSensor` 记一次碰撞并发一次 `barrel_hit`，掉落导演据此掉一枚币；无速度与角度门槛，任何有效碰撞都计数。 |
| 一次性 | 状态为 `intact -> broken`；累计碰撞达到 `max_hits`（默认 `20`）时转入 `broken`，禁用实体碰撞和感应区，并恰好发一次 `barrel_broken`；破碎后不再计数或掉币。 |
| 掉落 | 每次碰撞掉 `1` 枚金币：飞行起点为 `DropAnchor`，落点按 3.3 由导演的预置 `CoinDropAnchor` 池选择（池为空时退回 `DropAnchor`），避免金币落进桶自身实体而不可拾取；金币不能落在 kill zone 内。 |

木桶不造成伤害、不掉落遗物，也不需要血条。它的价值是“反复碰撞换取可拾取资源”，并让玩家有意把球持续导向桶。

### 3.3 战斗金币 `coin_pickup`

**玩家感受：** 金币以可读的抛物线落到预先设计的安全位置并停留；只有球吃到它，才真的进入本局总金币。第一期不把金币做成真实物理刚体，因此不承诺与墙、桶发生物理弹跳。

| 项目 | 规格 |
| --- | --- |
| 素材 | 使用 `res://Assets/Items/Coin props` 的序列帧；该目录同样需随实现提交。每枚金币自身播放循环帧动画。 |
| 场景根 | `Area2D`，子节点为 `AnimatedSprite2D`、`CollisionShape2D`、`AnimationPlayer`、`LifetimeTimer`。`AnimationPlayer` 只负责序列帧、缩放和落地反馈；世界运动控制器根据动态生成点与锚点计算确定性的抛物线路径。 |
| 落点与生命周期 | 掉落导演从关卡预放置的 `CoinDropAnchor` 集合选择合法锚点，世界运动控制器将实例从生成源移动到该锚点；不做刚体散落，也不依赖运行时碰撞决定落点。状态固定为 `spawning -> available -> collected/expired`：飞行期间关闭拾取感应，落地才进入 `available` 并开始停留计时。 |
| 生成源 | `CombatDropDirector` 监听敌人的 `defeated` 与木桶的 `barrel_hit`，只负责生成；敌人默认掉落率 `35%`、每次 `1` 枚，木桶每次碰撞 `1` 枚。 |
| 拾取 | 只接受 `marbles` 组中的 Head；原子状态 `available -> collected` 后发出 `coin_collected(amount, source)`，再由掉落导演调用当前 `RunWallet.credit(amount)`。生成本身绝不写钱包。 |
| 超时/出界 | 默认停留 `8 s`；进入 kill zone、被场景清理或超时均发出 `coin_expired`，不入账。 |
| 容量 | 同时最多 `12` 枚；超出时合并到最近的可用金币（增加其 `amount`），避免场景与物理感应区泛滥。 |

**结算门槛：** `BattleSession` 是唯一完成权威。它接收注入的 `LootSettlementGate` 并将原先“敌人清空即完成”的内部判定收束为“敌人清空且 `gate.is_settled()`”；`CombatDropDirector` 只维护金币计数、宽限计时并报告 gate 状态，绝不直接切场景或发出 `battle_completed`。无金币掉落的战斗注入默认已 settled 的 gate。敌人清空后开始最多 `3 s` 的拾取宽限；宽限结束仍未拾取的金币过期，gate 才变为 settled，随后由 `BattleSession` 进入原有完成路径。这样最后一只敌人掉落的金币可被捡到，且不会出现两个竞争的结算入口。

**经济护栏：** 每个普通战斗由环境掉落带来的期望金币先控制在 `3–5`，精英 `6–8`；在实际启用前，需与当前 `BattleRewardConfig` 的结算金币同测，不能简单叠加后仍沿用原有奖励区间。

### 3.4 弹弓 `slingshot`

**玩家感受：** 球直接射入弹弓核心范围时，会被弹弓以反作用力沿远离发射点的方向弹出；玩家可借由瞄准弹弓中心，把一次直射转换成可预测的折返。

| 项目 | 规格 |
| --- | --- |
| 场景根 | `Node2D`；包含 `KickSensor: Area2D`、`KickOrigin: Marker2D`、表现动画与按关卡需要配置的 `StaticBody2D` 导轨。导轨只塑形，反作用力由感应区施加；镜像由场景变体完成。 |
| 触发条件 | Head 进入 `KickSensor` 时速度至少 `90 px/s`，且其速度方向朝向 `KickOrigin`（点积至少 `0.5`）；切向掠过和远离核心的穿过不触发。 |
| 效果 | 冲量方向固定为 `KickOrigin → Head` 的归一化向量，即沿入射反作用方向把球推出；首轮目标速度 `420 px/s`，结果上限 `560 px/s`。 |
| 防抖 | 每颗 Head 冷却 `0.35 s`；一次触发后保持 `0.08 s` 的视觉激活，但不重复施力。 |
| 规则 | 弹弓是被动反作用器，不需要按键，不给金币，不触发木桶破坏的额外判定；不限定在桌面下侧，关卡可把它作为任意路线的定点折返器。 |

它与单侧弹力板的区别是：弹弓要求球**主动直射其核心**，再以“发射点到球”的反作用方向将其推出；单侧弹力板只要从有效面撞击，就沿自身固定法线补速。

### 3.5 成对传送门 `portal_pair`

**玩家感受：** 将球从一条危险或低价值路线送往另一条明确的出口路线。它是路线选择工具，不是随机位移。

| 项目 | 规格 |
| --- | --- |
| 场景根 | 每一端为 `PortalEndpoint: Area2D`，带 `PortalAnchor: Marker2D` 与朝向；由关卡中的 `PortalPairController` 用唯一 `pair_id` 配对。第一期只支持恰好两个端点。 |
| 触发对象 | 仅 Head 进入入口触发；链段不单独触发、也不能被逐颗传送。Head 与链的关联由战斗范围内的 `MarbleChainRegistry` 在 `build_chain()` / 销毁时注册和注销，端点控制器通过注入的 registry 解析所属链，禁止搜索场景树。 |
| 链级传送 | `MarbleTeleportService` 接收 `MarbleChain` 与出入口：将 Head 放到 `PortalAnchor + exit_forward * exit_offset`，将速度绕“入口前向 → 出口前向”的角差旋转；按比例保留速度，最低 `140 px/s`、最高 `480 px/s`。`exit_offset` 默认 `24 px`；它必须大于 Head 碰撞半径、出口检测区沿出口前向的半径和 `2 px` 间隙之和（当前 `22 px` 已不合格），否则关卡验证禁用该对。物理提交成功后，以出口朝向和同一目的地重置链的轨迹历史并重排可视段，保证整条链连续。 |
| 防回传 | `MarbleTeleportService` 必须在 Head 的 `_integrate_forces(state)` 中以单一物理提交点原子完成传送：写入 `state.transform` 与 `state.linear_velocity`、为该链写入 `portal_lockout(pair_id, 0.35 s)`、再确认链轨迹历史和可视段重置；若提交失败必须撤销锁定。两个端点的 `body_entered` / 重叠轮询在锁定或出口抑制期内均只能忽略该链，**不得**重新提交或保留待传送请求、改写其位置或速度。锁定期满后，Head 还必须先离开出口 `Area2D`，其后的新 `body_entered` 边沿才可触发反向传送。 |
| 安全性 | 出口前方 `32 px` 内若有 Head 或实体障碍，入口仅在 Head **仍重叠**时保留最多 `0.2 s` 的待传送请求，期间不冻结球的物理；Head 离开入口立即取消请求，绝不能在球已跑远后突然传送。超时仍无安全位置也取消，入口不吞球。`EXIT_UNSAFE` 是唯一允许写入待传送队列的结果；锁定、无效配置和重复请求必须立即丢弃并清除同一 Head 的旧请求。 |
| 异常配置 | 缺端点、重复 `pair_id`、出口在 kill zone 内或出口前方无可用空间时，编辑器验证报错，运行时禁用该对。 |

第一期不做一入多出、随机出口、敌人传送或金币传送；这些都会降低路线可读性，并让配对/防回传复杂度失控。

## 4. 建议的后续组件池

| 优先级 | 组件 | 核心行为 | 玩法价值 | 实现量 |
| --- | --- | --- | --- | --- |
| P1 | 圆形保险杠 `bumper` | 360° 触碰后沿接触法线加速一次 | 最易读的高频反弹点，补足平面中心的循环路线 | 低 |
| P1 | 单向闸门 `one_way_gate` | 顺向可通过，逆向像硬墙 | 让传送门/加速道形成可规划的单向回路 | 低-中 |
| P2 | 加速轨道 `boost_lane` | 进入时锁定为单向小幅加速，离开后恢复普通物理 | 奖励精确进入狭窄线路，不与弹力板重复 | 中 |
| P2 | 可破坏壁 `breakable_wall` | 多次高速命中后打开捷径，无金币掉落 | 把“多次尝试”转化为关卡拓扑变化 | 中 |
| P3 | 旋转拨片 `spinner` | 球擦过时旋转计次，攒满后开启一次短时加速门 | 为连续、角度好的击打提供节奏目标 | 中 |
| P3 | 脉冲磁井 `pulse_magnet` | 周期性轻拉近范围内弹珠，脉冲间隔可读 | 制造风险路线；需严格限幅，避免夺走操控感 | 中-高 |

推荐第一轮实际顺序：`木桶 + 金币`（验证资源循环）→ `单侧弹力板 + 弹弓`（验证路线与定点折返）→ `传送门`（验证链级移动）→ `圆形保险杠 / 单向闸门`。其余在前三类体验稳定后再做。

## 5. 运行时职责与事件流

### 5.1 场景组成

关卡场景中预放置 `TableComponents: Node2D` 与 `CombatDrops: Node2D`。前者承载所有静态组件/触发器，后者由预加载的金币场景实例承载掉落物。`CombatDropDirector` 是关卡逻辑节点：接收 `enemy_container`、`CombatDrops`、当前 `RunWallet`、本局随机源和完成门槛；它不创建 UI，不保存跨局状态。

```text
敌人 defeated / 木桶 barrel_hit
            ↓
      CombatDropDirector
            ↓ spawn（尚未入账）
        coin_pickup
       ├─ Head 触碰 → coin_collected → RunWallet.credit → HUD 的 wallet.changed 刷新
       └─ 超时 / 出界 → coin_expired → 销毁

敌人清空 → 拾取宽限（最多 3 秒） → 所有金币已解决 → BattleSession 完成
```

### 5.2 组件公共信号

| 信号 | 发射者 | 最小载荷 | 消费者 |
| --- | --- | --- | --- |
| `component_activated` | 弹力板、弹弓、传送门 | `component_id, marble` | 音效/特效与遥测（可选）。 |
| `barrel_hit` | 木桶 | `barrel, drop_anchor` | `CombatDropDirector`（每次碰撞掉一枚币）。 |
| `barrel_broken` | 木桶 | `barrel` | 表现与截图控制（累计碰撞达标后恰好一次）。 |
| `coin_collected` | 金币 | `coin, amount, source` | `CombatDropDirector`，单次调用钱包。 |
| `coin_expired` | 金币 | `coin, reason` | `CombatDropDirector`，更新活跃掉落计数。 |
| `loot_settled` | 掉落导演 | 无 | `BattleSession` 的完成门槛。 |
| `portal_transfer_requested` | 端点 | `pair_id, marble` | `MarbleTeleportService`。 |

所有一次性组件必须先切换内部状态再发信号；消费者不得通过“再次检测场景节点”决定是否已经结算，避免高速碰撞下的重复发奖。

## 6. 关卡配置与摆放检查

每个组件在 `.tscn` 内暴露 `component_id`；关卡加载时检查同一关卡内唯一。涉及随机的掉落数量和概率须从本局随机源取样，以便测试和复现。

| 检查项 | 失败处理 |
| --- | --- |
| `component_id` 重复 | 加载失败并报告冲突路径。 |
| 传送门 `pair_id` 非两端、出口压在 kill zone / 实体内 | 禁用该对并报告。 |
| 木桶 `DropAnchor` 位于 kill zone | 阻止关卡进入运行态。 |
| 弹力板 / 弹弓的冲量方向朝向场外 | 编辑器警告；运行时允许但标记为关卡错误。对弹弓检查其 `KickOrigin` 与感应区的几何方向。 |
| 金币生成点与 Head 重叠 | 允许，视为立即拾取；该情况只应用于敌人死亡的自然掉落。 |

## 7. 测试场景矩阵（实现阶段）

以下场景各自独立成测试关卡，并由单独的 Godot remote executor 运行、截图保存到 `.codex/hud_screenshots`；逻辑断言使用 GUT。实现前先静态审阅，确认 GUT 可正常执行后再运行。

| 场景 | GUT 证据 | 截图要证明的状态 |
| --- | --- | --- |
| `one_way_booster_front_back` | 正面一次加速、背面不加速、冷却阻止重复冲量 | 正/背面命中效果。 |
| `barrel_break_and_drop` | 每次碰撞计数并掉一枚币，累计达标仅破碎一次，金币落在锚点 | 完整桶、破裂桶与落地金币。 |
| `coin_collect_and_expire` | 生成不入账；Head 拾取只入账一次；超时/出界不入账 | HUD 金币变化与过期状态。 |
| `final_kill_loot_grace` | 最后一敌掉币后不立即完成；拾取或 3 秒到期才完成 | 敌人清空后的宽限画面。 |
| `slingshot_reaction_cooldown` | 直射核心后沿反作用方向获得目标速度；切向、远离核心与冷却均不触发 | 射入核心与折返推出的效果。 |
| `portal_chain_transfer` | 速度旋转/限幅正确；全链重置；锁定期不回传 | 入口、出口与连续链身。 |
| `portal_invalid_pair` | 不完整/非法出口被禁用且不丢球 | 验证错误或禁用提示。 |

## 8. 实施切片与风险

1. **基础落点：** 建立 `CombatDropDirector`、`coin_pickup`、战斗完成门槛及钱包注入；先用占位金币验证“生成不入账、拾取才入账”。
2. **资源互动：** 落地木桶与其破裂掉落，随后接入正式桶和金币帧素材。
3. **物理路线：** 单侧弹力板、弹弓、圆形保险杠；统一冲量限速与每球冷却。
4. **空间重排：** 成对传送门与 `MarbleTeleportService`；先证明链级重置正确，再开放给正式关卡。
5. **拓扑扩充：** 单向闸门、加速轨道和可破坏壁，最后才评估磁井与旋转拨片。

最高风险是传送门与战斗结束：前者必须操作整条链而非只移动视觉 Head，后者必须保证最后击杀掉落有可拾取窗口且没有重复入账。两者均应先以专用 GUT 场景锁定契约，再接入正式 `level_base`。
