#!/bin/bash
# ============================================================================
# launch_all_replicas_cleaved_v01.sh — 4×4090 工作站: 并行启动 4 个副本(cleaved 体系)
#
# 用法(在 CHARMM-GUI amber/ 目录内):
#   bash launch_all_replicas_cleaved_v01.sh <N> [--engine=pmemd.cuda] [--smd-speed 1|5]
#   例: bash launch_all_replicas_cleaved_v01.sh 4 --engine=pmemd.cuda --smd-speed 1
#       → 并行创建并运行 amber_r01..amber_r04, 依次独占 GPU 0..3
#
# 前置: 同 run_replica_cleaved_v01.sh(见其文件头); N ≤ 4(卡数)。
# ============================================================================
set -euo pipefail
SYS="cleaved"; N="${1:-}"; shift 1 || true
echo "$N" | grep -qE '^[0-9]+$' || { echo "错误: N 需为副本数(≤4)"; exit 1; }
[ "$N" -ge 1 ] && [ "$N" -le 4 ] || { echo "错误: N 需在 1–4 之间(4×4090)"; exit 1; }

ENGINE_ARG=""; SPEED="1"
for a in "$@"; do
  case "$a" in
    --engine=*)  ENGINE_ARG="${a#--engine=}" ;;
    --smd-speed) shift; SPEED="$1" ;;
    --smd-speed=*) SPEED="${a#--smd-speed=}" ;;
    *) echo "未知参数: $a"; exit 1 ;;
  esac
done

echo "==> 启动 $N 个副本(体系 $SYS, 引擎 ${ENGINE_ARG:-自动}, 拉速 ${SPEED} Å/ns):"
for ((r=1; r<=N; r++)); do
  g=$((r-1))
  log="replica_r$(printf '%02d' "$r").log"
  echo "    [GPU $g] 副本 $r → nohup bash run_replica_cleaved_v01.sh $r --engine=${ENGINE_ARG} --smd-speed=${SPEED} --gpu $g > $log 2>&1 &"
  nohup bash run_replica_cleaved_v01.sh "$r" --engine="${ENGINE_ARG}" --smd-speed="$SPEED" --gpu="$g" > "$log" 2>&1 &
done
echo "==> 已全部后台启动。跟踪: tail -f replica_r01.log (各副本各有独立日志)"
echo "==> 完成判定: 每个副本目录 amber_rNN/ 出现 smd.out 且末段 mdout 含 'Final Performance Info:'。"
