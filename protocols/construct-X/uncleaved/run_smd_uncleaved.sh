#!/bin/bash
# ============================================================================
# run_smd_uncleaved.sh — 项目 C' M3 SMD 生产(分片可重启版)
#
# 恒速拉动 S1尾↔S2头 COM 距离 R0 → RF(jar=1, rk2=7.2)。R0/RF 从 smd_uncleaved.RST
#   读取(r2 = 起点, r4 = 终点), 因此各体系可按其平衡 COM 距离自定义起点:
#   直接改 smd_uncleaved.RST 的 r2/r3 即可, 脚本自动重算段数与段目标。
#   --smd-speed 5 : 5 Å/ns 初筛   --smd-speed 1 : 1 Å/ns 定量
# 每段默认 1 ns(可用 --chunk N 调整), 段间可断点续跑(条件见下)。
#
# 断点续跑跳过条件: smd_chunkNN.rst7 存在【且】smd_chunkNN.mdout 正常完成
#   (含 "Final Performance Info:")【且】smd_chunkNN.RST 的 r4 == 本段目标。
#   三者齐备才跳过 —— 防两种坑:
#     a) 段被中途杀掉(如 cleaved 初筛 chunk00 止于 NSTEP=482000): mdout 未完成,
#        检测到后自动删除该段产物、从上一完整段重跑;
#     b) 换拉速/换分片后旧文件残留: 段目标与本次不一致, 自动删除重跑,
#        避免用初筛(5Å/ns, 6段)的旧 rst7 污染定量(1Å/ns, 27段)运行。
#
# 每段产物: smd_chunkNN.mdin / .RST / .mdout / .rst7 / .nc / .out(DUMPAVE)
# 全部完成(或跳过)后自动合并各段 DUMPAVE → smd.out, 供 analyze_smd.py 分析。
#
# 用法: bash run_smd_uncleaved.sh [--smd-speed 1|5] [--chunk 1] [--engine=引擎]
#   例: bash run_smd_uncleaved.sh cleaved --engine=pmemd.cuda
#        bash run_smd_uncleaved.sh uncleaved --smd-speed 1 --engine=pmemd.cuda
#
# 后台运行(推荐, 输出到日志):
#   nohup bash run_smd_uncleaved.sh cleaved --engine=pmemd.cuda > smd_run.log 2>&1 &
#   tail -f smd_run.log
#   # 或 screen: screen -dmS smd_c bash run_smd_uncleaved.sh cleaved --engine=pmemd.cuda
#
# 引擎选择(优先级): --engine= > $PMEMD_ENGINE > 自动探测(WSL 默认回退 CPU pmemd)
# 前置: 当前目录含 step3_input.parm7, eq4_npt.rst7, smd_uncleaved.RST, smd_pull_uncleaved.mdin
# ============================================================================
set -euo pipefail

# ---------- 参数解析 ----------
SYS="uncleaved"; SPEED="5"; ENGINE_ARG=""; CHUNK=1
ARGS=("$@"); i=0
while [ $i -lt ${#ARGS[@]} ]; do
  a="${ARGS[$i]}"
  case "$a" in
    cleaved|uncleaved)  [ "$a" = "uncleaved" ] || { echo "错误: 本脚本固定用于 uncleaved, 收到体系 '$a'"; exit 1; } ;;
    --smd-speed)        i=$((i+1)); SPEED="${ARGS[$i]:-}" ;;
    --smd-speed=*)      SPEED="${a#--smd-speed=}" ;;
    --chunk)            i=$((i+1)); CHUNK="${ARGS[$i]:-}" ;;
    --chunk=*)          CHUNK="${a#--chunk=}" ;;
    --engine=*)         ENGINE_ARG="${a#--engine=}" ;;
    *) echo "未知参数: $a"; exit 1 ;;
  esac
  i=$((i+1))
done
[ -n "$SYS" ] || { echo "用法: run_smd_uncleaved.sh <cleaved|uncleaved> [--smd-speed 1|5] [--chunk 1] [--engine=引擎]"; exit 1; }
case "$SPEED" in 1|5) ;; *) echo "错误: 拉速仅支持 1 或 5 Å/ns"; exit 1;; esac
echo "$CHUNK" | grep -qE '^[0-9]+$' || { echo "错误: --chunk 需为正整数(ns)"; exit 1; }

