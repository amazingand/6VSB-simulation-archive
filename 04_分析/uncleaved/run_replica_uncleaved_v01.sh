#!/bin/bash
# ============================================================================
# run_replica_uncleaved_v01.sh — 项目 C' 副本(独立重复)平衡 + SMD 包装器 · uncleaved 体系
#
# 用途: 针对"单轨迹"限制, 在 4×4090 工作站上生产独立副本:
#   每副本给 eq1–eq4 平衡链注入唯一随机种子 ig, 得到不同的平衡末态 eq4,
#   再用 cpptraj 按 RST 的 igr1/igr2(与 pmemd COM 约束同一原子组)重算新 R0,
#   生成副本专用 smd_<name>.RST(仅 r2 起点不同, igr 列表/终点/力常数字面不动),
#   最后复用 run_smd_<name>.sh 分片生产(它从 RST 读 R0/RF, 自动适配)。
#
#   ig 是 Amber 标准随机种子变量(sander/pmemd 均支持, 已验证):
#   - 同 ig → 同初速度 + 同 Langevin 噪声流 → 平衡/SMD 确定性可复现;
#   - 不同 ig → 独立轨迹。副本独立性来源即每副本唯一 ig。
#
# 用法: bash run_replica_uncleaved_v01.sh <repN> [--engine=引擎] [--smd-speed 1|5]
#   例: bash run_replica_uncleaved_v01.sh 1 --engine=pmemd.cuda --smd-speed 1
#
# 4 卡并行(4×4090 工作站, 在 amber/ 目录):
#   nohup bash run_replica_uncleaved_v01.sh 1 --engine=pmemd.cuda --gpu 0 > r1.log 2>&1 &
#   nohup bash run_replica_uncleaved_v01.sh 2 --engine=pmemd.cuda --gpu 1 > r2.log 2>&1 &
#   nohup bash run_replica_uncleaved_v01.sh 3 --engine=pmemd.cuda --gpu 2 > r3.log 2>&1 &
#   nohup bash run_replica_uncleaved_v01.sh 4 --engine=pmemd.cuda --gpu 3 > r4.log 2>&1 &
#   (--gpu N 只设 CUDA_VISIBLE_DEVICES=N, 各副本独占一张卡)
#   或直接: bash launch_all_replicas_uncleaved_v01.sh 4 --engine=pmemd.cuda --smd-speed 1
#
# 前置(在 CHARMM-GUI amber/ 目录内运行):
#   step3_input.parm7/.rst7/.pdb、dihe.restraint、
#   run_equil_uncleaved_v01.sh、run_smd_uncleaved_v03.sh、smd_pull_uncleaved_v03.mdin、smd_uncleaved_v02.RST
#   (即 03_SMD运行/uncleaved/ 部署单元全部文件 + 平衡产物; 首次副本可不含平衡产物, 链会重跑)
#
# 副本目录:  amber_r<repN>/(自含, 静态输入 + mdin + 脚本全部拷贝)
# 产物:      amber_r<repN>/smd_chunk*.nc、smd.out(与主副本同名文件, 便于统一分析)
# ============================================================================
set -euo pipefail

# ---------- 参数 ----------
SYS="uncleaved"; REPN="${1:-}"
ENGINE_ARG=""; SPEED="1"; GPU=""
ARGS=("$@"); i=1
while [ $i -lt ${#ARGS[@]} ]; do
  a="${ARGS[$i]}"
  case "$a" in
    --engine=*)   ENGINE_ARG="${a#--engine=}" ;;
    --smd-speed)  i=$((i+1)); SPEED="${ARGS[$i]:-}" ;;
    --smd-speed=*) SPEED="${a#--smd-speed=}" ;;
    --gpu)        i=$((i+1)); GPU="${ARGS[$i]:-}" ;;
    --gpu=*)      GPU="${a#--gpu=}" ;;
    *) echo "未知参数: $a"; exit 1 ;;
  esac
  i=$((i+1))
done
[ -n "$REPN" ] || { echo "用法: run_replica_uncleaved_v01.sh <repN> [--engine=] [--smd-speed 1|5] [--gpu N]"; exit 1; }
echo "$REPN" | grep -qE '^[0-9]+$' || { echo "错误: repN 需为正整数"; exit 1; }
case "$SPEED" in 1|5) ;; *) echo "错误: 拉速仅 1 或 5"; exit 1;; esac
[ -n "$GPU" ] && { echo "$GPU" | grep -qE '^[0-9]+$' || { echo "错误: --gpu 需为 GPU 序号"; exit 1; }; export CUDA_VISIBLE_DEVICES="$GPU"; }

