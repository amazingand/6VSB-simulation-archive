# Cprime 当前文件快照

快照时间：2026-08-17（Asia/Shanghai）

本文件只记录仓库工程状态、文件来源和待处理事项，不评价文件所涉及的研究内容。

## Git 基线

- 公开仓库：`amazingand/6VSB-simulation-archive`
- 基线提交：`bd4fa7de20cca296c388f132c1bb358e9ce2e18f`
- 基线来源：PR #6 合并后的 `main`
- 重构分支：`codex/restructure-cprime-history-2026-08-17`
- 正式生产汇总提交：`598d2c6c510781042da7c21f81a4ccabe6d646c9`，发生于 2026-08-17 02:41:26 +08:00

## 当前目录状态

| 路径 | 状态 |
|---|---|
| `protocols/construct-X/` | 两套当前规范部署单元已建立 |
| `archive/` | P1–P4 已重建为非压缩历史结构；另有 S0 来源清单和一个已确认的非交付 v0 草稿 |
| `analysis/` | v01 历史分析文件与 v02 正式生产分析文件已分开保存 |
| `docs/` | 历史文档及 2026-08-17 压缩包审计报告已纳入 |
| `structures/construct-X/` | 两个输入结构已纳入，现有 `structures/reference/` 保持不变 |
| `simulations/` | 部署副本和运行产物保持原路径 |
| `PROVENANCE_MAP.tsv` | 26 个规范文件/产物映射全部为 `MATCH` |

## 历史压缩包审计

- 物理压缩包：13
- 唯一容器内容：9
- 安全性异常：0
- 精确重复容器组：4
- 解压文件：348
- 解压文件 SHA-256 异常：0
- 同规范路径异内容组：62
- 已确认错误冲突：0
- 已确认非交付草稿：1 个 `analyze_smd.py` v0 文件内容，不计入正式 v1→v2 交付链

完整证据见 `docs/audits/Cprime_archive_audit_20260817/`。

## 未提交文件保护

原工作目录中的 6 个未提交文件已在被 Git 忽略的 `work/pre_restructure_guard_20260817/` 保存：

- 可逆 Git patch；
- 六个逐文件副本；
- 文件大小、时间和 SHA-256 清单。

其中四个脚本/输入文件对应当前 P4.1 规范版本，已经纳入重构分支；两个 `mdinfo` 属于运行时状态文件，未纳入本次提交。

## 暂缓事项

- 不删除任何现存 `.tgz` 或 `.tar.gz`。
- 不重写 Git 提交、标签或 Git LFS 历史。
- 不上传新的历史传输压缩包。
- 不把 `archive/non_delivery/` 中的草稿计入 P1–P4 正式交付链。
- 整体框架验证完成后，再讨论临时压缩包的最终删除及 LFS 历史治理。

## 下一步

1. 独立 Reviewer 检查正式树、清单、路径映射和 Git diff。
2. 重新生成仓库级 `SHA256SUMS`。
3. 从干净检出验证文件可复现性。
4. 仅按明确路径暂存、提交并推送重构分支。
5. 创建 draft PR，等待用户审阅后再合并。
