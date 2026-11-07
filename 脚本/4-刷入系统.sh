#!/usr/bin/env bash
# 步骤 5：把 GSI（Evolution X 9.9.3 / Android 14）刷进 system 分区
# 用法：bash ~/TB310FU-启天K9/4-刷入系统.sh [镜像路径]
#   默认镜像：~/TB310FU-启天K9/镜像/gsi/gsi.img
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
if [ -n "${1:-}" ]; then IMG="$1"
elif [ -f "$HERE/镜像/gsi/gsi.img" ]; then IMG="$HERE/镜像/gsi/gsi.img"
elif [ -f "$HERE/镜像/gsi/lineage21.img" ]; then IMG="$HERE/镜像/gsi/lineage21.img"
else IMG="$HERE/镜像/gsi/gsi.img"; fi

command -v fastboot >/dev/null || { echo "!! 没装 fastboot，先跑 0-环境准备.sh"; exit 1; }
[ -f "$IMG" ] || { echo "!! 找不到镜像：$IMG"; echo "   先跑：bash ~/TB310FU-启天K9/5-下载镜像.sh"; exit 1; }

echo "镜像：$IMG  ($(du -h "$IMG" | cut -f1))"
echo "== 检查 fastboot 设备 =="
fastboot devices
if ! fastboot devices | grep -q .; then
  echo "!! 没认到设备。请：平板关机 → 按住【音量-】+【电源】→ 出现 fastboot 界面"
  exit 1
fi

echo "== 关闭 dm-verity / 校验（A/B 机型，用备份里的 vbmeta 打补丁后写回）=="
for p in vbmeta vbmeta_system vbmeta_vendor; do
  f="$HERE/备份/${p}_a.img"
  if [ -s "$f" ]; then
    printf "  %-16s" "$p"
    if fastboot --disable-verity --disable-verification flash "$p" "$f" 2>&1 | tail -1; then :; else
      echo "    ⚠ 写 $p 失败，继续（可能已由 mtkclient 处理）"
    fi
  fi
done

echo "== 进入 fastbootd（用户空间 fastboot，刷 GSI 必须）=="
fastboot reboot fastboot || true
sleep 8
fastboot devices

echo "== 腾出空间：删掉 product / system_ext 逻辑分区（腾不出来就留着）=="
for p in product_a product system_ext_a system_ext; do
  fastboot delete-logical-partition "$p" >/dev/null 2>&1 && echo "  已删 $p" || true
done

echo "== 写入 system（1.4G，几分钟，别拔线）=="
if ! fastboot flash system "$IMG"; then
  echo
  echo "!! 写入失败。若提示空间不足，试 vndklite 版镜像："
  echo "   lineage-21.0-20250621-UNOFFICIAL-arm64_bvN-vndklite.img.gz"
  exit 1
fi

echo "== 清除数据与 metadata =="
fastboot -w || fastboot erase userdata
fastboot erase metadata 2>/dev/null || true

echo "== 重启 =="
fastboot reboot
echo
echo "✔ 完成。首次开机要 5~10 分钟（deodex + 初始化），屏幕会转圈，别断电。"