# ---------- 引擎选择(与 run_equil/run_smd 同款; WSL 安全回退) ----------
pick_engine() {
  if [ -n "$ENGINE_ARG" ]; then
    if command -v "$ENGINE_ARG" >/dev/null 2>&1; then echo "$ENGINE_ARG"; return
    else echo "错误: 未找到引擎 '$ENGINE_ARG'"; exit 1; fi
  fi
  if [ -n "${PMEMD_ENGINE:-}" ]; then
    if command -v "$PMEMD_ENGINE" >/dev/null 2>&1; then echo "$PMEMD_ENGINE"; return
    else echo "错误: 未找到引擎 '\$PMEMD_ENGINE'"; exit 1; fi
  fi
  local wsl=0; grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null && wsl=1
  if command -v pmemd.cuda >/dev/null 2>&1; then
    if [ "$wsl" = "1" ]; then
      echo "WSL 检测到 pmemd.cuda, 默认回退 CPU pmemd(配好 NVIDIA WSL 驱动后显式 --engine=pmemd.cuda)" >&2
    else echo "pmemd.cuda"; return; fi
  fi
  if command -v pmemd >/dev/null 2>&1; then echo "pmemd"; return; fi
  if command -v sander >/dev/null 2>&1; then echo "sander"; return; fi
  echo "错误: 未找到 pmemd/pmemd.cuda/sander"; exit 1
}
ENGINE="$(pick_engine)"

# ---------- 前置检查(当前目录 = amber/) ----------
for f in step3_input.parm7 step3_input.rst7 dihe.restraint \
         run_equil_uncleaved_v01.sh run_smd_uncleaved_v03.sh smd_pull_uncleaved_v03.mdin smd_uncleaved_v02.RST; do
  [ -f "$f" ] || { echo "错误: 当前目录缺 $f(请在 amber/ 目录运行)"; exit 1; }
done
command -v cpptraj >/dev/null 2>&1 || { echo "错误: 需要 cpptraj(AmberTools)重算副本 R0"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "错误: 需要 python3"; exit 1; }

# ---------- 副本种子(唯一、可复现) ----------
# ig = 体系基准 + 副本号。cleaved 基准 712000, uncleaved 基准 723000。
if [ "$SYS" = "cleaved" ]; then BASE=712000; else BASE=723000; fi
IGSEED=$((BASE + REPN))

REPDIR="amber_r$(printf "%02d" "$REPN")"
[ -d "$REPDIR" ] && { echo "错误: $REPDIR 已存在(请用未用过的副本号, 或删除后重跑)"; exit 1; }
mkdir -p "$REPDIR"
echo "==> 副本 $SYS/r$REPN: 目录 $REPDIR, 随机种子 ig=$IGSEED, 引擎 $ENGINE, 拉速 ${SPEED} Å/ns"

# ---------- 拷贝静态输入 + 部署单元到副本目录 ----------
cp -f step3_input.parm7 step3_input.rst7 step3_input.pdb dihe.restraint "$REPDIR/"
[ -f dihe_FC1.rest ] && cp -f dihe_FC1.rest "$REPDIR/"
cp -f align_min_uncleaved_v01.mdin eq1_nvt_uncleaved_v01.mdin eq2_npt_uncleaved_v01.mdin eq3_npt_uncleaved_v01.mdin eq4_npt_uncleaved_v01.mdin "$REPDIR/" 2>/dev/null || true
[ -f eq5_npt_uncleaved_v01.mdin ] && cp -f eq5_npt_uncleaved_v01.mdin "$REPDIR/"
cp -f run_equil_uncleaved_v01.sh run_smd_uncleaved_v03.sh smd_pull_uncleaved_v03.mdin smd_uncleaved_v02.RST analyze_smd_uncleaved_v03.py "$REPDIR/"

# ---------- 给 eq1–eq4(及 eq5)注入 ig ----------
# 仅改 &cntrl 内的 ig: 已有则替换值, 没有则在 imin 行后插入。
for m in eq1_nvt_uncleaved_v01.mdin eq2_npt_uncleaved_v01.mdin eq3_npt_uncleaved_v01.mdin eq4_npt_uncleaved_v01.mdin eq5_npt_uncleaved_v01.mdin; do
  [ -f "$REPDIR/$m" ] || continue
  python3 - "$REPDIR/$m" "$IGSEED" <<'PYEOF'
import sys, re
path, seed = sys.argv[1], sys.argv[2]
s = open(path).read()
cntrl = s.split('&cntrl', 1)
assert len(cntrl) == 2, f'{path}: 未找到 &cntrl 块'
head, body = cntrl
if re.search(r'(?m)^\s*ig\s*=', body):
    body = re.sub(r'(?m)^(\s*)ig\s*=\s*[^,]+(,)', rf'\g<1>ig = {seed}\g<2>', body, count=1)
else:
    body = re.sub(r'(?m)^(\s*imin=[^\n]*)$', rf'\g<1>\n    ig = {seed},', body, count=1)
open(path, 'w').write(head + '&cntrl' + body)
PYEOF
  echo "  已注入 ig=$IGSEED: $m"
