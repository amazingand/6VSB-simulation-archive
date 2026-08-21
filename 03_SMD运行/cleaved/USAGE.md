# 03_SMD运行 / cleaved · USAGE

> 本目录为 **cleaved 体系**(S2′ 已切割,R815↓)的 SMD 部署单元与运行证据。
> 运行平台:你的 RTX 4070S + Amber(pmemd.cuda/pmemd);脚本必须在 **amber/ 目录内**执行(从当前目录找 `step3_input.parm7` / `step3_input.rst7` / `dihe.restraint`)。
> 配套:根目录 `README.md`(本地部署指引)、`03_SMD运行/PROGRESS.md`(协议版本史)、`03_SMD运行/协议规划_v01.md`(参数定义与云侧基准)。
> 两段式流程:平衡段(`run_equil_cleaved_v01.sh`)→ 同步 GitHub + 云侧核验 → SMD 生产(`run_smd_cleaved_v03.sh`)。**SMD 生产绝不跳过快验直接开跑。**

---

## run_equil_cleaved_v01.sh

- **用途**:cleaved 体系平衡段——对齐极小化 + EQ1–EQ4 阶梯平衡(到 EQ4 停,作 SMD 生产起点);加 `--eq5` 顺带跑 EQ5 稳定性检验(对照用)。
- **适用体系**:cleaved(无体系参数,复制到 cleaved 的 amber/ 目录执行)。
- **输入**(均在当前目录):`step3_input.parm7`/`step3_input.rst7`(CHARMM-GUI 产物)、`dihe.restraint`(糖二面角约束,脚本自动转 `dihe_FC1.rest`)、`align_min_cleaved_v01.mdin`、`eq1_nvt_cleaved_v01.mdin`–`eq5_npt_cleaved_v01.mdin`。
- **输出**:`align_min.rst7/.mdout`(5000 步)、`eq1_nvt.rst7/.nc`(NVT 100 ps)、`eq2_npt.rst7/.nc`(NPT 200 ps)、`eq3_npt.rst7/.nc`(NPT 200 ps)、`eq4_npt.rst7/.nc`(NPT 自由平衡 500 ps,← SMD 起点)。
- **调用方式**:
  ```bash
  bash /绝对路径/03_SMD运行/cleaved/run_equil_cleaved_v01.sh            # 或复制到 amber/ 后本地执行
  bash run_equil_cleaved_v01.sh --eq5                                     # 附加 EQ5 稳定性检验
  ```
- **限制**:必须在 amber/ 目录内运行;cleaved 与 uncleaved 各用各的部署单元,不可混用。
- **已知问题**:EQ 中途断掉则重跑从头开始(脚本线性),想补跑只补中断后的阶段;极小化初能量 7.67E12 是正常的(S2′ 切割末端原子重叠),几百步内降回 −9E5 量级,跑完仍 >1E10 则停下检查。

## run_smd_cleaved_v03.sh

- **用途**:cleaved 体系 SMD 生产(机械力驱动 S1/S2 解离),分片可重启——每段 1 ns、段间自动接续,断点续跑、换参数自动重跑旧段。
- **适用体系**:cleaved。
- **输入**(当前目录):`eq4_npt.rst7`(平衡终点,自动找)、`smd_pull_cleaved_v03.mdin`、`smd_cleaved_v02.RST`(反应坐标,`r2`=起点 R0=28.28、`r4`=终点 RF=55.0)。
- **输出**:`smd_chunkNN.out/.mdout/.rst7`(每段)+ 跑完合并 `smd.out`(DUMPAVE 拉力/功)+ `smd_quant.log`(重定向日志)。
- **调用方式**:
  ```bash
  nohup bash run_smd_cleaved_v03.sh --smd-speed 1 --engine=pmemd.cuda > smd_quant.log 2>&1 &
  # 初筛(核验用,非论文证据)用 --smd-speed 5;定量(证据)用 --smd-speed 1
  ```
- **限制**:仅在云侧核验通过后执行;R0/RF 从 `smd_cleaved_v02.RST` 读,改它就改全局,脚本自动重算段数;时长(4070S)定量约 5–8 h,务必 `nohup`/`screen` 挂后台,跑完再启 uncleaved。
- **已知问题**:漏 `--smd-speed 1` 会默认 5 Å/ns(非证据参数);某段被杀(NSTEP < 500000 且无 `Final Performance Info:`)时脚本自动删该段从上一完整段重跑,无需手动清理。

## smd_pull_cleaved_v03.mdin

