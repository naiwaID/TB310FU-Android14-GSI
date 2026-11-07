#!/usr/bin/env bash
# 一次搞定：读分区表 + 备份关键分区 + 解锁 BL + 关校验
# 用法：bash ~/TB310FU-启天K9/一键备份解锁.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE/mtkclient"
PY="$HERE/venv/bin/python"
B="$HERE/备份"
mkdir -p "$B"
GPT="$B/gpt-$(date +%m%d-%H%M%S).txt"

cat <<'TIP'
════════════════════════════════════════════════
 这一步会：读分区表 → 备份关键分区 → 解锁 BL → 清数据
 数据会被清空（学习系统、账号全部消失），确认后再继续。

 进入 BROM 的方式（任选）：
   · 按键：关机 → 按住【音量 −】→ 插 USB
   · 测试点：镊子短接 V− 与 GND 保持不放 → 插 USB
════════════════════════════════════════════════
TIP
read -r -p "输入 yes 开始，其它键退出： " a
[ "$a" = "yes" ] || { echo "已取消"; exit 1; }

echo
echo "════════ 现在开始自动检测，不限时 ════════"
echo "  1. 平板关机：镊子短接 PWRK 与 GND 保持 15 秒"
echo "  2. 镊子一头点 V−，一头点 GND，保持不放"
echo "  3. 插 USB（先按住再插），检测到会自动往下走"
echo

# ---- 自动检测：轮询 USB，抓到联发科设备就立即开始，最多等 10 分钟 ----
wait_for_device() {
  local t=0 limit=600
  while [ $t -lt $limit ]; do
    for d in /sys/bus/usb/devices/*/; do
      local v p
      v=$(cat "$d/idVendor" 2>/dev/null || true)
      [ "$v" = "0e8d" ] || continue
      p=$(cat "$d/idProduct" 2>/dev/null || true)
      printf "\r  已等待 %3d 秒 —— 抓到 0e8d:%s            \n" "$t" "$p"
      case "$p" in
        0003) echo "  → BROM 模式，可以读写" ;;
        2000) echo "  → Preloader 模式（也能用，握手可能要多试一次）" ;;
        *)    echo "  → 非标准模式，继续尝试" ;;
      esac
      sleep 0.5
      return 0
    done
    printf "\r  等待设备中… %3d 秒（按住 V− 并插好 USB）" "$t"
    sleep 0.5
    t=$((t+1))
  done
  printf "\n  ✘ 10 分钟没检测到设备，退出\n"
  return 1
}

wait_for_device || { echo "检查：电池是否接着、USB 是否插到位、V− 是否真的短到 GND"; exit 1; }

echo
echo "===== 1/4 读分区表 ====="
"$PY" mtk.py printgpt | tee "$GPT.tmp" | tail -3
mv -f "$GPT.tmp" "$GPT"

echo
echo "===== 2/4 备份关键分区 ====="
"$PY" mtk.py r preloader "$B/preloader.bin" --parttype boot1 >/dev/null 2>&1 \
  && echo "  preloader.bin OK" || echo "  preloader 跳过"

for p in vbmeta_a vbmeta_b vbmeta_system_a vbmeta_vendor_a boot_a boot_b \
         nvram nvdata nvcfg persist seccfg proinfo; do
  printf "  %-16s" "$p"
  if "$PY" mtk.py r "$p" "$B/$p.img" >/dev/null 2>&1 && [ -s "$B/$p.img" ]; then
    echo "OK  $(stat -c%s "$B/$p.img") B"
  else
    echo "- 跳过"; rm -f "$B/$p.img"
  fi
done

echo
echo "===== 3/4 校验备份 ====="
"$PY" - "$B" "$GPT" <<'PYEOF'
import re,os,sys
B,g=sys.argv[1],sys.argv[2]
size={}
for line in open(g,encoding="utf-8",errors="ignore").read().splitlines():
    m=re.match(r"^([A-Za-z0-9_]+):\s+Offset 0x([0-9a-fA-F]+), Length 0x([0-9a-fA-F]+)",line)
    if m: size[m.group(1)]=int(m.group(3),16)
ok=bad=0
for f in os.listdir(B):
    if not f.endswith(".img"): continue
    p=f[:-4]; real=os.path.getsize(os.path.join(B,f)); want=size.get(p,0)
    if real==want: ok+=1
    else: bad+=1; print(f"  ✘ {p} {real} / {want}")
print(f"  ✔ 完整 {ok} 个，问题 {bad} 个")
PYEOF

echo
echo "===== 4/4 解锁 + 关校验 + 清数据 ====="
"$PY" mtk.py multi "da seccfg unlock;e metadata,userdata,md_udc;da vbmeta 3;reset"
RC=$?

echo
if [ $RC -eq 0 ]; then
  cat <<'NEXT'
✔ 解锁完成，设备会自动重启。
  接着进 fastboot 刷机：关机 → 按住【音量 −】+【电源】
  然后跑：bash ~/TB310FU-启天K9/4-刷入系统.sh
NEXT
else
  echo "✘ 解锁失败。重复跑本脚本即可，或分步手动执行："
  echo "   $PY mtk.py da seccfg unlock"
  echo "   $PY mtk.py e metadata,userdata,md_udc"
  echo "   $PY mtk.py da vbmeta 3"
fi
