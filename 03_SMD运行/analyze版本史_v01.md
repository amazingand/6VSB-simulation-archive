# M3 · analyze_smd.py 版本迭代确认报告

> **一句话结论**:正式交付链只有 **v1 → v2** 两版;P4.1 为纯改名、脚本未动;**没有 v3**。
> 当前部署单元(`protocols/construct-X/{cleaved,uncleaved}/`)与 GitHub 仓库 `amber/`
> 两侧均为 **v2**,逐字节一致,无漂移。
>
> 核验日期: **2026-08-17**;依据: P3 / P4 存档包 + 当前部署单元 + 仓库实拉,四个独立来源。

---

## 1. 核验方法(四个独立来源交叉比对)

| # | 来源 | 路径 | 用途 |
|---|---|---|---|
| ① | P3 存档 | `archive/P3_20260814_分片可重启/{cleaved,uncleaved}.tgz` | 提取 v1 |
| ② | P4 存档 | `archive/P4_20260815_核验修订/M3_SMD初筛核验修订包.tar.gz` | 提取 v2 |
| ③ | 当前部署单元 | `protocols/construct-X/{cleaved,uncleaved}/analyze_smd.py` | 核验现役版 |
| ④ | GitHub 仓库 | `simulations/construct-X/{cleaved,uncleaved}/charmm-gui-*/amber/analyze_smd.py`(API 实拉) | 核验部署一致性 |

方法: 三处解包/实拉后逐一 `sha256sum`,并对 v1/v2 做逐行 `diff`。

## 2. 版本链总览

| 版本 | 时间 | 内容 | 指纹(SHA-256) | 位置 |
|---|---|---|---|---|
| **v0(草稿)** | 08-14 早(未定稿) | 最早草稿,列 1 当时间读 | `63cdce37…9a842` | 仅 `tmp/m3_packages/`,**从未交付** |
| **v1** | 08-14 17:15 | DUMPAVE 语义定死后完整重写,分片跨段累计 | `3c26487e…dad0` | `archive/P3_*/{cleaved,uncleaved}.tgz`(两体系同版) |
| **v2** | 08-15 08:15 | 三处修复(§4) | `aea06846…e57fa3` | P4 修订包 + `protocols/` 现役 + 仓库 `amber/` |
| P4.1 | 08-15 | 纯改名,analyze_smd.py **未改动**(仍 v2) | `aea06846…e57fa3` | `protocols/construct-X/{cleaved,uncleaved}/` |

> 大小佐证: v1 = 6756 B, v2 = 8374 B(仓库树记录两体系均为 8374 B,与 v2 精确吻合)。

## 3. 各版本要点

### 3.1 v0 —— 暂存草稿(非交付链)

`tmp/m3_packages/` 里留存的早期版本。判据特征: 把 DUMPAVE **第 1 列当时间**读入
(`t.append(vals[0])`),无 `derive_time`、无 `cumulative_work`、无 `--speed`——即**早于
08-14 下午「DUMPAVE 语义定死」(列 1 = 约束目标位置 r2,非时间)的那次重写**。它从未进入
任何交付包,不属于正式版本链,记录在案以免日后在暂存区搜到造成困惑。

### 3.2 v1 —— P3 分片可重启交付版(08-14 17:15, `3c26487e…`)

分片架构落成时交付的完整版,要点:

- **列 1 读为 r2 目标位置**(不再是时间),时间由 `t = (r2 − R0) / v` 反推;
- `R0 = 28.80` **硬编码**(当时两体系共用);
- `cumulative_work()`: 段边界检测 `diff(w) < -1.0`(功掉 1 kcal/mol 以上即视为段重启),
  自动把各段功从 0 拼接成全程累计;
- `--speed 5|1` 拉速参数、4 联图、`.dat` 输出。

### 3.3 v2 —— P4 三处修复版(08-15 08:15, `aea06846…`)

初筛核验后发现三个问题,逐一修复:

