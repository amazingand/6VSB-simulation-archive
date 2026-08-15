# SMD 文件迭代记录

本文档只记录文件名、来源路径、大小与 SHA-256 校验值，用于版本追踪和完整性核验；不解释文件内容，也不提供研究或模拟参数建议。

## 2026-08-15 试运行快照

本次快照保留以下三类文件：

1. 迭代前的 `run_smd.sh` 与 `smd_pull.mdin`；
2. 迭代前失败输出 `smd_pull.mdout`；
3. 带 `cleaved` 或 `uncleaved` 后缀的替代文件，以及试运行生成的同目录文件。

试运行生成文件均保留在两个 `amber/` 目录原位，其 SHA-256 记录在仓库根目录的 `SHA256SUMS` 中。

### cleaved

来源归档：`simulations/construct-X/cleaved/cleaved (1).tgz`

- 大小：9,308 字节
- SHA-256：`2d68fc708a32101691e7abddde3ca4c1e65554a7272c7186a9df379bab935363`

| 角色 | 文件 | 大小（字节） | SHA-256 |
| --- | --- | ---: | --- |
| 旧版脚本 | `amber/run_smd.sh` | 4,092 | `bbcdb1653a27efcff43aba23382483e3fbd37044f6c279e19ee2d37496a0969c` |
| 旧版输入 | `amber/smd_pull.mdin` | 563 | `634076eacd93e0a1989809448400ef722ac2c397837873770251361e4f5ed9c1` |
| 旧版失败输出 | `amber/smd_pull.mdout` | 8,092 | `4b48e190cf35250898fafb58717b7f27ecf5834c20a86acabed2d0734f8b01bb` |
| 当前替代脚本 | `amber/run_smd_cleaved.sh` | 6,683 | `039b90244a665273fdfa758d62f07ab47ef8c9c2ebb3122f237c194235484a01` |
| 当前替代输入 | `amber/smd_pull_cleaved.mdin` | 604 | `2a33433aa3b9f90df0650e7e5e2e5e7eefc36de5fb27d996fd96c360470dc61b` |

归档内 `cleaved/smd_pull.mdin` 与当前替代输入的 SHA-256 相同。归档内 `cleaved/run_smd.sh` 的 SHA-256 为 `2ced9b9502e98871b2c28f686645614146dd02974cbadae93996e73947333d3b`，与当前替代脚本不同；因此两者均被保留，不宣称逐字节相同。

### uncleaved

来源归档：`simulations/construct-X/uncleaved/uncleaved(1).tgz`

- 大小：9,305 字节
- SHA-256：`d338a100947a70bdb3981e38a504fee4fa99bd9ddb8f0f1f2840ecc520318143`

| 角色 | 文件 | 大小（字节） | SHA-256 |
| --- | --- | ---: | --- |
| 旧版脚本 | `amber/run_smd.sh` | 4,092 | `bbcdb1653a27efcff43aba23382483e3fbd37044f6c279e19ee2d37496a0969c` |
| 旧版输入 | `amber/smd_pull.mdin` | 555 | `61cd632030e2cd3adab6c01144dc2ca669ce37fe6008ba163773d2c67640c904` |
| 旧版失败输出 | `amber/smd_pull.mdout` | 8,094 | `73310c7b9587781cded39592fbf2e05c3e1a6ada3309c7b902f9ad06d5e23fff` |
| 当前替代脚本 | `amber/run_smd_uncleaved.sh` | 6,699 | `9c5cd5f1a7fe1ec8239074e5d3bf57e00feb1277b914c400adb3a50f61a45b4e` |
| 当前替代输入 | `amber/smd_pull_uncleaved.mdin` | 596 | `d8145819476e9aae38be5cc5d807da247cd5090d55418482e4c64a9b9094b212` |

归档内 `uncleaved/smd_pull.mdin` 与当前替代输入的 SHA-256 相同。归档内 `uncleaved/run_smd.sh` 的 SHA-256 为 `2ced9b9502e98871b2c28f686645614146dd02974cbadae93996e73947333d3b`，与当前替代脚本不同；因此两者均被保留，不宣称逐字节相同。

## 2026-08-15 正式文件更新

来源归档：`simulations/M3_SMD初筛核验修订包(1).tar.gz`

- 大小：12,406 字节
- SHA-256：`82de76be417b85dc7ffa4b14a5d190f347c16dded323ace376a4c1b63a8c2637`

`analyze_smd.py` 由用户从同名解压目录直接移动到目标工作目录，因此解压目录中不再保留该文件。核查确认来源归档内存在该成员，其 SHA-256 为 `aea068465269461d60f39be0434cc432b8ed4a650d58ffd7c96e252589e57fa3`；两个工作目录中的正式副本也与该校验值一致。

### 正式文件

| 目录 | 文件 | 大小（字节） | SHA-256 |
| --- | --- | ---: | --- |
| cleaved | `amber/analyze_smd.py` | 8,374 | `aea068465269461d60f39be0434cc432b8ed4a650d58ffd7c96e252589e57fa3` |
| cleaved | `amber/run_smd_cleaved.sh` | 9,175 | `d6f86a2f9e639bd6d39239a4b508c9250c996c870a16227ff704c2912f3294e2` |
| cleaved | `amber/smd_pull_cleaved.mdin` | 620 | `f0416a6f8982ce282eaae38a3a68c97bf1ee45eb8aa9edaff8f3de03a8937765` |
| cleaved | `amber/smd_cleaved.RST` | 1,999 | `3bedbe1ecdc8845b4809a36b450fc5b9e310a1c715906a918496ec379fa9b339` |
| uncleaved | `amber/analyze_smd.py` | 8,374 | `aea068465269461d60f39be0434cc432b8ed4a650d58ffd7c96e252589e57fa3` |
| uncleaved | `amber/run_smd_uncleaved.sh` | 9,203 | `5b8337c66ae43e38c05950348e8fd1315e719c67ba5a49d399684ed9fc0daa44` |
| uncleaved | `amber/smd_pull_uncleaved.mdin` | 612 | `aca4246553812739d1c49d01c4fca07ea5beadd4146d88602d100af738c8ac0f` |
| uncleaved | `amber/smd_uncleaved.RST` | 2,001 | `011264d1ae20ad331d60ded81b8260940491978d413474a041588a020a81fd70` |

### 试运行文件迁移

- cleaved：45 个文件迁移到 `amber/smd_test/`，全部与上一快照对应文件的 SHA-256 一致。
- uncleaved：45 个文件迁移到 `amber/smd_test/`，全部与上一快照对应文件的 SHA-256 一致。
- 为区分用途，原带后缀脚本、输入、RST 和分析脚本在 `smd_test/` 中增加 `_test` 标记；文件内容校验值保持不变。
- 两份 `smd_run.log` 作为试运行归档的一部分显式纳入版本控制，不受仓库的一般日志忽略规则影响。

## 追溯规则

- 不覆盖或删除上述旧版文件与失败输出。
- 来源归档、当前替代文件和生成文件分别计算 SHA-256，不以相似文件名代替完整性校验。
- Git 标签用于固定一次仓库快照；后续迭代使用新提交与新标签，不移动既有标签。
- 文件时间戳仅作辅助信息，Git 快照的权威标识为提交、标签与 `SHA256SUMS`。
