#!/usr/bin/env bash
# 用 mtkclient 在 BROM 里直接擦 data（绕过 fastbootd，最可靠）
# 用法：bash ~/TB310FU-启天K9/BROM擦除数据.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE/mtkclient" || exit 1
PY="$HERE/venv/bin/python"

echo "════ 在 BROM 里擦除 data ════"
echo "要擦的分区: userdata, metadata, cache"
echo
echo "现在做："
echo "  1. 红+绿 保持 15 秒        → 强制关机（屏幕黑）"
echo "  2. 拔掉 USB 线"
echo "  3. 红+黄 保持不放          → V+ 接地（黄线必须接黄，橙线不行！）"
echo "  4. 插 USB 线，继续按住黄线"
echo "  5. 看到日志再松手"
echo
echo "等 BROM（只认 0e8d:0003）："
n=0
while :; do
  pid=$(cat /sys/bus/usb/devices/1-1/idProduct 2>/dev/null || true)
  if [ "$pid" = "0003" ]; then
    echo "[$(date +%H:%M:%S)] 抓到 BROM 0e8d:0003 ✔"
    break
  fi
  [ -n "$pid" ] && [ "$pid" != "0003" ] && printf "\r  当前 USB=%s（不是 BROM，黄线接对了吗？）%3ds  " "$pid" "$((n*2))"
  [ -z "$pid" ] && printf "\r  等待设备上电… %3ds  " "$((n*2))"
  n=$((n+1)); sleep 2
done
echo
echo

echo "== 擦除 data =="
"$PY" mtk.py e userdata,metadata,cache 2>&1 | tail -20

echo
echo "== 重启 =="
"$PY" mtk.py reset 2>&1 | tail -5

echo
echo "✔ 完成。拔掉 USB，松开黄线，等 30 秒后按绿+红开机"
echo "  开机后如果还卡 logo，再跑：bash ~/TB310FU-启天K9/重装系统.sh（但要走 fastboot 刷 system）"
