#!/usr/bin/env bash
# 彻底重装：清 data + 重刷 system（GSI），修开机卡 logo
# 用法：bash ~/TB310FU-启天K9/脚本/重装系统.sh
#       进 fastboot 的操作由人来做，脚本只负责等和刷
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
IMG="${1:-$HERE/镜像/gsi/gsi.img}"
[ -f "$IMG" ] || { echo "!! 镜像不存在: $IMG"; exit 1; }

fb() { timeout 20 fastboot "$@" 2>&1 | tr -d '\r'; }

echo "════ 彻底重装 GSI ════"
echo "镜像: $IMG  ($(du -h "$IMG" | cut -f1))"
echo
echo "现在做（手上动作）："
echo "  1. 红+绿 保持 15 秒    → 强制关机（屏幕黑）"
echo "  2. 松手等 3 秒"
echo "  3. 红+橙 保持不放      → V− 接地"
echo "  4. 红+绿 碰 1 秒松开   → 出现 START 菜单"
echo "  5. 橙线碰一下          → Volume Down 进 Fastboot"
echo
echo "我不按 Ctrl+C，一直等你。"
echo

# ---------- 1. 等 fastboot ----------
n=0
while :; do
  if [ -n "$(timeout 3 fastboot devices 2>/dev/null | tr -d '\r' | grep -v '^$')" ]; then
    echo "[$(date +%H:%M:%S)] 抓到 fastboot 设备"; break
  fi
  n=$((n+1)); printf "\r  等待 fastboot… %3ds  " "$((n*2))"; sleep 2
done
echo
fastboot devices 2>&1 | tr -d '\r'

# ---------- 2. 判断在 bootloader 还是 fastbootd ----------
mode=$(fb getvar is-userspace 2>/dev/null | grep -oE "yes|no" | head -1)
echo "当前模式: is-userspace=$mode  ($([ "$mode" = yes ] && echo fastbootd || echo bootloader))"

# ---------- 3. bootloader 阶段：清 data ----------
if [ "$mode" != "yes" ]; then
  echo
  echo "== 清数据（bootloader 阶段）=="
  for p in userdata metadata cache; do
    printf "  erase %-10s " "$p"
    r=$(fb erase "$p" | tail -1)
    echo "${r:-（无输出）}"
  done
  echo
  echo "== 进 fastbootd =="
  fb reboot fastboot
  sleep 8
  n=0
  while :; do
    if [ -n "$(timeout 3 fastboot devices 2>/dev/null | tr -d '\r' | grep -v '^$')" ]; then
      m2=$(fb getvar is-userspace 2>/dev/null | grep -oE "yes|no" | head -1)
      [ "$m2" = "yes" ] && { echo "[$(date +%H:%M:%S)] 已进入 fastbootd"; break; }
    fi
    n=$((n+1)); printf "\r  等待 fastbootd… %3ds  " "$((n*2))"; sleep 2
  done
  echo
fi

# ---------- 4. 刷 system ----------
echo
echo "== 写入 system（约 2~4 分钟，别碰板子）=="
fb flash system "$IMG"
echo

# ---------- 5. 确认并重启 ----------
echo "== 确认写入 =="
fb getvar partition-size:system 2>/dev/null | head -1
echo
echo "== 重启 =="
fb reboot
echo
echo "✔ 重装完成。首次开机 5~10 分钟，屏幕转圈是正常的。"
echo "  起来之后跑：bash ~/TB310FU-启天K9/横屏切换.sh land "
