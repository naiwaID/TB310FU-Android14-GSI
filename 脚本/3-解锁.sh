#!/usr/bin/env bash
# 步骤 3：解锁 Bootloader + 关闭 dm-verity/verification + 清数据
# 用法：bash ~/TB310FU-启天K9/3-解锁.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE/mtkclient"
PY="$HERE/venv/bin/python"

cat <<'TIP'
⚠️  这一步会清空平板内所有数据（学习系统、账号、缓存全部没了），不可恢复。
    确认 2-备份分区.sh 已经跑完，再继续。
TIP
read -r -p "输入 yes 继续，其它键退出： " a
[ "$a" = "yes" ] || { echo "已取消"; exit 1; }

echo
echo "== 平板关机 → 按住【音量 +】→ 插 USB → 松手 =="
read -r -p "按回车开始..." _

# 一条连接里完成：解锁 seccfg → 清 userdata/metadata → 关校验 → 重启
"$PY" mtk.py multi "da seccfg unlock;e metadata,userdata,md_udc;da vbmeta 3;reset"
RC=$?

echo
if [ $RC -eq 0 ]; then
  echo "✔ 已解锁。平板会自动重启，可能停在黄色/橙色警告页，这是正常现象。"
  echo "  接下来手动进 fastboot：关机 → 按住【音量 -】+【电源】不放。"
  echo "  然后运行：bash ~/TB310FU-启天K9/4-刷入系统.sh"
else
  echo "✘ 失败。分步重试（每步都是独立一次 BROM 连接）："
  echo "   cd $HERE/mtkclient"
  echo "   ../venv/bin/python mtk.py da seccfg unlock"
  echo "   ../venv/bin/python mtk.py e metadata,userdata,md_udc"
  echo "   ../venv/bin/python mtk.py da vbmeta 3"
  echo "   ../venv/bin/python mtk.py reset"
fi
