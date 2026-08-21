#!/bin/bash
# pack_migration.sh — 迁移打包
#
# 用途: 把当前工作区打成自含快照(含 MANIFEST.md 状态快照), 供其他 agent / 其他主机接手。
#       包内不包含 GB 级模拟数据(那部分在 GitHub 仓库与用户本地 amber/ 目录, 通过引用追踪)。
#
# 用法:  bash scripts/pack_migration.sh            # 生成 Cprime_migration_YYYYMMDD.tar.gz + SHA256SUMS
#        bash scripts/pack_migration.sh --dry-run  # 只打印将打包的文件清单, 不生成包
#
# 包结构:  tar.gz = 当前 workspace 全量快照 (排除自身输出与 SHA256SUMS)
# 接手方:  解包 → 读 README.md + MANIFEST.md → 按 MANIFEST 的"当前进度/下一步"继续。
set -euo pipefail

WS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATE="$(date +%Y%m%d)"
OUT="$WS_ROOT/Cprime_migration_${DATE}.tar.gz"
# 先写到工作区外的临时目录, 再移入 —— 避免 tar 输出落在被归档目录内导致
# "file changed as we read it"
TMPOUT="$(mktemp /tmp/Cprime_migration_XXXXXX.tar.gz)"
trap 'rm -f "$TMPOUT"' EXIT

if [ ! -f "$WS_ROOT/MANIFEST.md" ]; then
  echo "错误: 缺 $WS_ROOT/MANIFEST.md —— 迁移包必须含当前状态快照, 请先生成。" >&2
  exit 1
fi

if [ "${1:-}" = "--dry-run" ]; then
  echo "将打包以下内容 (共 $(find "$WS_ROOT" -type f | wc -l) 个文件):"
  find "$WS_ROOT" -type f -not -name "Cprime_migration_*.tar.gz" -not -name SHA256SUMS | sed "s|$WS_ROOT/||"
  exit 0
fi

cd "$WS_ROOT"
tar -czf "$TMPOUT" \
    --exclude="Cprime_migration_*.tar.gz" \
    --exclude="SHA256SUMS" \
    .
mv "$TMPOUT" "$OUT"
trap - EXIT

# 双写 SHA-256: 单行(供 grep) + 详细清单
{
  echo "# SHA-256 checksums — $(basename "$OUT") — 由 scripts/pack_migration.sh 生成 $(date '+%Y-%m-%d %H:%M')"
  sha256sum "$(basename "$OUT")"
} > "$WS_ROOT/SHA256SUMS"

echo "== 迁移包已生成 =="
echo "  包:        $OUT"
echo "  大小:      $(stat -c%s "$OUT") bytes"
echo "  SHA-256:   $(awk '/^[0-9a-f]/{print $1; exit}' "$WS_ROOT/SHA256SUMS")"
echo ""
echo "  接手方:  tar xzf $(basename "$OUT") → 读 README.md + MANIFEST.md"
