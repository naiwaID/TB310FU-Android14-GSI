#!/usr/bin/env bash
# 修复开机卡 logo（data 分区因突然断电损坏）
# 用法：
#   bash ~/TB310FU-启天K9/修复卡开机动画.sh          # 清 userdata + metadata + cache 后重启
#   bash ~/TB310FU-启天K9/修复卡开机动画.sh soft     # 只清 metadata + cache（尽量保数据）
#   bash ~/TB310FU-启天K9/修复卡开机动画.sh wait     # 只等 fastboot，不擦除
#
# 进 fastboot 的操作：
#   强制关机（红+绿 15 秒）→ 红+橙保持 + 红+绿碰 1 秒
#   → 屏幕出现 START 菜单 → 橙线碰一下（Volume Down）→ 进 Fastboot
set -uo pipefail
MODE="${1:-full}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

echo "════ 修复开机卡 logo ════"
echo "模式: $MODE"
echo
echo "现在做（手上动作）："
echo "  1. 红+绿 保持 15 秒 → 强制关机，屏幕黑"
echo "  2. 松手等 3 秒"
echo "  3. 红+橙 保持不放（V− 接地）"
echo "  4. 红+绿 碰 1 秒松开 → 应该出现 START 菜单"
echo "  5. 橙线碰一下 → Volume Down 进 Fastboot"
echo
echo "我在等 fastboot，进入后自动处理。别按 Ctrl+C。"
echo

n=0
while :; do
  out=$(timeout 3 fastboot devices 2>/dev/null | tr -d '\r' | grep -v '^$')
  if [ -n "$out" ]; then
    echo "[$(date +%H:%M:%S)] 抓到: $out"
    break
  fi
  n=$((n+1))
  printf "\r  等待 fastboot… %3ds  " "$((n*2))"
  sleep 2
done
echo

[ "$MODE" = "wait" ] && { echo "已连上，按 wait 模式不擦除，退出。"; exit 0; }

echo "== 当前状态 =="
fastboot getvar is-userspace 2>&1 | grep -v "^$" | tr -d '\r' | head -2
fastboot getvar product 2>&1 | tr -d '\r' | head -1

if [ "$MODE" = "soft" ]; then
  echo
  echo "== 只清 metadata / cache（保数据，先试这个）=="
  fastboot erase metadata 2>&1 | tr -d '\r'
  fastboot erase cache 2>&1 | tr -d '\r'
else
  echo
  echo "== 清 userdata（会丢应用和设置）=="
  fastboot -w 2>&1 | tr -d '\r' | tail -6
  # 上面若在 fastbootd 下报 not found，逐个擦
  echo "== 逐个擦（兜底）=="
  for p in userdata metadata cache; do
    printf "  %-10s " "$p"
    fastboot erase "$p" 2>&1 | tr -d '\r' | tail -1
  done
fi

echo
echo "== 重启 =="
fastboot reboot 2>&1 | tr -d '\r'
echo
echo "✔ 已完成。等待开机（首次 5~10 分钟，屏幕转圈是正常的）"
echo "  开机后检查："
echo "    adb devices"
echo "    bash ~/TB310FU-启天K9/横屏切换.sh land    # 重新设为横屏"
