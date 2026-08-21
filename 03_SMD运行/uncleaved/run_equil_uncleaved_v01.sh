#!/bin/bash
# ============================================================================
# run_equil_uncleaved_v01.sh — 项目 C' M3 平衡段 · uncleaved 体系(跑到 EQ4 停)
#
# 本脚本为体系专属副本(原共享 run_equil.sh 拆分), 固定体系 = uncleaved,
# 引用本目录版本化 mdin(align_min_uncleaved_v01 / eq*_uncleaved_v01)。
#
# 流程: 对齐极小化(确定性, 云端/本地同步分界点)
#        → EQ1(NVT 升温)→ EQ2-EQ4(NPT 阶梯放开 posres)
#   EQ5 为可选稳定性检验, 用 --eq5 打开
#
# 用法:  bash run_equil_uncleaved_v01.sh [--eq5] [--engine=引擎]
#   例:  bash run_equil_uncleaved_v01.sh                          # CPU pmemd(默认)
#         bash run_equil_uncleaved_v01.sh --eq5                   # 加 EQ5 稳定性检验
#         bash run_equil_uncleaved_v01.sh --engine=pmemd.cuda     # 显式启用 GPU
#
# 引擎选择(优先级从高到低):
#   1) --engine=<name>      命令行参数(推荐, 环境已确认时用)
#   2) PMEMD_ENGINE         环境变量, 如 export PMEMD_ENGINE=pmemd.cuda
#   3) 自动探测             见下方 "WSL2 安全策略"
#
#   ⚠ WSL2 用户注意: 在 WSL2 下若 NVIDIA WSL 驱动未配置好, 直接运行
#     pmemd.cuda 会强制退出整个 WSL。因此自动探测在 WSL 环境默认回退到
#     CPU 版 pmemd, 绝不自动执行 GPU 二进制; 确认 GPU 可用后再显式加
#     --engine=pmemd.cuda。
#
# 前置: 当前目录含 CHARMM-GUI 产物:
#   step3_input.parm7 / step3_input.rst7 / dihe.restraint
#   以及本套件 mdin(align_min_uncleaved_v01 / eq1_nvt_uncleaved_v01 … eq4_npt_uncleaved_v01)
#
# 产物:
#   align_min.rst7   — 与云侧核验的分界结构(确定性)
#   eq4_npt.rst7/.nc — EQ4 末态, SMD 生产的起点
#
# 核验通过后接续:  bash run_smd_uncleaved_v03.sh [--engine=引擎]
# ============================================================================
set -euo pipefail

# ---------- 参数解析 ----------
SYS="uncleaved"
DO_EQ5=0
ENGINE_ARG=""
for a in "${@}"; do
  case "$a" in
    --eq5)        DO_EQ5=1 ;;
    --engine=*)   ENGINE_ARG="${a#--engine=}" ;;
    *)            echo "未知参数: $a"; exit 1 ;;
  esac
done

# ---------- 引擎选择(只做路径探测, 不执行任何 GPU 二进制) ----------
pick_engine() {
  # 1) 命令行显式指定 → 直接采用(用户已确认环境可用)
  if [ -n "$ENGINE_ARG" ]; then
    if command -v "$ENGINE_ARG" >/dev/null 2>&1; then
      echo "$ENGINE_ARG"; return
    else
      echo "错误: 未找到引擎 '$ENGINE_ARG'(请检查 Amber 安装或路径)"; exit 1
    fi
  fi
  # 2) 环境变量 PMEMD_ENGINE
  if [ -n "${PMEMD_ENGINE:-}" ]; then
    if command -v "$PMEMD_ENGINE" >/dev/null 2>&1; then
      echo "$PMEMD_ENGINE"; return
    else
      echo "错误: 未找到引擎 '\$PMEMD_ENGINE' = '$PMEMD_ENGINE'(请检查 Amber 安装或路径)"; exit 1
    fi
  fi
  # 3) 自动探测(WSL 环境安全回退)
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
echo "==> 引擎: $ENGINE  体系: $SYS"

# ---------- 前置检查 ----------
[ -f step3_input.parm7 ] || { echo "错误: 缺 step3_input.parm7(请在 amber 产物目录内运行)"; exit 1; }
[ -f step3_input.rst7  ] || { echo "错误: 缺 step3_input.rst7(请在 amber 产物目录内运行)"; exit 1; }

# ---------- 平衡流程 ----------
# 对齐极小化(确定性, 云端/本地同步分界点)
[ -f dihe.restraint ] && sed -e "s/FC/1.0/g" dihe.restraint > dihe_FC1.rest
echo "==> [1/5] 对齐极小化 (align_min, 5000 步)"
$ENGINE -O -i align_min_uncleaved_v01.mdin -p step3_input.parm7 -c step3_input.rst7 \
        -o align_min.mdout -r align_min.rst7 -ref step3_input.rst7
echo "    完成: align_min.rst7   最终能量见 align_min.mdout 尾部(与云侧核验)"

# EQ1 NVT 升温 310K, posres 2.0 + 糖二面角
echo "==> [2/5] EQ1 NVT 升温 (100 ps)"
$ENGINE -O -i eq1_nvt_uncleaved_v01.mdin -p step3_input.parm7 -c align_min.rst7 \
        -o eq1_nvt.mdout -r eq1_nvt.rst7 -ref align_min.rst7 -x eq1_nvt.nc

# EQ2 NPT posres 1.0
echo "==> [3/5] EQ2 NPT (200 ps)"
$ENGINE -O -i eq2_npt_uncleaved_v01.mdin -p step3_input.parm7 -c eq1_nvt.rst7 \
        -o eq2_npt.mdout -r eq2_npt.rst7 -ref align_min.rst7 -x eq2_npt.nc

# EQ3 NPT posres 0.5
echo "==> [4/5] EQ3 NPT (200 ps)"
$ENGINE -O -i eq3_npt_uncleaved_v01.mdin -p step3_input.parm7 -c eq2_npt.rst7 \
        -o eq3_npt.mdout -r eq3_npt.rst7 -ref align_min.rst7 -x eq3_npt.nc

# EQ4 NPT 无 posres(糖二面角仍在)
echo "==> [5/5] EQ4 NPT 自由平衡 (500 ps)"
$ENGINE -O -i eq4_npt_uncleaved_v01.mdin -p step3_input.parm7 -c eq3_npt.rst7 \
        -o eq4_npt.mdout -r eq4_npt.rst7 -x eq4_npt.nc

if [ "$DO_EQ5" = "1" ]; then
    echo "==> [可选] EQ5 NPT 无约束稳定性检验 (500 ps)"
    $ENGINE -O -i eq5_npt_uncleaved_v01.mdin -p step3_input.parm7 -c eq4_npt.rst7 \
            -o eq5_npt.mdout -r eq5_npt.rst7 -x eq5_npt.nc
fi

echo
echo "平衡段完成。产物:"
echo "  分界结构  align_min.rst7       (与云侧核验点)"
echo "  平衡末态  eq4_npt.rst7/.nc     (SMD 生产起点)"
[ "$DO_EQ5" = "1" ] && echo "  稳定性    eq5_npt.rst7/.nc"
echo
echo "下一步:"
echo "  (1) 把 align_min.mdout 尾部最终能量报给云侧核验"
echo "  (2) 核验通过后:  bash run_smd_uncleaved_v03.sh [--engine=引擎]"