# ---------- 引擎选择(只做路径探测, 不执行任何 GPU 二进制) ----------
pick_engine() {
  if [ -n "$ENGINE_ARG" ]; then
    if command -v "$ENGINE_ARG" >/dev/null 2>&1; then echo "$ENGINE_ARG"; return
    else echo "错误: 未找到引擎 '$ENGINE_ARG'"; exit 1; fi
  fi
  if [ -n "${PMEMD_ENGINE:-}" ]; then
    if command -v "$PMEMD_ENGINE" >/dev/null 2>&1; then echo "$PMEMD_ENGINE"; return
    else echo "错误: 未找到引擎 '\$PMEMD_ENGINE' = '$PMEMD_ENGINE'"; exit 1; fi
  fi
  local wsl=0
  grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null && wsl=1
  if command -v pmemd.cuda >/dev/null 2>&1; then
    if [ "$wsl" = "1" ]; then
      echo "检测到 pmemd.cuda, 但当前是 WSL 环境: 默认回退 CPU 版 pmemd。" >&2
      echo "  (若已配好 NVIDIA WSL 驱动, 请显式加 --engine=pmemd.cuda 启用 GPU)" >&2
    else
      echo "pmemd.cuda"; return
    fi
  fi
  if command -v pmemd >/dev/null 2>&1; then echo "pmemd"; return; fi
  if command -v sander >/dev/null 2>&1; then echo "sander"; return; fi
  echo "错误: 未找到 pmemd/pmemd.cuda/sander(请检查 Amber 安装或显式 --engine=)" >&2; exit 1
}
ENGINE="$(pick_engine)"

# ---------- 前置检查 ----------
[ -f step3_input.parm7 ] || { echo "错误: 缺 step3_input.parm7(请在 amber 目录内运行)"; exit 1; }
[ -f eq4_npt.rst7      ] || { echo "错误: 缺 eq4_npt.rst7: 请先跑 run_equil.sh 完成平衡"; exit 1; }
[ -f smd_uncleaved.RST           ] || { echo "错误: 缺 smd_uncleaved.RST"; exit 1; }
[ -f smd_pull_uncleaved.mdin     ] || { echo "错误: 缺 smd_pull_uncleaved.mdin"; exit 1; }

# ---------- 从 smd_uncleaved.RST 读取反应坐标起止(单一事实来源) ----------
# r2 = 起点(R0), r4 = 终点(RF); 各体系按平衡 COM 距离改 r2 即自定义起点。
R0="$(python3 - <<'PYEOF'
import re
s = open('smd_uncleaved.RST').read()
m = re.search(r'\br2\s*=\s*([0-9.]+)', s)
if not m: raise SystemExit('错误: smd_uncleaved.RST 未找到 r2(起点)')
print(m.group(1))
PYEOF
)"
RF="$(python3 - <<'PYEOF'
import re
s = open('smd_uncleaved.RST').read()
m = re.search(r'\br4\s*=\s*([0-9.]+)', s)
if not m: raise SystemExit('错误: smd_uncleaved.RST 未找到 r4(终点)')
print(m.group(1))
PYEOF
)"
echo "==> smd_uncleaved.RST: 反应坐标 R0=${R0} Å → RF=${RF} Å"

# ---------- 分片段数 ----------
NSEG="$(python3 - "$SPEED" "$CHUNK" "$R0" "$RF" <<'PYEOF'
import sys, math
v  = float(sys.argv[1])
c  = float(sys.argv[2])
R0 = float(sys.argv[3])
RF = float(sys.argv[4])
T  = (RF - R0) / v
print(int(math.ceil(T / c - 1e-9)))
PYEOF
)"
echo "==> 引擎: $ENGINE  体系: $SYS  拉速: ${SPEED} Å/ns  分片: ${CHUNK} ns/段  共 ${NSEG} 段"
echo "==> SMD 恒速拉动: eq4_npt.rst7 起步, COM 距离 ${R0} → ${RF} Å"

# ---------- 逐段运行(断点续跑) ----------
for ((seg=0; seg<NSEG; seg++)); do
  NN="$(printf "%02d" "$seg")"
  # 段参数: t0,t1(ns)  r2s,r2e(Å)  nst(步) —— 先算, 供判断旧文件是否与本次一致
  read T0 T1 R2S R2E NST <<< "$(python3 - "$SPEED" "$CHUNK" "$seg" "$R0" "$RF" <<'PYEOF'
