# 04_分析 / uncleaved · USAGE

> 本目录为 **uncleaved 体系(未切割态)** 的分析脚本与结果。与 cleaved 镜像同构,**脚本/数据各留
> 一份,不可互换**(差异:默认盐桥对仅 ASP614:LYS854、默认窗口、ig 种子基准 723000、R0=31.27)。
> 配套:根目录 `04_分析/PROGRESS.md`、根 `README.md` §三、根 `NODES.md`。

---

## analyze_smd_uncleaved_v03.py

- **用途**:解析 SMD(DUMPAVE)输出,输出力–位移 / 拉力–时间 / 做功曲线与关键统计。
- **适用体系**:uncleaved 仅(从 `smd_uncleaved_v02.RST` 起点 r2 反推时间)。
- **输入**:`smd.out`(合并 DUMPAVE)。
- **输出**:`<out>.dat`(5 列: t_ps / r2_target / dist / force / work_cum);`--plot` 时 `<out>.png`(2×2)。
- **调用方式**:
  ```bash
  python analyze_smd_uncleaved_v03.py smd.out --speed 1 --plot --out smd_prod_uncleaved_v01  # 定量(证据)
  python analyze_smd_uncleaved_v03.py smd.out --speed 5 --plot --out smd_uncleaved_v01        # 初筛(非证据)
  ```
- **限制**:段边界 = 累计功精确为 0 的行;负力(压缩伪迹)不参与解离统计;无 `--speed` 默认 5。
- **已知问题**:中文图需 CJK 字体(自动探测)。

## analyze_smd_contacts_uncleaved_v02.py

- **用途**:轨迹级接触分析(T11 v2)。uncleaved 为**单一主导势垒**(37.5–42.5 Å),重点确认
  ASP614–LYS854 存活/断裂位置与承力残基;无 cleaved 的 LYS557–ASP839(FP 内)锚。
- **适用体系**:uncleaved 仅(system 参数固定为 uncleaved;默认盐桥对仅 **ASP614:LYS854**)。
- **输入**:`step3_input.parm7`、`step3_input.pdb`、`smd_uncleaved_v02.RST`、`smd_chunk*.nc`(可部分
  分片);`--eq4 eq4_npt.rst7`、`--forces smd.out`(均可选)。
- **输出**:`<out>_saltbridges.tsv`、`<out>_windows.tsv`、`<out>_residue_contacts.tsv` + 图(盐桥
  演化 / 接触图 / 窗均力,`--no-plot` 关闭)。
- **调用方式**(在 amber/ 目录内):
  ```bash
  python analyze_smd_contacts_uncleaved_v02.py --traj "smd_production/smd_chunk*.nc" \
         --forces smd_production/smd.out --eq4 eq4_npt.rst7 \
         --windows 31.3-37.5,37.5-42.5,42.5-45,45-55 --out contacts_uncleaved
  ```
- **限制**:接触 < 4.5 Å、盐桥 O…N < 4.0 Å;S1 尾/S2 头按残基号定位(v2 修复 uncleaved 崩溃)。
- **已知问题**:未推窗口留空(NA)。

## run_replica_uncleaved_v01.sh

- **用途**:副本(独立重复)平衡 + SMD 包装器(T12)——ig 种子 → 独立 eq4 → cpptraj 重算 R0 →
  副本 RST → `run_smd_uncleaved_v03.sh` 分片生产。
- **适用体系**:uncleaved 仅。
- **输入**(在 CHARMM-GUI amber/ 目录内):`step3_input.parm7/.rst7/.pdb`、`dihe.restraint`、
  03 层部署单元(`run_equil_uncleaved_v01.sh`、`run_smd_uncleaved_v03.sh`、`smd_pull_uncleaved_v03.mdin`、
  `smd_uncleaved_v02.RST`)。
- **输出**:`amber_r<repN>/` 自含目录(eq4_npt.rst7、smd_chunk*.nc、smd.out)。
- **调用方式**:
  ```bash
  bash run_replica_uncleaved_v01.sh 1 --engine=pmemd.cuda --smd-speed 1 --gpu 0
  ```
- **限制**:副本号决定种子 **`ig = 723000 + repN`**(与 cleaved 基准 712000 不同);
  `amber_rNN/` 已存在会报错防误覆盖。
- **已知问题**:无。

## launch_all_replicas_uncleaved_v01.sh

- **用途**:4×4090 工作站并行启动 N(1–4)个副本,每副本独占一张 GPU。
- **适用体系**:uncleaved 仅。
- **输入**:同 run_replica(不接收位置体系参数)。
- **输出**:`amber_r01..rNN/` + 日志 `replica_rNN.log`。
- **调用方式**:
  ```bash
  bash launch_all_replicas_uncleaved_v01.sh 4 --engine=pmemd.cuda --smd-speed 1
  ```
- **限制**:N ≤ 4;完成判定 = 每个 `amber_rNN/` 出现 smd.out 且末段 mdout 含
  `Final Performance Info:`。
- **已知问题**:无。

## replicas_README_uncleaved_v01.md

- **用途**:副本方案说明(ig 独立性、新 R0 重算、N≥3 建议、论文证据用法、工作流)。
- **适用体系**:uncleaved 仅。
- **输入/输出**:文档,只读。
- **调用方式**:按需查阅。
- **限制**:无。
- **已知问题**:无。

## smd_prod_uncleaved_v01.dat / .png

- **用途**:**定量(1 Å/ns)结果 = 论文证据**。uncleaved R0=31.27 → 55.0 Å、23.73 ns、24 段;
  峰力 1331 pN @ 40.28 Å、总功 65.22 kcal/mol(见 `05_对比/核验报告_v02.md`)。
- **适用体系**:uncleaved 仅。
- **输入**:定量 `smd.out`(--smd-speed 1)。
- **输出**:数据 5 列;2×2 曲线图。
- **调用方式**:表格软件 / 查看器打开。
- **限制**:仅定量数据入论文;初筛见下一组。
- **已知问题**:无。

## smd_uncleaved_v01.dat / smd_curves_uncleaved_v01.png

- **用途**:**初筛(5 Å/ns)结果 = 非证据**;uncleaved 初筛存在开局弹簧压缩伪迹(R0 曾为 28.80,
  非平衡 31.27),数字仅作 5 vs 1 拉速排序对照。
- **适用体系**:uncleaved 仅。
- **输入**:初筛 smd.out(--smd-speed 5)。
- **输出**:同 analyze_smd 产物格式。
- **调用方式**:同 smd_prod 组。
- **限制**:非论文证据;定量数字以 `smd_prod_uncleaved_v01.*` 为准。
- **已知问题**:无。
