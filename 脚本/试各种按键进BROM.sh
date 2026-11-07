#!/usr/bin/env bash
# 逼 BROM：三轮按键组合，全程记录插线瞬间是否产生任何 USB 设备
# 用法：bash ~/TB310FU-启天K9/brom-try.sh
set -uo pipefail

snap() { lsusb | sed -E 's/^Bus [0-9]+ Device [0-9]+: ID //' | sort; }
BASE=$(snap)

try_round() {
  local name="$1" hint="$2"
  echo
  echo "──────── 第 $name 轮 ────────"
  echo "  操作：拔掉线 → $hint → 插上 USB → 保持 5 秒再松手"
  echo "  监听 45 秒，现在开始..."
  local hit=""
  for i in $(seq 1 90); do
    local now; now=$(snap)
    local new; new=$(comm -13 <(echo "$BASE") <(echo "$now") 2>/dev/null | grep -v "root hub" || true)
    if [ -n "$new" ]; then
      echo "  [$(date +%H:%M:%S)] 抓到新设备："
      echo "$new" | sed 's/^/      /'
      hit=1
      case "$new" in
        *0e8d:0003*) echo "  ★ 是 BROM！机器活着，可以刷。"; return 0 ;;
        *0e8d:*)     echo "  ★ 联发科设备（非标准 BROM 模式），也可能可刷。"; return 0 ;;
        *18d1:*)     echo "  ★ 进 Android 系统了！adb/fastboot 可用。"; return 0 ;;
      esac
      BASE="$now"
    fi
    sleep 0.5
  done
  [ -z "$hit" ] && echo "  ✘ 45 秒内没有任何 USB 设备出现"
  return 1
}

echo "=== 逼 BROM 诊断 ==="
echo "开始前请确认：平板已拔线、处于关机或黑屏状态"
read -r -p "按回车开始..." _

try_round 1 "按住【音量 +】不放" && exit 0
try_round 2 "按住【音量 -】不放" && exit 0
try_round 3 "同时按住【音量 + 和 音量 -】不放" && exit 0
try_round 4 "同时按住【电源 + 音量 +】不放" && exit 0

cat <<'TIP'

────────────────────────────────────────
四轮全部没有任何 USB 设备出现。

结论：这不是软件状态问题，是硬件层没上电。
按键、线、BROM 都试过了，电脑连"看到一个设备"的反应都没有。

下一步只有两条：
  A. 换一根确定能传数据的线 + 换电脑另一个 USB 口，再跑一次本脚本
  B. 拆后盖，断开电池排线 30 秒再插回（详见前面的拆机步骤）

刷机这条路在设备被认到之前是走不通的——不是命令写错，是物理上没连通。
────────────────────────────────────────
TIP
