# 项目 C′ — 力驱动 S1/S2 解离 → 融合肽释放(SARS-CoV-2 棘突)

> **一句话**:用全原子 steered MD(SMD)把 2023 论文(Yu et al., *RSC Adv.* 2023, 13, 16970)
> 的"静态剪切 S1 剥离"升级为**真实力学过程**,定量 furin 切割(685–686)对 S1/S2 解离的
> 力学代价,并追踪融合肽(FP)何时解除遮蔽。
>
> **状态速览**:定量 SMD(1 Å/ns)两体系全部跑完并核验通过——uncleaved 比 cleaved 更难剥离
> (总功 +31%、峰力 +38%、主释放推迟 ~10 Å),与 2023 静态剪切结论一致;论文骨架 v01 已成型,
> 待用户本地跑轨迹级接触分析(T11 v2)与副本集合(T12)后回填论文 [A][B]。详见
> [`PROGRESS.md`](PROGRESS.md)(总进度 + 参数单一事实源)与 [`NODES.md`](NODES.md)(节点/简称唯一释义)。

---

## 一、目录结构(论文逻辑主轴)

```
workspace/
├── README.md  NODES.md  PROGRESS.md   ← 顶层状态文件(持续追加,不挂 _vNN)
├── scripts/pack_migration.sh          ← 迁移包按需生成工具(排除 history/)
├── 01_研究问题/   ← ① 为什么做:背景综述 + 立项 + 核心预言
├── 02_体系/       ← ② 做什么:构型 X(cleaved/uncleaved PDB)+ 构建说明 + 自检报告
├── 03_SMD运行/    ← ③ 怎么做:协议规划 + 部署单元(两段式平衡/SMD)+ 核验证据
├── 04_分析/       ← ④ 结论从哪来:分析脚本 + 结果(体系严格隔离,各留一份)
├── 05_对比/       ← ⑤ 汇合点(唯一合法双体系汇合节点):核验报告 + 机制分析 + 论文用图
├── 06_论文/       ← ⑥ 出论文:结论摘要 + 论文进度 + 图表冻结副本
└── history/       ← 只读历史区(P1–P5 快照),不参与工作流与迁移包
```

论文主稿本体在 **`.paper` 工作台**(`papers/spike-force-dissociation/`,平台托管),不在本
workspace 内;`06_论文/` 只放结论摘要、进度跟踪与图表冻结副本。

### 各层职责

| 层 | 职责 | 关键文件 |
|---|---|---|
| 01_研究问题 | 立论、预言、设计决策史 | `背景与预言_v01.md`(M0 综述 + M1 立项)、`参考文献/` |
| 02_体系 | 构型 X 结构与自检 | `cleaved|uncleaved/construct_X_{sys}_v01.pdb`、`构建说明_v01.md`、`自检报告_v01.md` |
| 03_SMD运行 | 协议 + 可执行部署单元 + 核验证据 | `{cleaved,uncleaved}/run_equil_{sys}_v01.sh`、`run_smd_{sys}_v03.sh`、`smd_{sys}_v02.RST`、`协议规划_v01.md` |
| 04_分析 | 分析脚本 + 结果 | `{cleaved,uncleaved}/analyze_smd_{sys}_v03.py`、`analyze_smd_contacts_{sys}_v02.py`、`run_replica_{sys}_v01.sh`、`smd_prod_{sys}_v01.dat/png` |
| 05_对比 | 双体系结论与论文用图 | `核验报告_v02.md`、`机制分析_v01.md`、`plots/smd_prod_comparison_v01.png`、`smd_prod_barrier_architecture_v01.png` |
| 06_论文 | 论文状态 + 摘要 + 图表副本 | `结论摘要_v01.md`、`图表/`(预留) |

---

## 二、命名规则与隔离边界(全项目硬约束)

1. **顶层状态文件不挂 `_vNN`**:`README.md` / `NODES.md` / 各层 `PROGRESS.md` / 各层
   `USAGE.md` 持续追加更新;`vNN` 只用于科研产物(脚本 / mdin / RST / PDB / 数据 / 报告 / 图表)。
2. **科研产物命名**:`<逻辑名>_<体系>_<vNN>.<ext>`,体系名 `cleaved` / `uncleaved` **始终嵌入**;
   每次实质修改版本号 +1,禁止覆盖旧版本(旧版进 `history/`)。
3. **01–04 无体系共享执行文件**:字节级相同也分体系各留一份(`04_分析/{cleaved,uncleaved}/`);
   阶段根目录只允许双体系综合文档(报告 / PROGRESS / 说明),**执行文件必须进体系目录**。
4. **05_对比 是唯一合法双体系汇合节点**;`history/` 永久只读,不移动 / 不重命名 / 不更新 /
   不参与迁移包。
5. **交叉引用同步纪律**:mdin 的 `DISANG` 行、脚本引用的 mdin/RST 名若迁移/改名,必须同步
   改成带版本的新名(如 `DISANG=smd_cleaved_v02.RST`),迁移后跑一致性检查确认零悬空引用。
6. **USAGE 粒度**:每个目录的 `USAGE.md` 按文件逐一建条目(用途/适用体系/输入/输出/调用方式/
   限制/已知问题)。

---

## 三、本地部署与快速使用(Amber,RTX 4070S)

