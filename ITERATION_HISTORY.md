# 迭代历史 — 项目 Cprime

> 本文件追踪工作区内**所有按版本演化的东西**:协议(mdin/脚本/RST)、报告、
> 分析代码与数据。部署文件用稳定名(无后缀), 其版本变化在这里 + `archive/` 记录。
> **归档只增不改; 新版本永远另起, 不覆盖历史。**

---

## 1. 协议版本(P1 → P4.1)

| 版本 | 日期 | 变更摘要 | 存档位置 |
|---|---|---|---|
| **P1** | 08-13 | 首交付: 7 个 mdin + smd.RST, sander 兼容(约束块**无** `&end`), SMD 单段直跑 | **无文件**——文件被 P2 覆盖; 仅记录于 docs/M3_模拟协议规划_v01.md |
| **P2** | 08-14 | ① `&end` 修正(pmemd/pmemd.cuda 标准, 约束块后必须 `&end`); ② 脚本拆两段 `run_equil.sh` / `run_smd.sh`; R0=28.80; SMD 单段 | `archive/P2_20260814_and_end修正/`(11 文件/体系, 从 m3_packages 重建) |
| **P3** | 08-14 | ① SMD 分片可重启(1 ns/段, 断点续跑); ② **DUMPFREQ 修复**(缺 `&wt type='DUMPFREQ'` 时 DUMPAVE 恒为空); ③ analyze_smd.py v1; ④ 每段 mdin 由模板 regex 生成 | 展开快照：`archive/P3_20260814_分片可重启/`；原传输容器见该目录的 `SOURCE_ARCHIVES.tsv` |
| **P4** | 08-15 | 初筛核验后 3 项修订: ① **R0 按体系平衡距离**(28.28 / 31.27), 脚本从 smd.RST 读 R0/RF; ② **跳过条件收紧**(rst7 + mdout `Final Performance Info:` + 段目标一致); ③ analyze_smd.py v2(段边界判据 + 解离峰只看拉伸正力 + R0 取数据首行) | 展开快照：`archive/P4_20260815_核验修订/`；原传输容器见该目录的 `SOURCE_ARCHIVES.tsv` |
| **P4.1** | 08-15 | **全链重命名一致**: RST 统一为 `smd_cleaved.RST` / `smd_uncleaved.RST`, 脚本引用与 mdin 模板 DISANG 行同步改名(修复仓库 `amber/` 里"RST 已改名但脚本仍引用 smd.RST"的部署不一致)。**当前部署单元 = `protocols/construct-X/{cleaved,uncleaved}/`** | 工作区即当前快照; 修订说明见 docs/M3_SMD初筛核验修订说明_v01.md |

**指纹(SHA-256, 部署单元 = P4.1):**

| 文件 | SHA-256 |
|---|---|
| `cleaved/run_smd_cleaved.sh` | `2433d6b217fdb51d64d5ee01dc7caa5f4425c10350da0d33cf77f3c28e918e56` |
| `cleaved/smd_pull_cleaved.mdin` | `fefb8fc79b068a09fbca9919e966d8ca96317f54cd1e6d4ee85766a27fdf6eb5` |
| `cleaved/smd_cleaved.RST` | `3bedbe1ecdc8845b4809a36b450fc5b9e310a1c715906a918496ec379fa9b339` |
| `cleaved/analyze_smd.py` | `aea068465269461d60f39be0434cc432b8ed4a650d58ffd7c96e252589e57fa3` |
| `uncleaved/run_smd_uncleaved.sh` | `349051e27601abbfceec10a9595fa8e48d63ac1c8eaf01a5431fd89eee494f5e` |
| `uncleaved/smd_pull_uncleaved.mdin` | `c66dc677e99d152567fd385b220bb13d3371bf626d5014333610478f7d44712b` |
| `uncleaved/smd_uncleaved.RST` | `011264d1ae20ad331d60ded81b8260940491978d413474a041588a020a81fd70` |
| `uncleaved/analyze_smd.py` | `aea068465269461d60f39be0434cc432b8ed4a650d58ffd7c96e252589e57fa3`(与 cleaved 相同) |

**存档指纹:**