done
# SMD 模板同注入(分片生成时透传到每段; irest=1 下 ig 只控 Langevin 噪声流)
python3 - "$REPDIR/smd_pull_uncleaved_v03.mdin" "$IGSEED" <<'PYEOF'
import sys, re
path, seed = sys.argv[1], sys.argv[2]
s = open(path).read()
head, body = s.split('&cntrl', 1)
if re.search(r'(?m)^\s*ig\s*=', body):
    body = re.sub(r'(?m)^(\s*)ig\s*=\s*[^,]+(,)', rf'\g<1>ig = {seed}\g<2>', body, count=1)
else:
    body = re.sub(r'(?m)^(\s*imin=[^\n]*)$', rf'\g<1>\n    ig = {seed},', body, count=1)
open(path, 'w').write(head + '&cntrl' + body)
PYEOF
echo "  已注入 ig=$IGSEED: smd_pull_uncleaved_v03.mdin(模板)"

# ---------- 平衡链(align_min 确定性共享 → eq1–eq4, 在副本目录内跑) ----------
cd "$REPDIR"
echo "==> 平衡链: align_min → eq1 → eq2 → eq3 → eq4(ig=$IGSEED)"
bash run_equil_uncleaved_v01.sh --engine="$ENGINE"
[ -f eq4_npt.rst7 ] || { echo "错误: 平衡链未产出 eq4_npt.rst7"; exit 1; }

# ---------- 用 cpptraj + igr 掩码重算 eq4 COM 距离 → 新 R0 ----------
# igr1/igr2 原子索引从参考 smd_<name>.RST 提取(与 pmemd COM 约束同一原子组);
# distance 命令对两组质心求距(纯 Cα 等质量, COG=COM, 云侧已验证与 pmemd DUMPAVE 一致)。
python3 - "smd_uncleaved_v02.RST" <<'PYEOF'
import sys, re
rst = sys.argv[1]
txt = open(rst).read()
def nums(block): return [int(x) for x in re.split(r'[,\s]+', block) if x.strip().isdigit()]
i1 = nums(re.findall(r'igr1\s*=\s*(.*?)igr2', txt, re.S)[0])
i2 = nums(re.findall(r'igr2\s*=\s*(.*?)\s*&end', txt, re.S)[0])
with open('cpptraj_r0.in', 'w') as f:
    f.write('parm step3_input.parm7\n')
    f.write('trajin eq4_npt.rst7\n')
    f.write(f'distance comd @{",".join(map(str, i1))} @{",".join(map(str, i2))} out r0_com.txt\n')
print(f'cpptraj 输入已生成: igr1={len(i1)} igr2={len(i2)} 原子')
PYEOF
cpptraj -i cpptraj_r0.in >/dev/null
NEWR0="$(grep -v '^#' r0_com.txt | tail -1 | awk '{printf "%.2f", $2}')"
[ -n "$NEWR0" ] && echo "$NEWR0" | grep -qE '^[0-9.]+$' || { echo "错误: 未能从 cpptraj 输出读取 COM 距离"; exit 1; }
echo "==> 副本 eq4 COM 距离 = ${NEWR0} Å(参考 R0 = $(grep -oP 'r2 = \K[0-9.]+' ../smd_uncleaved_v02.RST | head -1) Å)"

# ---------- 生成副本 smd_<name>.RST(仅改 r2/r3 起点, 余字面不变) ----------
python3 - "smd_uncleaved_v02.RST" "$NEWR0" <<'PYEOF'
import sys, re
path, newr2 = sys.argv[1], sys.argv[2]
s = open(path).read()
s2 = re.sub(r'r1 = [0-9.]+, r2 = [0-9.]+, r3 = [0-9.]+, r4 = [0-9.]+,',
            f'r1 = 0.0, r2 = {newr2}, r3 = {newr2}, r4 = 55.0,', s, count=1)
assert s2 != s, '副本 RST 生成失败: 未匹配到 r1/r2/r3/r4 行'
open(path, 'w').write(s2)
print(f'已生成副本 RST: r2 = r3 = {newr2}, r4 = 55.0, igr 列表与力常数不变')
PYEOF

# ---------- SMD 分片生产(复用 run_smd, 从新 RST 读 R0/RF) ----------
echo "==> SMD 分片生产: bash run_smd_uncleaved_v03.sh --smd-speed ${SPEED} --engine=$ENGINE"
bash run_smd_uncleaved_v03.sh --smd-speed "$SPEED" --engine="$ENGINE"

echo
echo "副本完成。产物在 $REPDIR/:"
echo "  eq4_npt.rst7       副本平衡末态(独立起点)"
echo "  smd_uncleaved_v02.RST 副本反应坐标(新 R0=${NEWR0} Å)"
echo "  smd_chunk*.nc/out  SMD 分片轨迹 + DUMPAVE"
echo "  smd.out            合并力/功数据(analyze_smd_uncleaved_v03.py 直接分析)"
echo "建议: 与主副本一起用 analyze_smd_contacts_uncleaved_v02.py 做轨迹级接触分析。"
