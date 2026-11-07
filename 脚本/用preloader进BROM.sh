#!/usr/bin/env bash
# 设备一旦能在 USB 上出现，用备份的 preloader 手动喂给 mtkclient
# 适用场景：printgpt 报 "No emmc info" / 握手失败 / 自动读 preloader 失败
# 用法：bash ~/TB310FU-启天K9/brom-preloader.sh [down|up|both]
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
PY="$HERE/venv/bin/python"
PL="$HERE/备份/preloader.bin"

[ -s "$PL" ] || { echo "!! 找不到 $PL（preloader 备份）"; exit 1; }
echo "使用 preloader: $PL  ($(stat -c%s "$PL") B)"
echo
KEYNAME="${1:-}"
case "$KEYNAME" in
  down) KEYTIP="按住【音量 −】" ;;
  both) KEYTIP="同时按住【音量 + 和 音量 −】" ;;
  up)   KEYTIP="按住【音量 +】" ;;
  *)    KEYTIP="按住【音量 −】（不行就换音量 + ，或两个一起按）" ;;
esac
echo "== 现在做：平板关机 → $KEYTIP → 插 USB =="
read -r -p "按回车立即开始等待设备..." _

cd "$HERE/mtkclient"
echo "== 尝试 1：用备份 preloader 读分区表 =="
"$PY" mtk.py printgpt --preloader "$PL" && {
  echo "✔ 通了，可以正常备份/刷机"; exit 0; }

echo
echo "== 尝试 2：先 crash 到 BROM，再读 =="
"$PY" mtk.py crash 2>/dev/null | tail -3
"$PY" mtk.py printgpt --preloader "$PL" && {
  echo "✔ 通了"; exit 0; }

echo
echo "== 尝试 3：不带参数，交给自动检测 =="
"$PY" mtk.py printgpt && { echo "✔ 通了"; exit 0; }

cat <<'TIP'
✘ 三种都失败。说明 BROM 层面没握手成功，不是命令问题。

下一步（按顺序）：
  1. 换线、换电脑后置 USB 口，再跑一次
  2. 自制深刷线：D+ 与 GND 之间串 1kΩ 电阻（详见 设备资料.md）
  3. 开壳短接 BROM_DL_KEY 测试点
TIP
