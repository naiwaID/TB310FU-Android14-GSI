#!/usr/bin/env bash
# 一眼看平板现在是什么状态（随时可跑，只读）
# 用法：bash ~/TB310FU-启天K9/查看设备状态.sh          看当前状态（瞬间返回）
#       bash ~/TB310FU-启天K9/查看设备状态.sh wait     等 120 秒，一出现设备就报告
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"

if [ "${1:-}" = "wait" ]; then
  echo "等待平板出现在 USB 上（最多 120 秒）..."
  echo "插线前先按住【音量 −】不松（不行就换【音量 +】，或两个一起按）"
  echo "Type-C 接平板，A 头接电脑后置口；看到这里报告出现设备后再松手"
  for i in $(seq 1 240); do
    for d in /sys/bus/usb/devices/*/; do
      v=$(cat "$d/idVendor" 2>/dev/null || true)
      if [ "$v" = "0e8d" ]; then
        p=$(cat "$d/idProduct" 2>/dev/null || true)
        echo
        echo "✔ [$(date +%H:%M:%S)] 出现 0e8d:$p"
        [ "$p" = "0003" ] && echo "  → BROM 模式，可以刷机！接着跑：bash ~/TB310FU-启天K9/brom-preloader.sh"
        exit 0
      fi
      if [ "$v" = "18d1" ]; then
        echo
        echo "✔ [$(date +%H:%M:%S)] 出现 Android 设备 18d1，系统起来了"
        exit 0
      fi
    done
    sleep 0.5
  done
  echo "✘ 120 秒内没有设备出现"
  exit 1
fi

echo "== 1. USB 层 =="
FOUND=0
for d in /sys/bus/usb/devices/*/; do
  v=$(cat "$d/idVendor" 2>/dev/null || true)
  [ -z "$v" ] && continue
  p=$(cat "$d/idProduct" 2>/dev/null || true)
  case "$v" in
    0e8d) FOUND=1
          case "$p" in
            0003) echo "  ✔ 0e8d:0003  BROM 下载模式 —— 能救，能刷" ;;
            2000) echo "  ✔ 0e8d:2000  Preloader —— 能救" ;;
            *)    echo "  ✔ 0e8d:$p  联发科设备（非标准模式）" ;;
          esac ;;
    18d1) FOUND=1; echo "  ✔ 18d1:$p  Android fastboot/adb 模式" ;;
  esac
done
[ $FOUND -eq 0 ] && echo "  ✘ 没有任何 MTK / Android 设备 → 没插线，或没供电"

echo
echo "== 2. fastboot =="
if command -v fastboot >/dev/null; then
  OUT=$(fastboot devices 2>/dev/null)
  [ -n "$OUT" ] && echo "$OUT" || echo "  无"
else
  echo "  未安装 android-tools"
fi

echo
echo "== 3. adb =="
if command -v adb >/dev/null; then
  OUT=$(adb devices 2>/dev/null | grep -v "List of devices")
  [ -n "$OUT" ] && echo "$OUT" || echo "  无"
else
  echo "  未安装 android-tools"
fi

echo
echo "== 4. 本机准备情况 =="
[ -s "$HERE/镜像/gsi/gsi.img" ] && echo "  镜像: $(du -h "$HERE/镜像/gsi/gsi.img" | cut -f1) 就绪" || echo "  镜像: 缺失"
echo "  备份: $(ls "$HERE/备份"/*.img 2>/dev/null | wc -l) 个分区文件"
echo "  mtkclient: $([ -d "$HERE/mtkclient" ] && echo 就绪 || echo 缺失)"
