#!/usr/bin/env bash
# 反复抓 BROM：mtkclient 会一直等待，你在它等待期间反复插拔线，撞上那"偶尔上电"的一秒
# 用法：bash ~/TB310FU-启天K9/catch-brom.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
PY="$HERE/venv/bin/python"
PL="$HERE/备份/preloader.bin"
LOG="$HERE/备份/catch-$(date +%H%M).log"
cd "$HERE/mtkclient"

[ -s "$PL" ] || { echo "!! 缺 preloader 备份"; exit 1; }
echo "日志：$LOG"
echo

for i in $(seq 1 30); do
  # 三种按键轮着来，每轮换一个
  case $((i % 3)) in
    1) KEYTIP="按住【音量 −】"; KEYNAME=音量− ;;
    2) KEYTIP="按住【音量 +】"; KEYNAME=音量+ ;;
    0) KEYTIP="同时按住【音量 + 和 音量 −】"; KEYNAME=双键 ;;
  esac
  echo "──────── 第 $i 次（$KEYNAME）────────"
  echo "  现在：拔线 → $KEYTIP → 插线 → 松手（等 8 秒没反应就拔掉重来）"

  timeout 30 "$PY" mtk.py printgpt --preloader "$PL" 2>&1 | tee -a "$LOG" \
    | grep -E "Partition|partition|Handshake|Error|error|Waiting|Found|DRAM|da" | tail -6

  if grep -qE "^[a-zA-Z0-9_]+: +Offset 0x" "$LOG" 2>/dev/null; then
    echo
    echo "★★★ 抓到了！分区表已读出，设备活着 ★★★"
    echo "接着跑：bash ~/TB310FU-启天K9/2-备份分区.sh"
    exit 0
  fi
  echo "  这次没成功，继续下一次"
done

cat <<'TIP'

✘ 20 次都没抓到。
说明它连"偶尔上电"都做不到了 —— 供电/电池这一环真的断了。
到这里，软件侧彻底没戏，剩下只有：
  · 拆后盖断电池排线（详见 设备资料.md）
  · 或送修："断开电池排线断电 30 秒，不要刷机"
TIP
