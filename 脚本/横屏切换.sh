#!/usr/bin/env bash
# 平板屏幕方向锁定（TB310FU / Evolution X GSI）
# 用法：
#   bash ~/TB310FU-启天K9/横屏切换.sh land    锁定横屏（默认）
#   bash ~/TB310FU-启天K9/横屏切换.sh flip    横屏反向（画面上下颠倒时用）
#   bash ~/TB310FU-启天K9/横屏切换.sh port    锁定竖屏
#   bash ~/TB310FU-启天K9/横屏切换.sh soft    横屏但不强制应用（某个 app 界面错乱时用）
#   bash ~/TB310FU-启天K9/横屏切换.sh auto    恢复重力感应自动旋转
#   bash ~/TB310FU-启天K9/横屏切换.sh show    只看当前状态
set -uo pipefail

need_adb() {
  if ! adb devices 2>/dev/null | grep -q "device$"; then
    echo "!! 没连上平板：插 USB、开 USB 调试"; exit 1
  fi
}

case "${1:-land}" in
  land)
    need_adb
    adb shell settings put system accelerometer_rotation 0
    adb shell settings put system user_rotation 1
    adb shell wm user-rotation lock 1        # 关键：必须 lock，否则 app 会改回 free
    adb shell wm fixed-to-user-rotation enabled >/dev/null 2>&1
    echo "✔ 已锁定横屏（含强制所有应用跟随）"
    ;;
  flip)
    need_adb
    adb shell settings put system accelerometer_rotation 0
    adb shell settings put system user_rotation 3
    adb shell wm user-rotation lock 3
    adb shell wm fixed-to-user-rotation enabled >/dev/null 2>&1
    echo "✔ 已锁定横屏反向（含强制所有应用跟随）"
    ;;
  port)
    need_adb
    adb shell settings put system accelerometer_rotation 0
    adb shell settings put system user_rotation 0
    adb shell wm user-rotation lock 0
    adb shell wm fixed-to-user-rotation enabled >/dev/null 2>&1
    echo "✔ 已锁定竖屏（含强制所有应用跟随）"
    ;;
  soft)
    need_adb
    adb shell settings put system accelerometer_rotation 0
    adb shell settings put system user_rotation 1
    adb shell wm user-rotation lock 1
    adb shell wm fixed-to-user-rotation default >/dev/null 2>&1
    echo "✔ 横屏，但不强制应用（竖屏锁定的 app 仍会竖着）"
    ;;
  auto)
    need_adb
    adb shell settings put system accelerometer_rotation 1
    adb shell settings delete system user_rotation >/dev/null 2>&1
    adb shell wm user-rotation free
    adb shell wm fixed-to-user-rotation default >/dev/null 2>&1
    echo "✔ 已恢复重力感应自动旋转"
    ;;
  show) ;;
  *)
    echo "用法: bash ~/TB310FU-启天K9/横屏切换.sh [land|flip|port|soft|auto|show]"; exit 1 ;;
esac

echo "--- 当前状态 ---"
printf "  %-22s %s\n" "自动旋转" "$(adb shell settings get system accelerometer_rotation | tr -d '\r')"
printf "  %-22s %s\n" "锁定角度" "$(adb shell settings get system user_rotation | tr -d '\r')"
adb exec-out screencap -p > /tmp/_rot.png 2>/dev/null
python3 -c "
import struct,sys
try:
    d=open('/tmp/_rot.png','rb').read()
    w,h=struct.unpack('>II',d[16:24])
    print(f'  {\"实际画面\":<18} {w}x{h}  →', '横屏' if w>h else '竖屏')
except Exception: pass" 2>/dev/null
rm -f /tmp/_rot.png
