# M3 SMD 初筛核验修订包 — 说明

> **本文档是 P4 修订包的说明(2026-08-15 历史记录)**,文中的包内路径(`cleaved/smd.RST`
> 等)指当时的交付包结构。当前部署单元为 **P4.1 全链重命名版**
> (`protocols/construct-X/{cleaved,uncleaved}/`, RST 名为 `smd_cleaved.RST` /
> `smd_uncleaved.RST`),部署用法见 `README.md` §4 与 `docs/M3_本地操作说明_v02.md`。
> 核验报告现为 `docs/M3_SMD初筛核验报告_v02.md`。

2026-08-15。初筛(5 Å/ns)已核验,本包为定量运行(1 Å/ns)前所需的修订。
**用法见《M3_SMD初筛核验报告.md》;替换文件见末尾"部署清单"。**

---

## 1. 改了什么(相对上一版分片可重启包)

| 文件 | 修订 | 原因 |
|---|---|---|
| `run_smd.sh` / `run_smd_cleaved.sh` / `run_smd_uncleaved.sh` | **R0/RF 从 smd.RST 读取**(r2=起点, r4=终点), 不再硬编码 28.80→55.0 | 各体系需按自己的平衡 COM 距离起拉(见 §2) |
| 同上 | **断点续跑跳过条件收紧**: rst7 存在 + mdout 含 `Final Performance Info:` + 段 RST 的 r4 与本次目标一致, 三者齐备才跳过; 否则自动删除该段重跑 | 初筛 cleaved chunk00 止于 NSTEP=482000(进程被杀), 旧逻辑只看 rst7 存在会静默跳过截断段; 且换拉速(5→1 Å/ns)后旧段残留会污染定量运行 |
| 同上 | **合并 smd.out 只按本次 NSEG 顺序合并**, 不碰残留旧段 | 先跑定量(27 段)再跑初筛(6 段)时, `smd_chunk*.out` 通配会混入旧段 |
| `analyze_smd.py` | **段边界判据**: 功掉 >1 kcal/mol **且**掉落后落在 0 附近(\|w\|<0.5), 才视为段重置 | 旧判据把 uncleaved 开局压缩瞬态(功 0→−1.4)误判为段边界, 报"7 段"、累计功多算 ~1.4 kcal/mol |
| 同上 | **解离峰值只看拉伸正力**; 负力=压缩(弹簧预紧伪迹), 单独提示 | uncleaved 初筛里 2475 pN 的"最大力"是开局压缩伪迹, 不是解离力 |
| 同上 | **R0 取数据首行目标位置**, 时间轴从 0 起 | 支持各体系自定义 R0 |
| `cleaved/smd.RST` | r2=r3: **28.80 → 28.28** | 该体系 eq4 平衡 COM 距离 = 28.28 Å(实测) |
| `uncleaved/smd.RST` | r2=r3: **28.80 → 31.27** | 该体系 eq4 平衡 COM 距离 = 31.27 Å(实测) |
| `smd_pull_*.mdin` | 仅修正首行注释(总量不再固定) | 文档一致性, 语法/参数未动 |

## 2. 为什么各体系要改起点 R0

初筛核验发现: 两个体系的平衡 COM 距离不同(cleaved 28.28 Å / uncleaved 31.27 Å),
而 smd.RST 起点硬编码 28.80 Å → uncleaved 开局弹簧被压缩 2.47 Å(力 −35.6
kcal/mol/Å ≈ 2475 pN), 前 ~50 ps 弹簧在把界面往回推, 是装载伪迹而非解离信号。

修订后: 各体系从自身平衡距离起拉, 弹簧开局松弛(力≈0), 力谱干净。
**若你坚持两体系用同一绝对起点(28.80)以对齐横轴**, 把 `smd.RST` 的 r2/r3 改回
28.80 即可, 脚本会自动适配(但 uncleaved 的开局压缩伪迹会保留)。

## 3. 部署清单(每个体系自己的 amber 目录)

```
cleaved 体系目录:  复制  cleaved/smd.RST     → 覆盖 smd.RST
                   复制  run_smd_cleaved.sh  → 覆盖(或删掉旧的)
                   复制  analyze_smd.py      → 覆盖
uncleaved 体系目录: 复制  uncleaved/smd.RST  → 覆盖 smd.RST
                   复制  run_smd_uncleaved.sh→ 覆盖
                   复制  analyze_smd.py      → 覆盖
```

`smd_pull.mdin`(**不变**,无需替换);`step3_input.parm7`/`eq4_npt.rst7` 不动。
`run_smd.sh` 与各体系的 `smd_pull.mdin` 为**溯源历史文件**(见 §6),保留不部署。

> 若想先用通用版 `run_smd.sh <cleaved|uncleaved>`, 它读当前目录的 `smd_pull.mdin` 与 `smd.RST`, 只需把对应体系的 smd.RST 拷过去。

## 4. 定量运行(1 Å/ns)

替换完成后直接投定量, 脚本会**自动识别并重跑**与本次参数不符的旧段:

```bash
# cleaved:  R0=28.28 → 55.0, 1 Å/ns, 26.72 ns, 27 段
nohup bash run_smd_cleaved.sh --smd-speed 1 --engine=pmemd.cuda > smd_quant.log 2>&1 &

# uncleaved: R0=31.27 → 55.0, 1 Å/ns, 23.73 ns, 24 段
nohup bash run_smd_uncleaved.sh --smd-speed 1 --engine=pmemd.cuda > smd_quant.log 2>&1 &
```

(若未配好 NVIDIA WSL 驱动, 去掉 `--engine=pmemd.cuda` 会回退 CPU pmemd。)

跑完合并 smd.out 后:

```bash
python analyze_smd.py smd.out --speed 1 --plot
```

## 5. 断点续跑注意

- 某段被杀(如初筛 chunk00 那种 NSTEP<500000 且无 `Final Performance Info:`):
  重跑脚本会删除该段、从上一完整段重跑, **无需手动清理**。
- 换拉速/换 R0 后重跑: 旧段目标不符, 同样自动删除重跑。
- 已完成的段: 秒跳过, 不动轨迹。

## 6. 溯源历史文件(保留,不参与部署)

按用户约定, `run_smd.sh` 与各体系的 `smd_pull.mdin` 保留在包内作为**协议溯源链**,
仅作追溯, 不用于生产运行:

| 溯源文件(祖先) | 生产文件(当前为准) | 关系 |
|---|---|---|
| `run_smd.sh`(通用分片脚本, 传体系参数) | `run_smd_cleaved.sh` / `run_smd_uncleaved.sh` | 命名版由通用版派生: 固定体系 + 参数一致性校验 |
| `cleaved/smd_pull.mdin` / `uncleaved/smd_pull.mdin`(各体系 mdin 模板) | `smd_pull_cleaved.mdin` / `smd_pull_uncleaved.mdin` | 命名模板由体系模板改名而来, 内容一致(仅首行注释注明"由 run_smd.sh 按段覆盖") |

- **为什么保留**: 脚本与 mdin 的演化可追溯(通用 → 命名), 需要时可回退/对照。
- **为什么不用它们跑定量**: 通用版需传体系参数并读目录内 `smd_pull.mdin`;
  命名版体系已写死并做一致性校验, 更适合生产部署。两套语法与参数完全一致, 无行为差异。
