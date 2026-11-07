#!/usr/bin/env bash
# 全自动：等 BROM → 备份+解锁 → 等 fastboot → 刷机
# 用法：bash ~/TB310FU-启天K9/全自动流程.sh
# 前提：V− 已用鳄鱼夹/杜邦线常接 GND（省掉一直按住的动作）
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE/mtkclient" || exit 1
PY="$HERE/venv/bin/python"
B="$HERE/备份"
mkdir -p "$B"

wait_usb() { # 只认 BROM(0003)，preloader(2000) 会提示并继续等
  local t=0
  echo "[$(date +%H:%M:%S)] 等待 BROM（插 USB，按住 V+ 或短接 V+ 到 GND）..."
  while :; do
    for d in /sys/bus/usb/devices/*/; do
      local v p
      v=$(cat "$d/idVendor" 2>/dev/null || true)
      [ "$v" = "0e8d" ] || continue
      p=$(cat "$d/idProduct" 2>/dev/null || true)
      if [ "$p" = "0003" ]; then
        echo
        echo "[$(date +%H:%M:%S)] 抓到 BROM 0e8d:0003 ✔"
        sleep 0.4
        return 0
      fi
      if [ "$p" = "2000" ]; then
        echo
        echo "[$(date +%H:%M:%S)] 是 Preloader(2000)，DAA 会拦，不能用于 mtkclient"
        echo "   → 拔线，改按【音量 +】（或把短接线从 V− 换到 V+）再插"
      fi
    done
    printf "\r  等待 BROM… %3ds" "$t"
    sleep 1
    t=$((t+1))
  done
}

wait_fastboot() {
  local t=0
  echo "[$(date +%H:%M:%S)] 等待 fastboot（V− 已接地，点一下 PWRK 即可）..."
  while :; do
    if fastboot devices 2>/dev/null | grep -q .; then
      echo "[$(date +%H:%M:%S)] fastboot 就绪"
      return 0
    fi
    printf "\r  等待 fastboot… %3ds" "$t"
    sleep 1
    t=$((t+1))
  done
}

# ---------- 阶段 1：BROM：备份 + 解锁 ----------
wait_usb

echo
"$PY" mtk.py printgpt
"$PY" mtk.py r preloader "$B/preloader.bin" --parttype boot1
for p in vbmeta_a vbmeta_b vbmeta_system_a vbmeta_vendor_a boot_a boot_b \
         nvram nvdata nvcfg persist seccfg proinfo; do
  "$PY" mtk.py r "$p" "$B/$p.img"
done

echo
echo "[$(date +%H:%M:%S)] 解锁 + 关校验 + 清数据"
"$PY" mtk.py multi "da seccfg unlock;e metadata,userdata,md_udc;da vbmeta 3;reset"

# ---------- 阶段 2：fastboot：刷机 ----------
wait_fastboot
echo
exec bash "$HERE/4-刷入系统.sh"
