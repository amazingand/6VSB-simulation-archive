# 03_SMD运行 / uncleaved · USAGE

> 本目录为 **uncleaved 体系**(S2′ 未切割)的 SMD 部署单元。与 cleaved 镜像同构,**文件与参数不可混用**。
> 运行平台:你的 RTX 4070S + Amber(pmemd.cuda/pmemd);脚本必须在 **amber/ 目录内**执行。
> 配套:根目录 `README.md`(本地部署指引)、`03_SMD运行/PROGRESS.md`(协议版本史)、`03_SMD运行/协议规划_v01.md`(参数定义与云侧基准)。
> 两段式流程:平衡段(`run_equil_uncleaved_v01.sh`)→ 同步 GitHub + 云侧核验 → SMD 生产(`run_smd_uncleaved_v03.sh`)。**SMD 生产绝不跳过快验直接开跑。**

---

## run_equil_uncleaved_v01.sh

- **用途**:uncleaved 体系平衡段——对齐极小化 + EQ1–EQ4 阶梯平衡;加 `--eq5` 顺带跑 EQ5 稳定性检验。
- **适用体系**:uncleaved(无体系参数,复制到 uncleaved 的 amber/ 目录执行)。
- **输入**(均在当前目录):`step3_input.parm7`/`step3_input.rst7`、`dihe.restraint`、`align_min_uncleaved_v01.mdin`、`eq1_nvt_uncleaved_v01.mdin`–`eq5_npt_uncleaved_v01.mdin`。
- **输出**:`align_min.rst7/.mdout`、`eq1_nvt.rst7/.nc`(NVT 100 ps)、`eq2_npt.rst7/.nc`、`eq3_npt.rst7/.nc`、`eq4_npt.rst7/.nc`(NPT 自由平衡 500 ps,← SMD 起点)。
- **调用方式**:
  ```bash
  bash /绝对路径/03_SMD运行/uncleaved/run_equil_uncleaved_v01.sh
  bash run_equil_uncleaved_v01.sh --eq5
  ```
- **限制**:必须在 amber/ 目录内运行;cleaved 与 uncleaved 各用各的部署单元,不可混用。
- **已知问题**:EQ 中途断掉则重跑从头开始;极小化初能量约 −9.08E5 起、终值落 −9.69E5 附近(与 cleaved 不同,见协议规划 §5)。

## run_smd_uncleaved_v03.sh

- **用途**:uncleaved 体系 SMD 生产,分片可重启(每段 1 ns、段间自动接续)。
- **适用体系**:uncleaved。
- **输入**(当前目录):`eq4_npt.rst7`、`smd_pull_uncleaved_v03.mdin`、`smd_uncleaved_v02.RST`(`r2`=R0=31.27、`r4`=RF=55.0)。
- **输出**:`smd_chunkNN.out/.mdout/.rst7` + 合并 `smd.out` + `smd_quant.log`。
- **调用方式**:
  ```bash
  nohup bash run_smd_uncleaved_v03.sh --smd-speed 1 --engine=pmemd.cuda > smd_quant.log 2>&1 &
  ```
- **限制**:仅在云侧核验通过后执行;定量参数 **R0=31.27 → 55.0 Å, 1 Å/ns, 23.73 ns, 24 段**;时长约 5–8 h,挂后台跑完再启下一个。
- **已知问题**:漏 `--smd-speed 1` 会默认 5 Å/ns;断段自动从上一完整段重跑。

## smd_pull_uncleaved_v03.mdin

- **用途**:SMD 生产段 mdin 模板(`DISANG=smd_uncleaved_v02.RST`);定义 nmropt 移动距离约束、DUMPAVE 与分片参数。
- **适用体系**:uncleaved。
- **输入**:被 `run_smd_uncleaved_v03.sh` 引用;约束原子同 cleaved(S1 尾 144 Cα ↔ S2 头 200 Cα)。
- **输出**:SMD 段产物。
- **调用方式**:不经手调用,由 run_smd 脚本读取。
- **限制**:v3 = P2 → P3 DUMPFREQ → P4.1 引用改名;改 RST 名必须同步改本文件 `DISANG` 行。
- **已知问题**:无。

## smd_uncleaved_v02.RST

- **用途**:SMD 反应坐标(距离约束)文件——uncleaved 定量参数 `R0=31.27 → RF=55.0 Å, 1 Å/ns, 23.73 ns, 24 段`,`rk2=7.2 kcal/mol/Å²`。
- **适用体系**:uncleaved。
- **输入**:由 `run_smd_uncleaved_v03.sh` / `smd_pull_uncleaved_v03.mdin` 引用。
- **输出**:无独立输出。
- **调用方式**:不直接调用。
- **限制**:v2 = P4 按体系实测平衡距离修订(R0=31.27);与 cleaved 的 RST(R0=28.28)**不可互换**。
- **已知问题**:改数值后必须确认脚本引用一致(P4.1 命名纪律)。

## align_min_uncleaved_v01.mdin

- **用途**:对齐极小化(5000 步),消除初始高能接触。
- **适用体系**:uncleaved。
- **输入**:`step3_input.rst7`;被 `run_equil_uncleaved_v01.sh` 第一步调用。
- **输出**:`align_min.rst7` / `align_min.mdout`。
- **调用方式**:由 run_equil 脚本调用。
- **限制**:pmemd/pmemd.cuda 标准格式(约束块以 `&end` 结尾);**不要用 sander 跑**(sander 需移除 `&end` 是它自己的缺陷,非标准)。
- **已知问题**:sander 会报 `Error decoding variable from: Protein`;用 pmemd/pmemd.cuda 正常。

## eq1_nvt_uncleaved_v01.mdin … eq5_npt_uncleaved_v01.mdin(5 个)

- **用途**:阶梯平衡(EQ1 NVT 100 ps → EQ2/EQ3 NPT 各 200 ps → EQ4 NPT 自由平衡 500 ps → EQ5 稳定性检验,糖二面角约束全程)。
- **适用体系**:uncleaved。
- **输入**:上一阶段 `eq*.rst7`;由 `run_equil_uncleaved_v01.sh` 按序调用。
- **输出**:`eq1_nvt.rst7/.nc` … `eq4_npt.rst7/.nc`(及 `--eq5` 时 `eq5_npt.rst7/.nc`)。
- **调用方式**:由 run_equil 脚本调用。
- **限制**:EQ 阶段互不覆盖;某阶段失败可从该阶段补跑。
- **已知问题**:mdin 改坏会报 `NTB set but no NTP`——重拷部署单元 mdin。
