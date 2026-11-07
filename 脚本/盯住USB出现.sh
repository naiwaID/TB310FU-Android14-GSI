#!/usr/bin/env bash
# 盯着 USB，判断平板当前是"活着"还是"没电/没复位"
# 用法：bash ~/TB310FU-启天K9/watch-mtk.sh
# 检测到 BROM(0e8d:0003) 时，会尝试发一次 reset 让 SoC 重启
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
PY="$HERE/venv/bin/python"

mode_of() {
  local p="$1"
  case "$p" in
    0003) echo "BROM（下载模式，可救）" ;;
    2000) echo "Preloader（预引导）" ;;
    201c|2001|201d) echo "DA / 元数据模式" ;;
    0dxx|0e00) echo "USB 串口（可能已进系统）" ;;
    *)    echo "未知模式 $p" ;;
  esac
}

echo "== 监测中，60 秒 ==="
echo "   动作：拔掉 USB → 长按电源 30 秒 → 插上 USB"
HIT=0
for i in $(seq 1 60); do
  for d in /sys/bus/usb/devices/*/; do
    v=$(cat "$d/idVendor" 2>/dev/null || true)
    [ "$v" = "0e8d" ] || continue
    p=$(cat "$d/idProduct" 2>/dev/null || true)
    echo "  [$(date +%H:%M:%S)] 发现 0e8d:$p → $(mode_of "$p")"
    HIT=1
    if [ "$p" = "0003" ]; then
      echo "  → 发 reset 让它重启 ..."
      cd "$HERE/mtkclient" && "$PY" mtk.py reset 2>&1 | tail -3
      echo "  → 之后应该会自动开机（或在 BROM 里等下一步）"
      exit 0
    fi
    exit 0
  done
  sleep 1
done

if [ $HIT -eq 0 ]; then
  cat <<'TIP'

✘ 60 秒内完全没有枚举出设备。按顺序做：

1) 拔掉 USB 线，别插充电器
2) 长按【电源键】30~40 秒（10 秒是没用的，MTK 要更久）
3) 还是黑屏：按住【电源 + 音量下】20 秒
4) 还没反应：接充电器放 30 分钟（电池可能触发了保护）
5) 再不行：插回电脑重跑本脚本，同时按【电源 + 音量上】

只要脚本能抓到 0e8d:0003，就说明机器没坏，能继续刷。
TIP
fi
