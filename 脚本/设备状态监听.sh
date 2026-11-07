#!/usr/bin/env bash
# 常驻监听：一直盯着 USB，状态变化就打印一行（不会刷屏）
# 用法：bash ~/TB310FU-启天K9/设备状态监听.sh
# 退出：Ctrl+C
set -uo pipefail
LAST=""
START=$(date +%s)

state() {
  local s=""
  for d in /sys/bus/usb/devices/*/; do
    local v p
    v=$(cat "$d/idVendor" 2>/dev/null || true)
    p=$(cat "$d/idProduct" 2>/dev/null || true)
    case "$v" in
      0e8d) case "$p" in
              0003) s="BROM 0e8d:0003（可读写分区）" ;;
              2000) s="Preloader 0e8d:2000" ;;
              *)    s="MTK 0e8d:$p" ;;
            esac ;;
      18d1) case "$p" in
              4ee0) s="fastboot 18d1:4ee0（可刷机）" ;;
              4ee1|4ee2) s="adb 18d1:$p（系统已起）" ;;
              *)    s="Android 18d1:$p" ;;
            esac ;;
    esac
    [ -n "$s" ] && { echo "$s"; return; }
  done
  echo "无设备"
}

echo "常驻监听中（Ctrl+C 退出）——只在状态变化时打印"
while :; do
  S=$(state)
  if [ "$S" != "$LAST" ]; then
    printf "[%s +%3ds] %s\n" "$(date +%H:%M:%S)" "$(( $(date +%s) - START ))" "$S"
    LAST="$S"
  fi
  sleep 1
done
