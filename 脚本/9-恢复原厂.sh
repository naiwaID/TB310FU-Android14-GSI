#!/usr/bin/env bash
# 应急：把 2-备份分区.sh 备份的分区写回去（刷坏了用）
# 用法：bash ~/TB310FU-启天K9/9-恢复原厂.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE/mtkclient"
B="$HERE/备份"
PY="$HERE/venv/bin/python"

[ -d "$B" ] || { echo "!! 没有备份目录 $B"; exit 1; }
ls "$B"/*.img >/dev/null 2>&1 || { echo "!! 备份目录里没有 .img"; exit 1; }

echo "将写回以下分区："
ls "$B"/*.img | xargs -n1 basename | tr '\n' ' '; echo
read -r -p "平板关机 → 按住音量+ → 插 USB。确认后按回车..." _

for f in "$B"/*.img; do
  p="$(basename "$f" .img)"
  printf "  %-16s" "$p"
  if "$PY" mtk.py w "$p" "$f" >/dev/null 2>&1; then echo OK; else echo FAIL; fi
done

"$PY" mtk.py reset || true
echo "写回结束。若仍无法开机，改用 5-下载镜像.sh rom 下官方固件整包写回。"