- **用途**:SMD 生产段的 Amber mdin 模板(与 `smd_cleaved_v02.RST` 配对,`DISANG=smd_cleaved_v02.RST`);定义 nmropt 移动距离约束、DUMPAVE 记录与分片参数。
- **适用体系**:cleaved。
- **输入**:被 `run_smd_cleaved_v03.sh` 引用;约束原子来自构型 PDB(S1 尾 144 Cα ↔ S2 头 200 Cα)。
- **输出**:SMD 段产物(见 run_smd 条目)。
- **调用方式**:不经手调用,由 `run_smd_cleaved_v03.sh` 读取。
- **限制**:版本史 v3 = P2 → P3 DUMPFREQ → P4.1 引用改名;改 RST 文件名必须同步改本文件 `DISANG` 行。
- **已知问题**:无。

## smd_cleaved_v02.RST

- **用途**:SMD 反应坐标(距离约束)文件——cleaved 定量参数 `R0=28.28 → RF=55.0 Å, 1 Å/ns, 26.72 ns, 27 段`,力常数 `rk2=7.2 kcal/mol/Å²`。
- **适用体系**:cleaved。
- **输入**:由 `run_smd_cleaved_v03.sh` / `smd_pull_cleaved_v03.mdin` 引用。
- **输出**:无独立输出。
- **调用方式**:不直接调用。
- **限制**:v2 = P4 按体系实测平衡距离修订(R0 由 28.80 改为 28.28);与 uncleaved 的 RST(R0=31.27)**不可互换**。
- **已知问题**:改数值后必须确认脚本引用一致(P4.1 命名纪律)。

## align_min_cleaved_v01.mdin

- **用途**:对齐极小化(5000 步),消除 S2′ 切割末端原子重叠等高能接触。
- **适用体系**:cleaved。
- **输入**:`step3_input.rst7`;被 `run_equil_cleaved_v01.sh` 第一步调用。
- **输出**:`align_min.rst7` / `align_min.mdout`。
- **调用方式**:由 run_equil 脚本调用;也可单独 `pmemd -O -i align_min_cleaved_v01.mdin ...`。
- **限制**:pmemd/pmemd.cuda 标准格式(约束块以 `&end` 结尾);**不要用 sander** 跑(见下)。
- **已知问题**:sander 有已知缺陷需移除 `&end`,本 mdin 是标准格式,用 sander 会报 `Error decoding variable from: Protein`——这是 sander 特例,不是标准。

## eq1_nvt_cleaved_v01.mdin … eq5_npt_cleaved_v01.mdin(5 个)

- **用途**:阶梯平衡(EQ1 NVT 100 ps 加热 → EQ2/EQ3 NPT 各 200 ps 压实 → EQ4 NPT 自由平衡 500 ps → EQ5 NPT 稳定性检验,糖二面角约束全程)。
- **适用体系**:cleaved。
- **输入**:上一阶段 `eq*_npt/nvt.rst7`;由 `run_equil_cleaved_v01.sh` 按序调用。
- **输出**:`eq1_nvt.rst7/.nc` … `eq4_npt.rst7/.nc`(及 `--eq5` 时 `eq5_npt.rst7/.nc`)。
- **调用方式**:由 run_equil 脚本调用。
- **限制**:EQ 阶段互不覆盖;某阶段失败可从该阶段补跑。
- **已知问题**:mdin 被改坏会报 `NTB set but no NTP`——重拷一份部署单元 mdin。

## 证据/align_min_cleaved_v01.mdout

- **用途**:云侧能量轨迹对齐核验的基准 mdout(cleaved 初筛证据)——前 100 步能量轨迹应落在云侧基准曲线附近,最终能量落在 **−9.8E5 ~ −9.9E5**(kcal/mol)。
- **适用体系**:cleaved(原 `analysis/evidence/` 中经确认属 cleaved 体系)。
- **输入/输出**:只读证据文件,不参与运行。
- **调用方式**:与本地新跑 `align_min.mdout` 对比。
- **限制**:仅供核验比对;浮点实现差异(sander vs pmemd.cuda)允许最后 1–2 位小数偏差,看趋势与前 5–6 位有效数字。
- **已知问题**:无。

## 证据/smd_pull_cleaved_v01.mdout

- **用途**:SMD 初筛核验的基准 mdout(cleaved),记录初筛拉动力–位移过程。
- **适用体系**:cleaved。
- **输入/输出**:只读证据文件。
- **调用方式**:不调用;供核验比对与论文证据链引用。
- **限制**:初筛参数(5 Å/ns)非论文证据参数;定量证据以 `smd.out`(--smd-speed 1)为准。
- **已知问题**:无。
