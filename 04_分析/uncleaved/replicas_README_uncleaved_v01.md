# 副本 SMD 运行包(4×4090 工作站)

针对**单轨迹限制**的副本方案:在 4×4090 上独立重复平衡 + SMD,为论文提供
error-bar/统计稳健性,并支持轨迹级机制归因的跨副本确认。

## 1. 副本是什么

| 项 | 说明 |
|---|---|
| 独立源 | 每副本给平衡链(EQ1–EQ4)注入**唯一随机种子 `ig`** → 不同初速度 + 不同 Langevin 噪声 → 独立平衡轨迹 → 独立平衡末态 eq4 |
| 反应坐标 | 与主副本**完全同一原子组**(igr1=144 Cα / igr2=200 Cα, 从参考 RST 提取) |
| 新 R0 | 每副本用 cpptraj 按 igr 掩码重算 eq4 的 COM 距离(已验证与 pmemd DUMPAVE 值一致, 云侧 28.279/31.274) |
| 副本 RST | 只改起点 `r2 = r3 = 新R0`, 终点 r4=55.0、rk2/rk3=7.2、igr 列表**字面不动** |
| SMD | 复用 `run_smd_uncleaved_v03.sh`(从 RST 读 R0/RF, 分片可重启), 模板已注入本副本 ig(Langevin 噪声流) |
| 产出 | 每副本 `amber_rNN/` 自含: eq4_npt.rst7、smd_chunk*.nc、smd.out |

**为什么用 `ig` 而不是 `igseed`**:`ig` 是 Amber 手册标准随机种子变量(sander 与
pmemd 都支持,已用对照实验验证:不同 `ig` → 不同初速度 → 独立轨迹;同 `ig` →
确定性可复现)。`igseed` 是 pmemd 的附加种子,但 sander 无法解析(实测报
`error in reading namelist cntrl`),且本方案用 `ig` 即可完全实现副本独立性,故
不引入第二种子变量,保持平衡链引擎无关、语法最简。

## 2. 用法

```bash
# 在 CHARMM-GUI amber/ 目录内(与 run_equil_uncleaved_v01.sh / run_smd_uncleaved_v03.sh 同处):

# 单副本(手动控制)
bash run_replica_uncleaved_v01.sh 1 --engine=pmemd.cuda --smd-speed 1 --gpu 0

# 4 卡并行 4 副本(推荐)
bash launch_all_replicas_uncleaved_v01.sh 4 --engine=pmemd.cuda --smd-speed 1

# 跟踪
tail -f replica_r01.log          # 各副本独立日志 replica_rNN.log
```

- `--smd-speed 1` = 定量(证据);`5` = 初筛。**论文证据只用 1 Å/ns**。
- `--gpu N` 设 `CUDA_VISIBLE_DEVICES=N`,副本独占一张卡。
- 副本号决定种子:`cleaved` 用 `ig = 712000+N`,`uncleaved` 用 `ig = 723000+N`
  (唯一、可复现;改种子 = 换副本,不要复用已用过的副本号)。
- 重复运行 = 新副本号;`amber_rNN/` 已存在会报错(防止误覆盖)。

## 3. 副本数建议与证据用法

- **最少 2,建议 3–4**:功/峰力/主释放距离给出均值和范围;机制图(接触归因)用
  各副本一致出现的残基做主结论,单副本特有接触标注为暂定。
- 论文中:主副本(已核验)为基线,副本作为 `N≥3 的均值±范围`;若副本间机制
  定性不一致 → 是重要发现,写进讨论,而非掩盖。
- 分析入口:`analyze_smd_uncleaved_v03.py smd.out --speed 1 --plot`(每副本单独跑);
  轨迹级接触分析用 `analyze_smd_contacts_uncleaved_v02.py`(见分析脚本说明)。

## 4. 工作流

1. 用户本地/工作站跑副本(SMD 完成前别推 GitHub,避免 LFS 半成品指针)。
2. 全部完成后,把 `amber_rNN/smd.out` 与关键窗口 `smd_chunk*.nc` 推仓库
   `simulations/construct-X/<sys>/charmm-gui-*/amber/` 下的 `replicas/` 子目录。
3. 云侧拉取 → 复核 → 更新核验报告(副本一致性)。

## 5. 文件清单

| 文件 | 作用 |
|---|---|
| `run_replica_uncleaved_v01.sh` | 副本包装器(ig 注入 → 平衡 → cpptraj 重算 R0 → 副本 RST → SMD) |
| `launch_all_replicas_uncleaved_v01.sh` | 4 卡并行启动器 |
| `smd_uncleaved_v02.RST`(副本目录内) | 副本反应坐标(新 R0, 其余字面与参考一致) |
