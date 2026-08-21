# Cprime 重构迁移状态

本分支以 `Cprime_migration_20260819` 的论文逻辑目录为结构基线，并采用“复制、校验、映射优先”的方式整合本地六轮运行资料。

## 已完成

- 已导入并校验线上迁移包；重复的 `clawsGO_6VSB_重构修订建议_v01-1.md` 未重复纳入。
- `cleaved` 与 `uncleaved` 始终使用独立目录和独立映射表。
- 本地六轮输出已在本地 `work/` 候选目录中完成复制、规范命名和逐项 SHA-256 校验。
- 线上仓库只迁移正式生产合并输出和分析产物，不引入 chunk、轨迹、restart 等大体积中间文件。
- 线上候选 28 项已完成受控对照：14 项逐字节相同、10 项经确认为正确运行目录下的等效规范替代、4 项仅有线上基线。
- 14 项逐字节相同文件已采用 `Cprime_migration_20260819` 规范名；本地相同部署镜像不重复进入仓库，只保留来源映射。
- 10 项等效替代已使用线上 `cleaved/uncleaved + vNN` 命名版本作为唯一规范文件；本地旧名只保留来源记录。
- 本地第二轮 SMD 测试的 8 个必要脚本、输入、RST 和分析脚本已按体系命名为 `v01` 并经 SHA-256 验证。
- `analysis/`、`protocols/`、`references/`、`structures/`、`simulations/` 已从最新 Git 树退出；原本地 `simulations/` 仍原位保留。
- 展开历史快照已统一迁移至 `history/`，传输压缩包不再进入最新树。

## 未决项

无。线上独有的 4 个 replica 脚本作为明确的单侧基线保留；生成的 chunk 输入和 RST 仅在本地追溯，不作为需要发布的规范源文件。

## 追溯入口

- `ONLINE_IMPORT_MAP.tsv`：线上迁移包导入记录。
- `03_SMD运行/LOCAL_SIX_RUNS_MAP.tsv`：本地六轮输出的来源与规范命名映射。
- `03_SMD运行/CROSS_SIDE_CONTENT_MAP.tsv`：28 项线上候选的字节级对照结论。
- `03_SMD运行/LOCAL_TEST_PROMOTION_MAP.tsv`：本地第二轮 8 个规范文件的来源、新名和校验值。
- `03_SMD运行/BASELINE_SINGLE_SIDE_MAP.tsv`：没有对侧基线的线上或本地文件。
- `03_SMD运行/QUARANTINE_INVENTORY.tsv`：198 个隔离副本的完整分类清单。
- `docs/repository-history/LEGACY_TREE_REMOVAL_MAP.tsv`：退出最新树的 474 个旧路径的校验值与去向。
- `03_SMD运行/<体系>/RUN_STAGE_MAP.tsv`：每个体系的三轮运行对照。
- `04_分析/<体系>/SOURCE_MAP.tsv`：线上分析、本地分析与来源状态。
