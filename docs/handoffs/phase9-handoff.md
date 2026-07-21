# Phase 9 收尾记录（完成）

Phase 9 锁定了最终架构文档、测试归档和去兼容审计。当前系统的唯一运行时事实由 `docs/architecture/current-runtime.md` 与 ADR-0001 约束；历史阶段文档已经明确标注为历史基线，不能再被当作当前入口。

- 新增 [ADR-0001](../adr/0001-final-architecture-cutover.md)，锁定模块边界、唯一状态所有权、唯一战斗完成路径和无迁移兼容运行时。
- README 与 CONTEXT 改为当前目录、流程和领域词汇；`tests/Game/debug` 镜像 `Game/Debug`，跨领域测试继续留在 `tests/Integration`。
- 删除 `BattlePlan.battle_group`、`RewardOption.option_id` 与 `RunState.advance_to_node` 的 Phase 2 兼容契约，并迁移所有测试调用者。
- 去兼容静态审计确认生产代码不存在旧目录路径、Event bridge、旧控制器、BuffManager、MarbleUpgradeSystem 或上述公开兼容 API 的残留。
- 当前 worktree 的递归 GUT 通过：28 scripts / 161 tests / 1775 asserts / exit 0。详细记录见 [Phase 9 验证](../testing/evidence/phase9-verification.md)。

运行流程已在当前提交的 game executor 上闭环：主场景启动后，真实 `Enemy.defeat → BattleSession → BattleGateway → RunFlowController` 进入奖励；领取奖励后返回节点选择；再从节点进入 `crossroads` 事件，并由 `EscapeButton.pressed` 经过 UI adapter 结算并返回节点。随后由节点按钮进入普通商店，并由商店退出按钮返回节点。另有 Node Choice、Run Event 与 Shop 三个预览场景分别独立运行并保存截图。命令返回、场景路径、流程 phase、运行日志与截图均记录在 [Phase 9 验证](../testing/evidence/phase9-verification.md)。

已知非阻断项：GUT 仍输出既有插件 UID fallback 与警告；不影响 exit 0，应在独立的第三方插件维护任务中处理。