脚本必须在 **`amber/` 目录内**执行(从当前目录找 `step3_input.parm7` 等 CHARMM-GUI 产物);
拓扑/力场/坐标由 CHARMM-GUI 包提供,不随本工作区交付。

### 1. 引擎选择

优先级:`--engine=引擎` > 环境变量 `$PMEMD_ENGINE` > 自动探测(`pmemd.cuda` → `pmemd` → `sander`)。
支持的引擎:`pmemd.cuda`(GPU,生产) / `pmemd`(CPU) / `sander`(仅核验)。

- **WSL 注意**:自动探测到 WSL 时,默认回退 CPU 版 `pmemd`;若已配好 NVIDIA WSL 驱动,
  显式加 `--engine=pmemd.cuda` 启用 GPU。
- **Amber 版本**:COM 距离约束(`iat=-1,-1`)自 AMBER 18 update.7 起被 `pmemd.cuda` 支持,
  本协议标准格式(约束块以 `&end` 结尾)适用 pmemd/pmemd.cuda;**不要用 sander 跑生产**
  (sander 需移除 `&end` 是它自身的缺陷,非标准写法)。

### 2. 前置文件(CHARMM-GUI 产物,在 amber/ 内)

`step3_input.parm7` / `step3_input.rst7` / `step3_input.pdb` / `dihe.restraint`(糖二面角约束)。
另需本工作区 `03_SMD运行/{cleaved,uncleaved}/` 下的部署单元。

### 3. 两段式流程(平衡 → 核验 → SMD 生产)

```bash
# —— 段 1:平衡(cleaved 示例;uncleaved 换成对应名字)——
#   把 03_SMD运行/cleaved/ 的文件拷入 amber/ 目录后:
bash run_equil_cleaved_v01.sh                # 对齐极小化 + EQ1–EQ4,平衡至 EQ4 停
#   记下 align_min.mdout 最终能量,同步 GitHub + 云侧核验(前 100 步能量轨迹对齐)

# —— 段 2:SMD 生产(仅在云侧核验通过后执行)—— ——
nohup bash run_smd_cleaved_v03.sh --smd-speed 1 --engine=pmemd.cuda > smd_quant.log 2>&1 &
#   定量(证据)必须 --smd-speed 1;初筛核验用 --smd-speed 5(非论文证据)
#   挂后台跑完(约 5–8 h)再启 uncleaved;脚本分片可重启、断点自动续跑

# —— 段 3:分析 ——
python analyze_smd_cleaved_v03.py smd.out --speed 1 --plot     # 力–位移 / 累计功
python analyze_smd_contacts_cleaved_v02.py --traj "smd_production/smd_chunk*.nc" \
       --forces smd_production/smd.out --eq4 eq4_npt.rst7      # 轨迹级接触演化(T11)
# 副本集合(4×4090 工作站):bash launch_all_replicas_cleaved_v01.sh 4 --engine=pmemd.cuda --smd-speed 1
```

### 4. 参数速查(单一事实源,勿改;完整表见 `PROGRESS.md`)

| 参数 | cleaved | uncleaved |
|---|---|---|
| 反应坐标 | S1 尾 144 Cα ↔ S2 头 200 Cα COM 距离(jar=1,iat=-1,-1) | 同左 |
| R0 → RF | **28.28 → 55.0 Å** | **31.27 → 55.0 Å** |
| 定量拉速 / 时长 / 段数 | **1 Å/ns / 26.72 ns / 27 段** | **1 Å/ns / 23.73 ns / 24 段** |
| 力常数 rk2 | 7.2 kcal/mol/Å² | 同左 |
| 蛋白 posres(ntr) | `RES 1 151 152 371`(S1 尾自由) | `RES 1 371`(S1 尾自由) |
| 恒温恒压 | 310.15 K / 1 bar,NPT,Langevin γ=1.0 | 同左 |
| 平衡段 | align_min(5000 步)→ EQ1 NVT 100 ps → EQ2/EQ3 NPT 200 ps → EQ4 NPT 500 ps(→ EQ5 检验,可选) | 同左 |

> **证据边界**:初筛(5 Å/ns)只作协议验证与 5 vs 1 拉速稳健性对照,**非论文证据**;
> 论文全部数字来自定量(1 Å/ns),段边界用"DUMPAVE 功精确为 0 的行"(analyze_smd v3)确认。

---

## 四、历史与边界

- **`history/`**(P1–P5 快照 + 文档旧版):只读历史证据,不参与工作流;打包迁移时排除。
- **迁移包**:按需生成,工具 `scripts/pack_migration.sh`(只含当前工作体系,排除 `history/`),
  平时不常驻线上。
- **节点与简称**:M0–M6 / 模式 M1–M3 / T11–T14 / 构型 X·Y / P1–P5 协议史 → 见 [`NODES.md`](NODES.md)。

## 五、仓库结构与迁移追溯

- 终版目录边界：[`FINAL_STRUCTURE.md`](FINAL_STRUCTURE.md)
- 重构状态与核验结论：[`MIGRATION_STATUS.md`](MIGRATION_STATUS.md)
- 旧路径退出最新树的去向：[`docs/repository-history/LEGACY_TREE_REMOVAL_MAP.tsv`](docs/repository-history/LEGACY_TREE_REMOVAL_MAP.tsv)
- 历史快照：[`history/`](history/)
