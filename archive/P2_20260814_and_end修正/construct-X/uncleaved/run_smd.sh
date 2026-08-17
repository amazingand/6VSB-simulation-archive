#!/bin/bash
# ============================================================================
# run_smd.sh — 项目 C' M3 SMD 生产段(从 EQ4 末态起步, 云侧核验通过后执行)
#
# 前置: run_equil.sh 已成功跑完, 当前目录有:
#   step3_input.parm7 / eq4_npt.rst7 / smd_pull.mdin / smd.RST
#
# 用法:  bash run_smd.sh <cleaved|uncleaved> [--smd-speed 1|5] [--engine=引擎]
#   例:  bash run_smd.sh cleaved                          # 5 A/ns 初筛 (5.24 ns)
#         bash run_smd.sh uncleaved --smd-speed 1         # 1 A/ns 定量 (26.2 ns)
#         bash run_smd.sh cleaved --engine=pmemd.cuda     # 显式启用 GPU
#
# 引擎选择(优先级从高到低): 同 run_equil.sh
#   1) --engine=<name>    2) 环境变量 PMEMD_ENGINE    3) 自动探测(WSL 默认回退 CPU)
#   ⚠ WSL2 下 GPU 二进制未配置好驱动会强制退出整个 WSL, 确认可用后再 --engine=pmemd.cuda
#
# 产物:  smd_pull.nc  (SMD 轨迹)   smd.out  (DUMPAVE, 供 analyze_smd.py)
# ============================================================================
set -euo pipefail

# ---------- 参数解析(兼容 --smd-speed 1 与 --smd-speed=1) ----------
SYS=""; SPEED="5"; ENGINE_ARG=""
i=1
while [ $i -le $# ]; do
  a="${!i}"
  case "$a" in
    cleaved|uncleaved) SYS="$a" ;;
    --smd-speed)       i=$((i+1)); SPEED="${!i:-}" ;;
    --smd-speed=*)     SPEED="${a#--smd-speed=}" ;;
    --engine=*)        ENGINE_ARG="${a#--engine=}" ;;
    *)                 echo "未知参数: $a"; exit 1 ;;
  esac
  i=$((i+1))
done
[ -n "$SYS" ] || { echo "用法: run_smd.sh <cleaved|uncleaved> [--smd-speed 1|5] [--engine=引擎]"; exit 1; }
case "$SPEED" in 1|5) ;; *) echo "错误: 拉速仅支持 1 或 5 A/ns"; exit 1;; esac

# ---------- 引擎选择(与 run_equil.sh 一致) ----------
pick_engine() {
  if [ -n "$ENGINE_ARG" ]; then
    if command -v "$ENGINE_ARG" >/dev/null 2>&1; then
      echo "$ENGINE_ARG"; return
    else
      echo "错误: 未找到引擎 '$ENGINE_ARG'(请检查 Amber 安装或路径)"; exit 1
    fi
  fi
  if [ -n "${PMEMD_ENGINE:-}" ]; then
    if command -v "$PMEMD_ENGINE" >/dev/null 2>&1; then
      echo "$PMEMD_ENGINE"; return
    else
      echo "错误: 未找到引擎 '\$PMEMD_ENGINE' = '$PMEMD_ENGINE'(请检查 Amber 安装或路径)"; exit 1
    fi
  fi
  local wsl=0
  grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null && wsl=1
  if command -v pmemd.cuda >/dev/null 2>&1; then
    if [ "$wsl" = "1" ]; then
      echo "检测到 pmemd.cuda, 但当前是 WSL 环境: 默认回退 CPU 版 pmemd, 避免 WSL 崩溃。" >&2
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
echo "==> 引擎: $ENGINE  体系: $SYS  拉速: ${SPEED} A/ns"

# ---------- 前置检查 ----------
[ -f step3_input.parm7 ] || { echo "错误: 缺 step3_input.parm7(请在 amber 产物目录内运行)"; exit 1; }
[ -f eq4_npt.rst7      ] || { echo "错误: 缺 eq4_npt.rst7: 请先跑 run_equil.sh 完成平衡"; exit 1; }

# ---------- SMD 恒速拉动(EQ4 末态起步) ----------
if [ "$SPEED" = "5" ]; then
    SMD_MDIN=smd_pull.mdin          # nstlim=2,620,000 = 5.24 ns @ 5 A/ns
else
    # 1 A/ns 定量: nstlim = (55-28.8)/(0.001*0.002) = 13,100,000 步 = 26.2 ns
    sed 's/nstlim=2620000/nstlim=13100000/' smd_pull.mdin > smd_pull_1ans.mdin
    SMD_MDIN=smd_pull_1ans.mdin
fi
echo "==> SMD 恒速拉动 ${SPEED} A/ns ($SMD_MDIN, 从 eq4_npt.rst7 起步)"
$ENGINE -O -i $SMD_MDIN -p step3_input.parm7 -c eq4_npt.rst7 \
        -o smd_pull.mdout -r smd_pull.rst7 -x smd_pull.nc

echo
echo "SMD 完成。产物:"
echo "  SMD 轨迹    smd_pull.nc"
echo "  SMD 拉力    smd.out               (DUMPAVE, 供 analyze_smd.py)"
echo
echo "下一步:  python analyze_smd.py smd.out --plot"
