# 项目文件组织规范

本文件定义 RoguePinball 的长期文件归属和命名规则。它补充而不替代[目标依赖与模块边界](../architecture/target-dependencies.md)与[Godot UID / 路径迁移规则](../architecture/uid-migration.md)；二者发生冲突时，以架构文档和迁移规则为准。

## 目标目录

```text
Game/
  Bootstrap/                 # 唯一跨领域组合根与 RunScope
  Debug/                     # 仅开发、调试工具及其表现层
Core/
  stats/                     # 跨领域数值系统、公式和静态数值资源
  localization/              # 本地化基础能力
Content/
  domain/                    # 不可变物品定义、稳定 ID 与类别
  data/                      # 内容目录、物品及遗物静态资源
Commerce/{domain,application,presentation,data}/
Loadout/{domain,application,presentation,data}/
Run/{domain,application,presentation,data}/
Combat/
  battle/                    # 战斗生命周期、敌人、桌台与物理部件
  marbles/
  skills/
  effects/
  status/                    # Buff 与状态效果
  levels/
  presentation/              # 战斗专属 HUD、浮字及场景
UI/shared/                   # 真正跨领域复用的展示预制
Assets/                      # 美术、音频等源资产
Themes/                      # Theme、字体及其派生资源
tests/{Commerce,Loadout,Run,Combat,Integration}/
docs/{agents,architecture,handoffs,testing}/
```

`addons/` 是第三方插件；`.godot/`、`output/`、导入缓存和编辑器配置是生成或工具内容。它们不参与领域分类。

## 归属与依赖规则

- 完整业务闭环模块（Commerce、Loadout、Run）使用 `presentation → application → domain`。`data` 存放该模块拥有的静态资源。
- Combat 按运行时概念组织，不强行套用四层。Combat 的场景、脚本、着色器与专属数据应与对应子域共置。
- Content 只拥有不可变内容定义和目录；不得拥有玩家持有状态、定价或战斗行为。
- Core 只能放真正跨领域的基础能力。不能因为暂时找不到位置就放入 Core 或 `UI/shared`。
- `Game/Bootstrap` 只装配依赖；不得承担领域结算、全局事件转发或动态搭建 UI。
- `UI/shared` 仅放被多个领域复用、且不拥有领域状态的组件。商店、背包、Run 面板和战斗 HUD 必须归入各自领域的 `presentation`。
- `Assets/` 与 `Themes/` 是跨领域的静态视觉资源；领域专属 `.tres`、场景或脚本不应回流到全局资源目录。

## 新文件决策顺序

新增文件前依次判断：

1. 它服务哪个领域或 Combat 子域？放入该范围。
2. 它是 UI 吗？仅跨领域、无领域状态的 UI 才放 `UI/shared`；否则放所属模块的 `presentation`。
3. 它是不可变内容还是运行时状态？前者放 `Content/domain` 或 `*/data`，后者放拥有该状态的领域。
4. 它是否真为跨领域基础能力？只有答案明确为“是”时，才进入 `Core/`。
5. 测试按被测领域归档；跨领域组合、启动和场景契约测试放 `tests/Integration`。

## 命名规范

- 顶层领域目录使用 PascalCase：`Combat`、`Loadout`、`Game`。
- 模块内部目录与资源文件使用小写 snake_case：`battle_gateway.gd`、`normal_shop/`。
- 目录名使用准确、完整的英文术语；禁止保留错拼或不一致的单复数，例如 `Fliper` 应为 `flipper`。
- 不使用阶段编号作为长期目录名，例如 `P4A`、`phase7_previews`；测试应以行为或被测子域命名。
- 同一资源的 `.gd` 与 `.gd.uid` 必须始终同名并作为一个移动单元处理。

## Godot 资源移动

- 场景、资源、脚本和着色器必须通过 Godot 编辑器/Hastur 迁移，不能复制重建 UID，也不能手工修改 `.uid`、`.tscn` 或 `.tres` 中的 UID 值。
- 每个移动批次必须审计 `preload`、`load`、`extends`、`ext_resource`、嵌套 `PackedScene`、`NodePath`、Autoload、主场景、测试夹具和动态目录扫描。
- Windows 上仅大小写变化的改名必须经中间名称完成，并在大小写敏感路径规则下复查。
- 每批迁移完成后，先确认 Godot 可导入和解析，再运行受影响的 GUT；最终运行完整 GUT 和相关运行时场景。

## UI 与测试例外

- UI 结构、布局、字体、颜色和可见性初始值只存在于 `.tscn` 或主题资源。脚本只处理数据、状态刷新及信号；动态子项必须实例化预制场景。
- 中文使用 Fusion Pixel，英文数字使用 Quaver；普通 UI 只使用 10px 或 12px 的复合字体资源。浮动伤害数字可使用 16px Quaver。
- 测试创建的节点和资源应尽量释放。测试不得依赖旧目录路径；路径迁移后的测试必须加载新路径。
