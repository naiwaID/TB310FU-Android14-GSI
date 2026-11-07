#!/usr/bin/env bash
# 步骤 2：备份关键分区（自带完整性校验，可重复跑）
# 用法：bash ~/TB310FU-启天K9/2-备份分区.sh          全量（约 330MB，40 秒）
#       bash ~/TB310FU-启天K9/2-备份分区.sh quick    只备刷机必需（约 200MB，1 分钟）
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE/mtkclient"
B="$HERE/备份"
PY="$HERE/venv/bin/python"
mkdir -p "$B"
GPT="$B/gpt-$(date +%m%d-%H%M%S).txt"

echo "== 备份分区表 -> $(basename "$GPT") =="
# 先写临时文件再落盘，中断不会毁掉已有分区表
"$PY" mtk.py printgpt | tee "$GPT.tmp" | tail -3
mv -f "$GPT.tmp" "$GPT"

echo "== 备份 preloader（boot1 引导区，砖机救援用）=="
"$PY" mtk.py r preloader "$B/preloader.bin" --parttype boot1 \
  && echo "  preloader.bin $(stat -c%s "$B/preloader.bin") B" \
  || echo "  preloader 备份跳过（不影响刷机）"

echo "== 备份关键分区（A/B 双槽，分区名带 _a/_b）=="
if [ "${1:-}" = "quick" ]; then
  # 快速模式：只备"刷机必须 + 真砖保险"，约 200MB，1 分钟
  LIST="vbmeta_a vbmeta_b vbmeta_system_a vbmeta_vendor_a boot_a nvram persist"
  echo "   快速模式：$LIST"
else
  LIST="proinfo nvram nvdata nvcfg seccfg persist protect1 protect2 frp md_udc metadata \
        boot_para logo misc para sec1 lenovolock lenovoraw \
        boot_a boot_b vendor_boot_a vendor_boot_b dtbo_a dtbo_b lk_a lk_b tee_a tee_b \
        vbmeta_a vbmeta_b vbmeta_system_a vbmeta_system_b vbmeta_vendor_a vbmeta_vendor_b"
fi
for p in $LIST; do
  printf "  %-18s" "$p"
  rm -f "$B/$p.img"
  if "$PY" mtk.py r "$p" "$B/$p.img" >/dev/null 2>&1 && [ -s "$B/$p.img" ]; then
    echo "OK  $(stat -c%s "$B/$p.img") B"
  else
    echo "-   无此分区，跳过"
    rm -f "$B/$p.img"
  fi
done

echo
echo "== 校验：拿分区表长度逐个比对 =="
"$HERE/venv/bin/python" - "$B" "$GPT" <<'PYEOF'
import re,os,sys
B,gptf=sys.argv[1],sys.argv[2]
size={}
for line in open(gptf,encoding="utf-8",errors="ignore").read().splitlines():
    m=re.match(r"^([A-Za-z0-9_]+):\s+Offset 0x([0-9a-fA-F]+), Length 0x([0-9a-fA-F]+)",line)
    if m: size[m.group(1)]=int(m.group(3),16)
if not size:
    print("  !! 分区表没解析出来，稍后重跑一次"); sys.exit(0)
ok=bad=0
for f in sorted(os.listdir(B)):
    if not f.endswith(".img"): continue
    p=f[:-4]; real=os.path.getsize(os.path.join(B,f)); want=size.get(p,0)
    if real==want: ok+=1
    else:
        bad+=1
        print(f"  ✘ {p:18} {real/1048576:8.2f} / {want/1048576:8.2f} MB  需重读")
print(f"  ✔ 完整 {ok} 个，问题 {bad} 个")
PYEOF

echo
du -sh "$B"
echo "下一步：bash ~/TB310FU-启天K9/3-解锁.sh"
