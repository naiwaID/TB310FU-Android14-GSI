#!/usr/bin/env bash
# 等 fastboot 出现，然后自动开始刷机（插上就不用管了）
# 用法：bash ~/TB310FU-启天K9/flash-when-ready.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"

command -v fastboot >/dev/null || { echo "缺 fastboot，先装 android-tools"; exit 1; }
IMG="$HERE/镜像/gsi/gsi.img"
[ -f "$IMG" ] || { echo "缺镜像 $IMG"; exit 1; }

echo "等待 fastboot 设备（按住 音量− + 电源，插线）…"
echo "镜像：$IMG ($(du -h "$IMG" | cut -f1))"
T=0
while :; do
  if fastboot devices 2>/dev/null | grep -q .; then
    echo
    echo "[$(date +%H:%M:%S)] ✔ 检测到 fastboot 设备"
    fastboot devices
    break
  fi
  printf "\r  等待中… %3d 秒" "$T"
  sleep 1
  T=$((T+1))
done

echo
exec bash "$HERE/4-刷入系统.sh"