1. **段边界判据收紧**: `diff(w) < -1.0`(纯掉落)→ `find_resets()` =
   掉 **>1 kcal/mol 且** 掉落后落在 0 附近(`|w| < 0.5`)。
   修复对象: uncleaved 开局弹簧压缩瞬态(功从 0 掉到负值)被误判成段边界 →
   **误报 7 段、累计功虚高 1.4 kcal/mol**(97.4 vs 真值 96.014)。
2. **解离峰值只看拉伸正力**: `np.abs(f).max()` → `np.where(f > 0, f, 0)` 中取峰;
   负力 = 压缩(装载伪迹,如 uncleaved 开局 ≈2475 pN 压缩),不参与解离统计;
   并新增**开局预紧提示**(`|Δr0| > 1.5 Å` 时打印告警)。
3. **R0 不再硬编码**: 删 `R0 = 28.80`,改为取数据首行目标位置 `R0 = r2[0]`,
   支持各体系自定义 R0(cleaved 28.28 / uncleaved 31.27),时间轴恒从 0 起。

另含绘图打磨(零线 `axhline(0)`、配色、`.dat` 增 r2 列)与文档头修订。

### 3.4 P4.1 —— 全链重命名(脚本未动)

P4.1 只做 RST 统一命名(`smd_cleaved.RST` / `smd_uncleaved.RST`)与脚本/mdin 引用同步;
`analyze_smd.py` 与 P4 版**逐字节相同**(指纹一致),仍为 v2。

## 4. v1 → v2 逐行差异证据(diff 摘录)

| 位置 | v1 | v2 |
|---|---|---|
| 段边界检测 | `resets = np.where(np.diff(w) < -1.0)[0]` | `find_resets(w)`: `drop 且 abs(w[i+1]) < 0.5` |
| R0 | `R0 = 28.80`(硬编码) | `R0 = float(r2[0])`(取数据首行) |
| 时间反推 | `derive_time(r2, speed)` 用全局 R0 | 内联 `t = (r2 - R0)/(speed*1e-3)`,R0 为本文件首行 |
| 力峰 | `fmax = abs(f).max()`(绝对值) | `fl_t = where(f>0, f, 0)`(仅拉伸正力) |
| 开局伪迹 | 无 | `if abs(dr0) > 1.5: [提示] 初始弹簧预紧…` |
| 输出 | 力峰、功、解离距离 | 新增"最大\|力\|"、拉伸峰值 pN @ COM 距离、段数 |

## 5. 交叉一致性核验结果

| 检查项 | 结果 |
|---|---|
| P3 存档 cleaved / uncleaved 的 analyze | 内容一致,均 `3c26487e…`(v1) |
| P4 修订包内 analyze | 单份,`aea06846…`(v2); 不在体系子目录,两体系共用 |
| 现役 `protocols/` cleaved vs uncleaved | 指纹相同,均 `aea06846…`(v2) |
| 仓库 `amber/` 两体系(API 实拉) | 均 `aea06846…`、8374 B、内容逐字节一致 = **v2** |
| **部署单元 vs 仓库** | **两侧同为 v2,零漂移** |
| ITERATION_HISTORY 记录 | P3=analyze v1、P4=analyze v2 两张表与实况吻合 |
| P2 存档 | 刻意不含 analyze(P2 阶段尚无脚本),11 文件/体系,记录正确 |

## 6. 结论与纪律

- **正式链: v1(08-14, P3)→ v2(08-15, P4 三修复); P4.1 改名不动脚本; 无 v3。**
- 现役与仓库部署同步停留在 **v2**;任何对分析逻辑的修改 = 升版本(v3),进 `archive/`
  快照 + 更新 `ITERATION_HISTORY.md`,**不覆盖历史**。
- `tmp/` 中的 v0 草稿为暂存残留,非交付物,不计入版本链。

---
*本报告由对四个独立来源的 sha256sum + diff 核验产生;指纹与存档位置可在
`ITERATION_HISTORY.md` 与 `archive/P{n}/说明.md` 复查。*
