#!/bin/bash
# ============================================================================
# run_smd.sh — 项目 C' M3 SMD 生产(分片可重启版)
#
# 恒速拉动 S1尾↔S2头 COM 距离 28.80 → 55.00 Å(jar=1, rk2=7.2, 见 smd.RST)
#   --smd-speed 5 : 5 Å/ns 初筛(总 5.24 ns)
#   --smd-speed 1 : 1 Å/ns 定量(总 26.2 ns)
# 每段默认 1 ns(可用 --chunk N 调整), 段间可断点续跑:
#   已生成 smd_chunkNN.rst7 的段自动跳过(重跑脚本即从断点继续)。
#
# 每段产物: smd_chunkNN.mdin / .RST / .mdout / .rst7 / .nc / .out(DUMPAVE)
# 全部完成(或跳过)后自动合并各段 DUMPAVE → smd.out, 供 analyze_smd.py 分析。
#
# 用法: bash run_smd.sh <cleaved|uncleaved> [--smd-speed 1|5] [--chunk 1] [--engine=引擎]
#   例: bash run_smd.sh cleaved --engine=pmemd.cuda
#        bash run_smd.sh uncleaved --smd-speed 1 --engine=pmemd.cuda
#
# 后台运行(推荐, 输出到日志):
#   nohup bash run_smd.sh cleaved --engine=pmemd.cuda > smd_run.log 2>&1 &
#   tail -f smd_run.log
#   # 或 screen: screen -dmS smd_c bash run_smd.sh cleaved --engine=pmemd.cuda
#
# 引擎选择(优先级): --engine= > $PMEMD_ENGINE > 自动探测(WSL 默认回退 CPU pmemd)
# 前置: 当前目录含 step3_input.parm7, eq4_npt.rst7, smd.RST, smd_pull.mdin
# ============================================================================
set -euo pipefail

# ---------- 参数解析 ----------
SYS=""; SPEED="5"; ENGINE_ARG=""; CHUNK=1
ARGS=("$@"); i=0
while [ $i -lt ${#ARGS[@]} ]; do
  a="${ARGS[$i]}"
  case "$a" in
    cleaved|uncleaved)  SYS="$a" ;;
    --smd-speed)        i=$((i+1)); SPEED="${ARGS[$i]:-}" ;;
    --smd-speed=*)      SPEED="${a#--smd-speed=}" ;;
    --chunk)            i=$((i+1)); CHUNK="${ARGS[$i]:-}" ;;
    --chunk=*)          CHUNK="${a#--chunk=}" ;;
    --engine=*)         ENGINE_ARG="${a#--engine=}" ;;
    *) echo "未知参数: $a"; exit 1 ;;
  esac
  i=$((i+1))
done
[ -n "$SYS" ] || { echo "用法: run_smd.sh <cleaved|uncleaved> [--smd-speed 1|5] [--chunk 1] [--engine=引擎]"; exit 1; }
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
[ -f smd.RST           ] || { echo "错误: 缺 smd.RST"; exit 1; }
[ -f smd_pull.mdin     ] || { echo "错误: 缺 smd_pull.mdin"; exit 1; }

# ---------- 分片段数 ----------
NSEG="$(python3 - "$SPEED" "$CHUNK" <<'PYEOF'
import sys, math
v  = float(sys.argv[1])
c  = float(sys.argv[2])
DR = 55.0 - 28.80
T  = DR / v
print(int(math.ceil(T / c - 1e-9)))
PYEOF
)"
echo "==> 引擎: $ENGINE  体系: $SYS  拉速: ${SPEED} Å/ns  分片: ${CHUNK} ns/段  共 ${NSEG} 段"
echo "==> SMD 恒速拉动: eq4_npt.rst7 起步, COM 距离 28.80 → 55.00 Å"

# ---------- 逐段运行(断点续跑) ----------
for ((seg=0; seg<NSEG; seg++)); do
  NN="$(printf "%02d" "$seg")"
  if [ -f "smd_chunk${NN}.rst7" ]; then
    echo "==> [段 $((seg+1))/${NSEG}] smd_chunk${NN}.rst7 已存在, 跳过"
    continue
  fi
  # 段参数: t0,t1(ns)  r2s,r2e(Å)  nst(步)
  read T0 T1 R2S R2E NST <<< "$(python3 - "$SPEED" "$CHUNK" "$seg" <<'PYEOF'
import sys
v, c, seg = float(sys.argv[1]), float(sys.argv[2]), int(sys.argv[3])
R0, RF = 28.80, 55.0
T  = (RF - R0) / v
t0 = seg * c
t1 = min((seg + 1) * c, T)
r2s = R0 + v * t0
r2e = R0 + v * t1
nst = int(round((t1 - t0) * 1e3 / 0.002))
print(f"{t0:.4f} {t1:.4f} {r2s:.6f} {r2e:.6f} {nst}")
PYEOF
)"
  INP=eq4_npt.rst7
  [ "$seg" -gt 0 ] && INP="smd_chunk$(printf "%02d" $((seg-1))).rst7"

  # 生成段 mdin + RST
  python3 - smd_pull.mdin smd.RST "smd_chunk${NN}.mdin" "smd_chunk${NN}.RST" "$NST" "$NN" "$R2S" "$R2E" <<'PYEOF'
import sys, re
src_md, src_rst, dst_md, dst_rst = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
nst, nn, r2s, r2e = sys.argv[5], sys.argv[6], sys.argv[7], sys.argv[8]
# --- mdin: 只改 &cntrl 内 nstlim(行首锚定, 避开注释行), 改 DISANG/DUMPAVE ---
md = open(src_md).read()
md = re.sub(r'(?m)^(\s*)nstlim=[0-9]+,', rf'\g<1>nstlim={nst},', md)
md = md.replace('DISANG=smd.RST', f'DISANG=smd_chunk{nn}.RST')
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

# ---------- 合并 DUMPAVE ----------
: > smd.out
for f in smd_chunk*.out; do cat "$f" >> smd.out 2>/dev/null || true; done
echo
echo "SMD 完成。产物:"
echo "  轨迹      smd_chunkNN.nc      (每段独立)"
echo "  拉力/功   smd.out             (各段 DUMPAVE 合并)"
echo "  断点结构  smd_chunkNN.rst7    (任一时刻可续跑)"
echo "下一步:  python analyze_smd.py smd.out --speed ${SPEED} --plot"
