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
