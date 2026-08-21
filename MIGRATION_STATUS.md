# Cprime 重构迁移状态

本分支以 `Cprime_migration_20260819` 的论文逻辑目录为结构基线，并采用“复制、校验、映射优先”的方式整合本地六轮运行资料。

## 已完成

- 已导入并校验线上迁移包；重复的 `clawsGO_6VSB_重构修订建议_v01-1.md` 未重复纳入。
- `cleaved` 与 `uncleaved` 始终使用独立目录和独立映射表。
- 本地六轮输出已在本地 `work/` 候选目录中完成复制、规范命名和逐项 SHA-256 校验。
- 线上仓库只迁移正式生产合并输出和分析产物，不引入 chunk、轨迹、restart 等大体积中间文件。
- 线上候选 28 项已完成受控 SHA-256 对照：14 项逐字节相同、10 项同用途但内容不同、4 项仅有线上基线。
- 14 项逐字节相同文件已采用 `Cprime_migration_20260819` 规范名；本地相同部署镜像不重复进入仓库，只保留来源映射。

## 暂缓项

10 项同用途但 SHA-256 不同的 Shell、MDIN 和 Python 文件继续按体系隔离，并标记为 `UNRESOLVED_CONTENT_DIFFERENCE`。在用户手动判定前不做静默覆盖或内容合并。

线上独有的 4 个 replica 脚本与本地第二轮独有的测试脚本、输入、RST、分析脚本及生成文件属于单侧基线，不强行配对，也不据此推断等价关系。

## 追溯入口

- `ONLINE_IMPORT_MAP.tsv`：线上迁移包导入记录。
- `03_SMD运行/LOCAL_SIX_RUNS_MAP.tsv`：本地六轮输出的来源与规范命名映射。
- `03_SMD运行/CROSS_SIDE_CONTENT_MAP.tsv`：28 项线上候选的字节级对照结论。
- `03_SMD运行/UNRESOLVED_CODE_MAP.tsv`：10 组内容不同候选在隔离区中的全部来源副本。
- `03_SMD运行/BASELINE_SINGLE_SIDE_MAP.tsv`：没有对侧基线的线上或本地文件。
- `03_SMD运行/QUARANTINE_INVENTORY.tsv`：198 个隔离副本的完整分类清单。
- `03_SMD运行/<体系>/RUN_STAGE_MAP.tsv`：每个体系的三轮运行对照。
- `04_分析/<体系>/SOURCE_MAP.tsv`：线上分析、本地分析与来源状态。
