# Cprime · 6VSB Simulation Archive

这是 Cprime 项目的公开 GitHub 文件归档，用于保存可版本化的输入文件、脚本、RST 约束文件、工程文档、分析产物和必要的模拟结果摘要。

仓库只承担文件托管、版本追踪、来源映射与完整性验证。当前自动化边界见 [`AGENTS.md`](AGENTS.md)：在用户明确解除限制前，不解读或评价文件所涉及的研究内容，也不据此修改模拟方案。

## 从哪里开始

| 文件 | 用途 |
|---|---|
| [`STATE.md`](STATE.md) | 当前工作阶段、分支、Gate 和下一步 |
| [`TASKS.md`](TASKS.md) | 主代理与子代理的任务图及完成条件 |
| [`DECISIONS.md`](DECISIONS.md) | append-only 工程决策记录 |
| [`MANIFEST.md`](MANIFEST.md) | 当前仓库文件快照与待处理事项 |
| [`ITERATION_HISTORY.md`](ITERATION_HISTORY.md) | 输入、脚本、RST 与相关产物的版本历史 |
| [`PROVENANCE_MAP.tsv`](PROVENANCE_MAP.tsv) | 规范文件与 `simulations/` 部署副本的 SHA-256 对应关系 |

## 目录职责

| 路径 | 职责 |
|---|---|
| `protocols/` | 当前规范部署文件；文件名保持稳定 |
| `archive/` | 不可变的历史快照、来源清单和待归属对象 |
| `simulations/` | 实际部署副本与运行产物 |
| `analysis/` | 按版本号保存的分析数据和图片 |
| `docs/` | 按阶段和版本号保存的说明与审计报告 |
| `structures/` | 参考结构与 construct-X 输入结构 |
| `references/` | 公开参考资料及其许可边界 |
| `scripts/` | 校验、迁移和历史重构工具 |
| `work/` | 本地临时目录，不进入 GitHub |

权威关系是：`archive/` 保存历史，`protocols/` 保存当前规范版本，`simulations/` 保存部署副本和产物。三者通过 SHA-256 映射，不使用硬链接、符号链接或双向自动同步。

## 命名规则

- 项目代号固定写作 `Cprime`。
- `protocols/` 和 `structures/` 中的部署文件使用稳定名称，不添加版本后缀。
- 文档使用 `M{阶段}_{主题}_vNN.md`。
- 分析成果使用 `<system>_<content>_vNN.{dat,png}`。
- 历史快照使用 `P{版本}_{YYYYMMDD}_{摘要}/`，并保持只增不改。
- 已确认不属于正式交付链的草稿进入 `archive/non_delivery/`；未来无法确认归属的对象仍须先隔离，不得强行并入既有版本。

## 历史压缩包策略

历史传输压缩包目前仍保留在原位置，但不再作为最终历史结构。仓库已经建立成员级审计、展开快照和来源清单。压缩包的最终删除将在整体框架验证完成后单独决定。

本阶段只整理仓库当前树，不重写既往提交、标签或 Git LFS 历史。因此旧标签仍可追溯原压缩包，但既有 LFS 占用不会因当前树删除而自动回收。

## GitHub 上传范围

- 允许：说明、清单、脚本、输入、RST、规范结构、合并后的 `smd.out` 和已批准的分析产物。
- 暂缓：历史传输压缩包和来源归属未解决的上传操作。
- 排除：`work/`、分片轨迹、restart、运行中间日志及其他未列入明确白名单的产物。

所有暂存操作应使用明确路径，避免使用无范围的 `git add .`。

## 获取与校验

仓库公开地址：<https://github.com/amazingand/6VSB-simulation-archive>

```powershell
git lfs install
git clone https://github.com/amazingand/6VSB-simulation-archive.git
powershell -ExecutionPolicy Bypass -File .\scripts\verify-checksums.ps1
```

## 引用与许可

机器可读引用信息见 [`CITATION.cff`](CITATION.cff)。论文 PDF 的许可边界及其他文件未被统一授权的说明见 [`LICENSES.md`](LICENSES.md)。

维护规则见 [`MAINTENANCE.md`](MAINTENANCE.md)。
