# 04_分析 · PROGRESS(持续追加)

> 本层 = M5 分析脚本 + 结果。顶层状态文件,不挂 `_vNN`。
> 本层吸收原《Cprime_接触分析+副本包_20260817_说明.md》内容(T11/T12 交付说明)。
> 体系严格隔离:脚本字节级相同也各留一份(cleaved/ / uncleaved/)。

## 一、分析任务与状态

| 任务 | 脚本 | 状态 | 说明 |
|---|---|---|---|
| 定量力–位移/功曲线 | `analyze_smd_{sys}_v03.py` | ✅ 已完成 | v3 = P5 功拼接修正(段界 = 功精确为 0);已产出 `smd_prod_{sys}_v01.dat/png` |
| 初筛曲线(非证据) | 同脚本 `--speed 5` | ✅ 已完成 | `smd_{sys}_v01.dat` + `smd_curves_{sys}_v01.png`,仅作对照 |
| T11 轨迹级接触分析 | `analyze_smd_contacts_{sys}_v02.py` | ⏳ **用户本地待跑** | v2 修复 uncleaved 链命名崩溃(按残基号 540–685/686–1035 + 蛋白链定位,不依赖段名) |
| T12 副本集合 N≥3 | `run_replica_{sys}_v01.sh` / `launch_all_replicas_{sys}_v01.sh` | ⏳ **4×4090 工作站** | 为论文提供均值±范围与跨副本机制确认 |

## 二、结果摘要与证据边界

**证据边界(防污染纪律)**:
- **定量(1 Å/ns)= 论文证据**:`smd_prod_{sys}_v01.dat/png`。段边界由 analyze_smd v3 用
  DUMPAVE 功重置标记确认;∫F·dr2 交叉校验差 0.6%(cleaved)/1.2%(uncleaved)。
- **初筛(5 Å/ns)= 非证据**:`smd_{sys}_v01.dat`、`smd_curves_{sys}_v01.png`,只用于协议验证与
  "5 vs 1 拉速排序一致"一句稳健性表述。

**定量关键数字**(完整表见根 `PROGRESS.md` §四):cleaved 峰力 960 pN @ 30.78 Å、总功 49.73
kcal/mol;uncleaved 1331 pN @ 40.28 Å、总功 65.22 kcal/mol。

## 三、T11 接触分析要点(交付用户本地)

- 输入与 M3 生产一致(prmtop / step3_input.pdb / `smd_{sys}_v02.RST` / `smd_chunk*.nc`),部分
  分片即可运行(按 COM 距离自动分窗,未推的窗口留空)。
- 产出:`*_saltbridges.tsv`、`*_windows.tsv`、`*_residue_contacts.tsv` + 3 张图
  (盐桥演化 / 接触图 / 窗均力)。
- 回答机制报告 §7 待确认问题:ASP614–LYS854 / LYS557–ASP839 存活与断裂位置、承力残基映射、
  二次抗阻带(cleaved 36–45 Å / uncleaved 37.5–42.5 Å)接触特征。
- 用法示例见 `{cleaved,uncleaved}/USAGE.md` 与脚本 docstring。

## 四、T12 副本包要点(4×4090 工作站)

- 每副本注入唯一 `ig` 种子(cleaved 基准 **712000**、uncleaved **723000**,副本号偏移),不同
  初速度 + 不同 Langevin 噪声 → 独立平衡末态 eq4。
- 反应坐标原子组与主副本完全同一(igr1=144 / igr2=200 Cα);新 R0 由 cpptraj 按 igr 掩码重算
  eq4 COM 距离(已验证与 pmemd DUMPAVE 一致,28.279/31.274),副本 RST 只改 `r2=r3=新R0`,
  r4/rk2/igr 字面不动。
- 复用 `run_smd_{sys}_v03.sh`(读 RST、分片可重启);产出 `amber_rNN/` 自含 eq4_npt.rst7、
  smd_chunk*.nc、smd.out。重复运行 = 新副本号,已存在目录会报错防误覆盖。
- 建议 N≥3:功/峰力/主释放距离给均值±范围;接触归因用各副本一致出现的残基。

## 五、文件清单(每体系一份)

| 文件 | 作用 |
|---|---|
| `analyze_smd_{sys}_v03.py` | 定量/初筛力–位移–功分析(v3) |
| `analyze_smd_contacts_{sys}_v02.py` | 轨迹级接触分析(T11 v2,体系固定) |
| `run_replica_{sys}_v01.sh` | 副本包装器(T12) |
| `launch_all_replicas_{sys}_v01.sh` | 4 卡并行启动器(T12) |
| `replicas_README_{sys}_v01.md` | 副本方案说明 |
| `smd_prod_{sys}_v01.dat/png` | **定量结果(证据)** |
| `smd_{sys}_v01.dat` + `smd_curves_{sys}_v01.png` | 初筛结果(非证据) |

## 六、状态

✅ 定量/初筛分析完成;T11 v2 与 T12 包已交付,待用户本地执行后回填论文 [A]/[B]。
