#!/bin/bash
# pack_migration.sh — 迁移打包(按需生成)
#
# 用途: 把【当前工作体系】(不含 history/ 只读历史区)打成自含快照, 供其他 agent / 主机接手。
#       包内不包含 GB 级模拟数据(那部分仅在用户本地 simulations/ 目录, 通过引用追踪)。
#
# 用法:  bash scripts/pack_migration.sh            # 生成 Cprime_migration_YYYYMMDD.tar.gz + 同名 .SHA256SUMS
#        bash scripts/pack_migration.sh --dry-run  # 只打印将打包的文件清单, 不生成包
#
# 包结构:  tar.gz = workspace 当前工作体系全量快照(排除 history/、自身输出与 SHA256SUMS)
# 接手方:  解包 → 读 README.md + PROGRESS.md + NODES.md → 按 PROGRESS.md 的"下一步"继续。
set -euo pipefail

WS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATE="$(date +%Y%m%d)"
OUT="$WS_ROOT/Cprime_migration_${DATE}.tar.gz"
CHECKSUM_OUT="$WS_ROOT/Cprime_migration_${DATE}.SHA256SUMS"
# 先写到工作区外的临时目录, 再移入 —— 避免 tar 输出落在被归档目录内导致
# "file changed as we read it"
TMPOUT="$(mktemp /tmp/Cprime_migration_XXXXXX.tar.gz)"
trap 'rm -f "$TMPOUT"' EXIT

# 顶层状态文件: 迁移包必须含当前状态, 否则拒绝打包
for f in README.md PROGRESS.md NODES.md; do
  if [ ! -f "$WS_ROOT/$f" ]; then
    echo "错误: 缺 $WS_ROOT/$f —— 迁移包必须含当前状态快照, 请先生成。" >&2
    exit 1
  fi
done

# 打包排除项(与 tar 调用保持同集): history 只读历史区和所有本地运行区不参与迁移包
EXCLUDES=(
  --exclude="Cprime_migration_*.tar.gz"
  --exclude="Cprime_migration_*.SHA256SUMS"
  --exclude="./SHA256SUMS"
  --exclude="./history"
  --exclude="./simulations"
  --exclude="./work"
  --exclude="./临时文件存放"
  --exclude="./.git"
  --exclude="__pycache__"
  --exclude="*.pyc"
)

if [ "${1:-}" = "--dry-run" ]; then
  n="$(find "$WS_ROOT" -type f \
        -not -path "$WS_ROOT/history/*" \
        -not -path "$WS_ROOT/simulations/*" -not -path "$WS_ROOT/work/*" \
        -not -path "$WS_ROOT/临时文件存放/*" -not -path "$WS_ROOT/.git" -not -path "$WS_ROOT/.git/*" \
        -not -path "$WS_ROOT/SHA256SUMS" \
        -not -name "Cprime_migration_*.tar.gz" -not -name "Cprime_migration_*.SHA256SUMS" | wc -l)"
  echo "将打包以下内容(不含 history/ 只读历史区; 共 $n 个文件):"
  find "$WS_ROOT" -type f \
       -not -path "$WS_ROOT/history/*" \
       -not -path "$WS_ROOT/simulations/*" -not -path "$WS_ROOT/work/*" \
       -not -path "$WS_ROOT/临时文件存放/*" -not -path "$WS_ROOT/.git" -not -path "$WS_ROOT/.git/*" \
       -not -path "$WS_ROOT/SHA256SUMS" \
       -not -name "Cprime_migration_*.tar.gz" -not -name "Cprime_migration_*.SHA256SUMS" | sed "s|$WS_ROOT/||"
  exit 0
fi

cd "$WS_ROOT"
tar -czf "$TMPOUT" "${EXCLUDES[@]}" .
mv "$TMPOUT" "$OUT"
trap - EXIT

# 为迁移包单独写校验文件，不覆盖仓库根 SHA256SUMS。
{
  echo "# SHA-256 checksums — $(basename "$OUT") — 由 scripts/pack_migration.sh 生成 $(date '+%Y-%m-%d %H:%M')"
  sha256sum "$(basename "$OUT")"
} > "$CHECKSUM_OUT"

echo "== 迁移包已生成(不含 history/ 只读历史区)=="
echo "  包:        $OUT"
echo "  大小:      $(stat -c%s "$OUT") bytes"
echo "  SHA-256:   $(awk '/^[0-9a-f]/{print $1; exit}' "$CHECKSUM_OUT")"
echo ""
echo "  接手方:  tar xzf $(basename "$OUT") → 读 README.md + PROGRESS.md + NODES.md"
