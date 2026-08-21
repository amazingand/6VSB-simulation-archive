# Cprime 终版结构

最新 Git 树以 `01_研究问题` 至 `06_论文` 为唯一项目主线。`cleaved` 与 `uncleaved` 在体系、运行和分析层严格隔离，仅在 `05_对比` 汇合。

- `03_SMD运行/<体系>` 保存按 `体系 + vNN` 命名的规范脚本、输入与 RST，以及最终合并正式输出。
- `04_分析/<体系>` 保存线上分析、本地分析、contacts 和 replica 工具。
- `history/` 仅保存已展开并具有清单的历史快照；不保存传输压缩包。
- `simulations/`、`work/` 和 `临时文件存放/` 只存在于本地，不进入最新 Git 树。
- 退出最新树的旧路径仍可通过 Git 历史、旧标签和 `LEGACY_TREE_REMOVAL_MAP.tsv` 追溯。
