#!/usr/bin/env bash
# 把整个项目归档到 2T 机械盘（/dev/sda1 → /mnt/lineage-out）
# 用法：bash ~/TB310FU-启天K9/to-hdd.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
MNT=/mnt/lineage-out
DEST="$MNT/TB310FU-刷机"

echo "== 1. 挂载 2T 机械盘 =="
if mountpoint -q "$MNT"; then
  echo "  已经挂载了"
else
  sudo mkdir -p "$MNT"
  sudo mount /dev/sda1 "$MNT" || { echo "!! 挂载失败，检查硬盘是否插好"; exit 1; }
  echo "  已挂载 /dev/sda1 → $MNT"
fi
df -h "$MNT" | tail -1

echo
echo "== 2. 复制到 $DEST =="
sudo mkdir -p "$DEST"
# 排除 venv（绝对路径依赖，换位置就失效，用交接说明里的命令重建）
sudo rsync -a --info=progress2 \
  --exclude 'venv/' \
  --exclude 'mtkclient/.git/' \
  --exclude 'backup/*.img' \
  "$HERE"/ "$DEST"/

echo
echo "== 3. 校验 =="
sudo du -sh "$DEST"
echo "  文件数：$(sudo find "$DEST" -type f | wc -l)"
sudo ls -1 "$DEST"

echo
echo "== 4. 卸载 =="
sync
sudo umount "$MNT" && echo "  已安全弹出"

cat <<TIP

✔ 归档完成：$DEST
  里面有一份 交接说明.md，隔多久翻出来都能按它接着做。

重新开始时：
  sudo mount /dev/sda1 /mnt/lineage-out
  cat "/mnt/lineage-out/TB310FU-刷机/交接说明.md"
TIP
