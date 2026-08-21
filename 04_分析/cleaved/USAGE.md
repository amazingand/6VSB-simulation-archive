# 04_分析 / cleaved · USAGE

> 本目录为 **cleaved 体系(切割态)** 的分析脚本与结果。运行平台:用户本地 / 4×4090 工作站
> (需 AmberTools 的 parmed、netCDF4、numpy、matplotlib)。配套:根目录
> `04_分析/PROGRESS.md`(任务与证据边界)、根 `README.md` §三(部署)、根 `NODES.md`。
> 与 uncleaved 镜像同构,脚本/数据各留一份,**不可互换**。

---

## analyze_smd_cleaved_v03.py

- **用途**:解析 SMD(DUMPAVE)输出,输出力–位移 / 拉力–时间 / 做功曲线与关键统计
  (峰力、平滑峰、解离距离、累计功、∫F·dr2 交叉校验)。
- **适用体系**:cleaved 仅(体系固定;从 `smd_cleaved_v02.RST` 起点 r2 反推时间)。
- **输入**:`smd.out`(合并 DUMPAVE;由 `run_smd_cleaved_v03.sh` 分片后自动合并)。
- **输出**:`<out>.dat`(t_ps / r2_target / dist / force / work_cum,5 列);`--plot` 时 `<out>.png`
  (2×2:拉力-时间、力-位移、功-时间、功-位移)。
- **调用方式**:
  ```bash
  python analyze_smd_cleaved_v03.py smd.out --speed 1 --plot --out smd_prod_cleaved_v01   # 定量(证据)
  python analyze_smd_cleaved_v03.py smd.out --speed 5 --plot --out smd_cleaved_v01         # 初筛(非证据)
  ```
- **限制**:段边界 = 累计功精确为 0 的行(v3 修正,各拉速可靠);负力(压缩伪迹)不参与解离统计;
  无 `--speed` 默认 5 Å/ns。
- **已知问题**:中文图需系统含 CJK 字体(脚本自动探测,若无则装 fonts-noto-cjk)。

## analyze_smd_contacts_cleaved_v02.py

- **用途**:轨迹级接触分析(T11 v2)——盐桥演化、S1 尾残基接触矩阵、窗口均力,回答
  `05_对比/机制分析_v01.md` §7 待确认问题(盐桥存活/断裂位置、承力残基、二次抗阻带特征)。
- **适用体系**:cleaved 仅(system 参数固定为 cleaved;默认盐桥对 ASP614:LYS854 + LYS557:ASP839)。
- **输入**:`step3_input.parm7`、`step3_input.pdb`、`smd_cleaved_v02.RST`、`smd_chunk*.nc`(轨迹,
  可部分分片);`--eq4 eq4_npt.rst7`(原生接触参考,可选);`--forces smd.out`(窗均力,可选)。
- **输出**:`<out>_saltbridges.tsv`、`<out>_windows.tsv`、`<out>_residue_contacts.tsv` + 图
  (盐桥演化 / 接触图 / 窗均力,`--no-plot` 关闭)。
- **调用方式**(在 amber/ 目录内):
  ```bash
  python analyze_smd_contacts_cleaved_v02.py --traj "smd_production/smd_chunk*.nc" \
         --forces smd_production/smd.out --eq4 eq4_npt.rst7 --out contacts_cleaved
  ```
- **限制**:接触判据默认重原子 < 4.5 Å、盐桥 O…N < 4.0 Å;S1 尾/S2 头按残基号 540–685/686–1035
  + 蛋白链定位(v2 修复,不依赖段名)。
- **已知问题**:未推的窗口留空(NA),需对应窗口轨迹分片已生成。

## run_replica_cleaved_v01.sh

- **用途**:副本(独立重复)平衡 + SMD 包装器(T12)——每副本注入唯一 `ig` 种子 → 独立平衡末态
  eq4 → cpptraj 按 igr1/igr2 重算新 R0 → 副本专用 RST → 复用 `run_smd_cleaved_v03.sh` 分片生产。
- **适用体系**:cleaved 仅。
- **输入**(在 CHARMM-GUI amber/ 目录内):`step3_input.parm7/.rst7/.pdb`、`dihe.restraint`、
  03 层部署单元(`run_equil_cleaved_v01.sh`、`run_smd_cleaved_v03.sh`、`smd_pull_cleaved_v03.mdin`、
  `smd_cleaved_v02.RST`)。
- **输出**:`amber_r<repN>/` 自含目录(eq4_npt.rst7、smd_chunk*.nc、smd.out)。
- **调用方式**:
  ```bash
  bash run_replica_cleaved_v01.sh 1 --engine=pmemd.cuda --smd-speed 1 --gpu 0
  ```
- **限制**:副本号决定种子 `ig = 712000 + repN`;`amber_rNN/` 已存在会报错防误覆盖;重复运行
  = 新副本号。
- **已知问题**:无。

## launch_all_replicas_cleaved_v01.sh

- **用途**:4×4090 工作站并行启动 N(1–4)个副本,每副本独占一张 GPU。
- **适用体系**:cleaved 仅。
- **输入**:同 run_replica(不接收位置体系参数)。
- **输出**:`amber_r01..rNN/` + 各副本日志 `replica_rNN.log`。
- **调用方式**:
  ```bash
  bash launch_all_replicas_cleaved_v01.sh 4 --engine=pmemd.cuda --smd-speed 1
  ```
- **限制**:N ≤ 4(卡数);完成判定 = 每个 `amber_rNN/` 出现 smd.out 且末段 mdout 含
  `Final Performance Info:`。
- **已知问题**:无。

## replicas_README_cleaved_v01.md

- **用途**:副本方案说明——独立性来源(ig)、新 R0 重算、副本数建议(N≥3)、论文证据用法、工作流。
- **适用体系**:cleaved 仅。
- **输入/输出**:文档,只读。
- **调用方式**:按需查阅。
- **限制**:无。
- **已知问题**:无。

## smd_prod_cleaved_v01.dat / .png

- **用途**:**定量(1 Å/ns)结果 = 论文证据**。力–位移/功–位移曲线数据与 4 联图,由
  `analyze_smd_cleaved_v03.py` 在定量 smd.out 上生成。
- **适用体系**:cleaved 仅。
- **输入**:定量 `smd.out`(--smd-speed 1)。
- **输出**:数据 5 列(t_ps / r2 / dist / force / work);图为 2×2 曲线。
- **调用方式**:表格软件 / 查看器打开;已入 `05_对比/核验报告_v02.md` §2 数字来源。
- **限制**:证据边界——**仅定量数据入论文**;初筛结果见下一组。
- **已知问题**:无。

## smd_cleaved_v01.dat / smd_curves_cleaved_v01.png

- **用途**:**初筛(5 Å/ns)结果 = 非证据**,仅作协议验证与"5 vs 1 拉速排序一致"稳健性对照。
- **适用体系**:cleaved 仅。
- **输入**:初筛 smd.out(--smd-speed 5)。
- **输出**:同 analyze_smd 产物格式。
- **调用方式**:同 smd_prod 组。
- **限制**:快拉偏置 + 开局伪迹,数字**不进入论文证据链**;定量数字以 `smd_prod_cleaved_v01.*` 为准。
- **已知问题**:无。