| 存档文件 | SHA-256 |
|---|---|
| `archive/P2_*/cleaved/run_smd.sh`(P2 单段版) | `bbcdb1653a27efcff43aba23382483e3fbd37044f6c279e19ee2d37496a0969c` |
| `archive/P2_*/cleaved/smd.RST`(R0=28.80) | `5714b00ba8ec4d0b241d3f028b11dbd19701de7250d4c9df8c1d1124f3c85fe2` |
| P3 cleaved 原传输容器（路径见 `archive/P3_*/SOURCE_ARCHIVES.tsv`） | `2d68fc708a32101691e7abddde3ca4c1e65554a7272c7186a9df379bab935363` |
| P3 uncleaved 原传输容器（路径见 `archive/P3_*/SOURCE_ARCHIVES.tsv`） | `d338a100947a70bdb3981e38a504fee4fa99bd9ddb8f0f1f2840ecc520318143` |
| P3 核心原传输容器（路径见 `archive/P3_*/SOURCE_ARCHIVES.tsv`） | `3d5bdec39c6de7bfbbdeea2d6f1b1b74fd4a9e938b2743ecb949bee20ea677c3` |
| P4 原传输容器（路径见 `archive/P4_*/SOURCE_ARCHIVES.tsv`） | `82de76be417b85dc7ffa4b14a5d190f347c16dded323ace376a4c1b63a8c2637` |

## 2. 报告与文档版本(docs/)

| 文件 | 版本 | 说明 |
|---|---|---|
| M0_背景调研_v01 | v01 | 2026 Mpro MD 调研(项目背景) |
| M1_立项_v01 | v01 | 立项与设计决策 |
| M2_构型X构建说明_v01 | v01 | 构建 + CHARMM-GUI 操作单 |
| M2_体系自检报告_v01 | v01 | 242k 体系自检 |
| M3_模拟协议规划_v01 | v01 | 协议总纲 |
| M3_本地操作说明_v02 | **v02**(v01 已归档 archive/文档旧版/) | 本地部署手册(P4.1 部署单元命名) |
| M3_分界点核验报告_v01 | v01 | 对齐极小化核验 |
| M3_SMD初筛核验报告_v02 | **v02**(v01=初筛版已归档) | 初筛核验 + 3 修订 + 定量方案 |
| M3_SMD初筛核验修订说明_v01 | v01 | P4 修订包说明(含溯源表 §6) |

## 3. 分析数据/图版本(analysis/)

| 文件 | 版本 | 内容 |
|---|---|---|
| cleaved_smd_v01.dat / cleaved_smd_curves_v01.png | v01 | 初筛(5 Å/ns)力-位移/功曲线 |
| uncleaved_smd_v01.dat / uncleaved_smd_curves_v01.png | v01 | 同上(uncleaved) |

> 定量(1 Å/ns)数据回来 → 另起 `_v02`, 不动 v01(初筛证据归档)。

## 4. 规则

1. **部署件稳定名**:protocols/ 与 structures/ 内文件名不挂版本; 变化记在这里 + archive/。
2. **报告/数据升 vNN**:同一主题实质修改 → v02, v03, …; 旧版进 `archive/文档旧版/`。
3. **archive 只增不改**:协议快照 `P{n}_{日期}_{摘要}/`, 文档旧版 `文档旧版/`; 回退从 archive 恢复。
4. **改协议必记**:mdin/脚本/RST 任何行为变化 → 新协议版本 + 指纹更新。
5. **GitHub 同步**:部署件变更后, 同步回推仓库 amber/ 并保持两端一致。

## 5. 2026-08-17 Cprime 仓库结构重构

本次变更是文件组织和来源追踪重构，不构成新的协议版本：

- P1–P4 的历史压缩包已完成成员级安全审计，并重建为可直接浏览的目录快照；
- P4.1 仍是当前部署版本，其规范文件位于 `protocols/construct-X/`；
- 两个 `amber/` 部署目录中的四个脚本/输入文件已与 P4.1 规范版本同步；
- v01 历史分析成果保持不变，正式生产分析成果按命名规则登记为 v02；
- 原始来源、历史快照、当前规范文件和部署副本之间使用 SHA-256 清单建立对应关系；
- 一个无法确认阶段归属的早期 `analyze_smd.py` 已隔离到 `archive/unresolved/`；
- 历史传输压缩包暂不删除，也不重写既往 Git、标签或 Git LFS 历史。

工程审计记录见 `docs/audits/Cprime_archive_audit_20260817/`，当前映射见 `PROVENANCE_MAP.tsv`。
