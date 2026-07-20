# Phase 1 历史测试 checkpoint/hash manifest

以下路径与哈希记录 Phase 1 最终完整 GUT 后的历史工作树内容，算法为 `git hash-object`。它们用于审计当时 Commerce 垂直切片的验证资产，**不是当前 HEAD 的 hash 声明，也不再命令当前阶段把 tests 保持为未提交**。后续 `7366094` 已提交 Phase 0–2 测试，部分文件又在 Phase 2 演进或删除；需要当前 hash 时必须重新计算，不能沿用本表。

```text
2052ea107d6b25cc31e955340dd17be4081354fb  tests/Commerce/fake_health_adapter.gd
99901c3806c88c7c737ae35062bd83e799973e4f  tests/Commerce/fake_health_adapter.gd.uid
41f0c655e9a39c145fc730e2ea2f30911ea239f0  tests/Commerce/fake_inventory_adapter.gd
69c28530faf5246dd913aea160c4cda9c52c332e  tests/Commerce/fake_inventory_adapter.gd.uid
647d6e02254f079225725adbd3605b37244b6f44  tests/Commerce/fake_progression_adapter.gd
ea53030f4aef9b0bf346356ce9d18bafc85717f0  tests/Commerce/fake_progression_adapter.gd.uid
1ec0960ce4d3fbb81b3c2ac689ab7ab4ea3d6a20  tests/Commerce/fake_wallet_adapter.gd
3892f6fec657743da7ad1302516905e648c7bee2  tests/Commerce/fake_wallet_adapter.gd.uid
fc453fc458e49cad05141ca352b7c151dc1c9141  tests/Commerce/test_current_adapters.gd
00d26a9063bd2139f7e64cb8658e14803a29c92b  tests/Commerce/test_current_adapters.gd.uid
b784fb210e703ad5a43165ebf9d955e3b7e88b3f  tests/Commerce/test_devil_shop_session.gd
029705f502e5783b76307c81c4cb66eb30f190a4  tests/Commerce/test_devil_shop_session.gd.uid
6f47f488636635ace29131a3e3e8ab0113865497  tests/Commerce/test_normal_shop_sale_service.gd
d0c44ab0dc225bcbd99ce4e3badf8452d36bd120  tests/Commerce/test_normal_shop_sale_service.gd.uid
6bf6044c650c92005783fabb37456684d1f1ef43  tests/Commerce/test_normal_shop_session.gd
782012bb66a27c7fbaeef5a5619eb2de32893b1a  tests/Commerce/test_normal_shop_session.gd.uid
6810ae956c00c9df4b0f4dacbc8d858b72cc17d8  tests/Commerce/test_presentation_delegation.gd
be47d2883477a39d4d9a5c6777821a9730ac993d  tests/Commerce/test_presentation_delegation.gd.uid
dec481276c623a7bb58558ceca57bfaef8a9fa45  tests/Integration/test_scene_contracts.gd
d67bcd4f71d0a260e011415436882c410ee0fa7a  tests/Integration/test_scene_contracts.gd.uid
572ff960ba326082dd77677fe82ec09a7d43751a  tests/test_devil_shop_upgrade_offers.gd
001f8d7cd1a6fdecb5aa2cb380493753bfe323be  tests/test_devil_shop_upgrade_offers.gd.uid
197b2366de2519783286b71271a283b127c94f69  tests/test_shop_upgrade_offers.gd
c7ce8a47641760d36ad403cd75fa6bc9012e3c78  tests/test_shop_upgrade_offers.gd.uid
```

以下三项降低为**历史交接 digest**：对应 blob 未归档，当前仓库不可恢复/重算；保留原 digest 和路径只用于追踪交接记录，不可据此证明内容或测试结果：

- `fc453fc458e49cad05141ca352b7c151dc1c9141  tests/Commerce/test_current_adapters.gd`；
- `00d26a9063bd2139f7e64cb8658e14803a29c92b  tests/Commerce/test_current_adapters.gd.uid`；
- `6810ae956c00c9df4b0f4dacbc8d858b72cc17d8  tests/Commerce/test_presentation_delegation.gd`。

本表内容应保持为历史 checkpoint，不随当前文件变化改写。当前阶段若新增测试证据，应在对应阶段台账/日志中记录新的 commit 或 blob hash；测试是否提交由该阶段的明确 checkpoint 范围决定，并须逐路径审阅。