import sys
v, c, seg = float(sys.argv[1]), float(sys.argv[2]), int(sys.argv[3])
R0, RF = float(sys.argv[4]), float(sys.argv[5])
T  = (RF - R0) / v
t0 = seg * c
t1 = min((seg + 1) * c, T)
r2s = R0 + v * t0
r2e = R0 + v * t1
nst = int(round((t1 - t0) * 1e3 / 0.002))
print(f"{t0:.4f} {t1:.4f} {r2s:.6f} {r2e:.6f} {nst}")
PYEOF
)"
  R2E6="$(printf "%.6f" "$R2E")"

  # 跳过条件: rst7 存在【且】mdout 正常完成【且】段 RST 的 r4 == 本段目标
  if [ -f "smd_chunk${NN}.rst7" ] && [ -f "smd_chunk${NN}.mdout" ] \
     && grep -q "Final Performance Info:" "smd_chunk${NN}.mdout" \
     && [ -f "smd_chunk${NN}.RST" ] && grep -qE "r4 = ${R2E6}," "smd_chunk${NN}.RST"; then
    echo "==> [段 $((seg+1))/${NSEG}] smd_chunk${NN} 已完成, 跳过"
    continue
  fi
  # 残留但不完整/参数不符: 删除后从上一完整段重跑
  if [ -f "smd_chunk${NN}.rst7" ]; then
    echo "==> [段 $((seg+1))/${NSEG}] smd_chunk${NN}.rst7 存在但 mdout 未完成或段目标不符, 删除重跑"
    rm -f "smd_chunk${NN}.rst7" "smd_chunk${NN}.mdout" "smd_chunk${NN}.out" \
          "smd_chunk${NN}.nc" "smd_chunk${NN}.mdin" "smd_chunk${NN}.RST"
  fi
  INP=eq4_npt.rst7
  [ "$seg" -gt 0 ] && INP="smd_chunk$(printf "%02d" $((seg-1))).rst7"

  # 生成段 mdin + RST
  python3 - smd_pull_uncleaved.mdin smd_uncleaved.RST "smd_chunk${NN}.mdin" "smd_chunk${NN}.RST" "$NST" "$NN" "$R2S" "$R2E" <<'PYEOF'
import sys, re
src_md, src_rst, dst_md, dst_rst = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
nst, nn, r2s, r2e = sys.argv[5], sys.argv[6], sys.argv[7], sys.argv[8]
# --- mdin: 只改 &cntrl 内 nstlim(行首锚定, 避开注释行), 改 DISANG/DUMPAVE ---
md = open(src_md).read()
md = re.sub(r'(?m)^(\s*)nstlim=[0-9]+,', rf'\g<1>nstlim={nst},', md)
md = md.replace('DISANG=smd_uncleaved.RST', f'DISANG=smd_chunk{nn}.RST')
md = md.replace('DUMPAVE=smd.out', f'DUMPAVE=smd_chunk{nn}.out')
open(dst_md, 'w').write(md)
# --- RST: 更新 r1/r2/r3/r4 与 r2a(段起止距离) ---
rst = open(src_rst).read()
rst = re.sub(r'r1 = [0-9.]+, r2 = [0-9.]+, r3 = [0-9.]+, r4 = [0-9.]+,',
             f'r1 = 0.0, r2 = {r2s}, r3 = {r2s}, r4 = {r2e},', rst)
rst = re.sub(r'r2a = [0-9.]+, rk2a = [0-9.]+, rk3a = [0-9.]+,',
             f'r2a = {r2e}, rk2a = 7.2, rk3a = 7.2,', rst)
open(dst_rst, 'w').write(rst)
PYEOF

  echo "==> [段 $((seg+1))/${NSEG}] ${T0}–${T1} ns | r2: ${R2S} → ${R2E} Å | ${NST} 步 | 输入 $INP"
  $ENGINE -O -i "smd_chunk${NN}.mdin" -p step3_input.parm7 -c "$INP" \
          -o "smd_chunk${NN}.mdout" -r "smd_chunk${NN}.rst7" -x "smd_chunk${NN}.nc" \
          -ref eq4_npt.rst7
done

# ---------- 合并 DUMPAVE(只按本次 NSEG 顺序合并, 不碰残留旧段) ----------
: > smd.out
for ((seg=0; seg<NSEG; seg++)); do
  NN="$(printf "%02d" "$seg")"
  [ -f "smd_chunk${NN}.out" ] && cat "smd_chunk${NN}.out" >> smd.out
done
echo
echo "SMD 完成。产物:"
echo "  轨迹      smd_chunkNN.nc      (每段独立)"
echo "  拉力/功   smd.out             (各段 DUMPAVE 合并)"
echo "  断点结构  smd_chunkNN.rst7    (任一时刻可续跑)"
echo "下一步:  python analyze_smd.py smd.out --speed ${SPEED} --plot"
