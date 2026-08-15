# 6VSB Simulation Archive

本仓库是 6VSB 项目的公开文件归档，用于在本地工作环境与获授权的云端 agent 之间同步版本化文件。

## 目录

| 路径 | 内容 |
| --- | --- |
| `references/paper/` | 已发表论文的归档副本 |
| `structures/reference/` | 参考结构文件 |
| `simulations/construct-X/cleaved/` | 构建体 X 的一组输入文件与归档包 |
| `simulations/construct-X/uncleaved/` | 构建体 X 的另一组输入文件与归档包 |
| `scripts/` | 本地校验脚本 |
| `SHA256SUMS` | 已归档文件的 SHA-256 校验值 |

仓库只承担文件托管、版本追踪和完整性校验，不在此处提供研究决策或自动执行模拟。

## 2026-08-14 文件快照

- `simulations/construct-X/cleaved/charmm-gui-8643876985/`
- `simulations/construct-X/uncleaved/charmm-gui-8644096179/`

上述目录是完成写入后的文件快照。按项目记录，它们分别由现有的 `construct_X_*.tgz` 归档展开，并在各自的 `amber/` 目录中加入对应的输入与操作脚本文件。用于保留该补充来源的归档名称为 `cleaved.tgz` 和 `uncleaved.tgz`。

大型或二进制文件使用 Git LFS；脚本、说明和较小的文本文件仍由普通 Git 管理。快照只表示文件集合和校验值已经固定，不对文件内容作研究结论。

## 2026-08-15 SMD 试运行快照

两个 `amber/` 目录中的试运行文件已按原路径归档。迭代前的 `run_smd.sh`、`smd_pull.mdin` 和失败输出 `smd_pull.mdout` 均继续保留；带 `cleaved` 或 `uncleaved` 后缀的替代文件作为独立文件保存，不覆盖旧版。

来源归档、旧版文件、替代文件及其 SHA-256 对应关系见 [`simulations/construct-X/SMD_ITERATION_HISTORY.md`](simulations/construct-X/SMD_ITERATION_HISTORY.md)。大型生成文件继续使用 Git LFS；快照不对文件内容或模拟结果作研究判断。

## 2026-08-15 正式文件更新

两个 `amber/` 目录原有的试运行文件已完整迁移到各自的 `smd_test/` 子目录；正式文件保留在 `amber/` 顶层。迁移后的 90 个试运行文件与上一快照中的对应文件 SHA-256 全部一致。

本次正式文件的来源归档为 `simulations/M3_SMD初筛核验修订包(1).tar.gz`。正式文件、来源成员和迁移关系的文件级记录仍见 [`simulations/construct-X/SMD_ITERATION_HISTORY.md`](simulations/construct-X/SMD_ITERATION_HISTORY.md)。

## 获取

本仓库使用 Git LFS 保存 `.tgz` 归档。首次克隆前请安装 Git LFS：

```powershell
git lfs install
git clone https://github.com/amazingand/6VSB-simulation-archive.git
```

克隆后可验证文件完整性：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-checksums.ps1
```

## 引用

如果本归档支持了公开成果，请引用：

> J. Yu, Z.-W. Zhang, H.-Y. Yang, C.-J. Liu and W.-C. Lu, *RSC Advances*, 2023, **13**, 16970–16983. DOI: [10.1039/D3RA01764H](https://doi.org/10.1039/D3RA01764H)

机器可读信息见 [`CITATION.cff`](CITATION.cff)。

## 维护与许可

- 版本、文件大小和发布规则见 [`MAINTENANCE.md`](MAINTENANCE.md)。
- 不同文件的许可边界见 [`LICENSES.md`](LICENSES.md)。
