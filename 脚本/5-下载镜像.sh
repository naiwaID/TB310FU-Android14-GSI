#!/usr/bin/env bash
# 步骤 4：下载 / 校验镜像
#   bash ~/TB310FU-启天K9/5-下载镜像.sh test        # 只测各镜像站速度
#   bash ~/TB310FU-启天K9/5-下载镜像.sh             # 测速→挑最快→多源并发下载→解压
#   bash ~/TB310FU-启天K9/5-下载镜像.sh local 文件  # 你自己下好的 .img.gz / .img，校验并解压
#   bash ~/TB310FU-启天K9/5-下载镜像.sh rom         # 官方 ROW 固件（3.5G，救砖用，很慢）
#
# 有代理就带上：https_proxy=http://127.0.0.1:7890 bash ~/TB310FU-启天K9/5-下载镜像.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
D="$HERE/镜像"; mkdir -p "$D/gsi"
PROXY="${https_proxy:-${HTTPS_PROXY:-${all_proxy:-${ALL_PROXY:-}}}}"

FILE="lineage-21.0-20250621-UNOFFICIAL-arm64_bvN.img.gz"
PATHQ="project/andyyan-gsi/lineage-21-td/$FILE"
ROM_URL="https://mirrors.lolinet.com/firmware/lenowow/2022/Tab_M9/TB310FU/TB310FU_S000912_251002_ROW.zip"
MIRRORS=(jaist nchc netix gigenet master cfhcable excellmedia astuteinternet
         pilotfiber phoenixnap liquidtelecom nfsn versaweb deac-riga freefr
         netcologne tenet iweb ufosc c3sl)

# ---------- 本地文件模式：校验 + 解压 ----------
OUT="$D/gsi/gsi.img"
GH_URL="https://github.com/mytja/treble_evo/releases/download/20250422/evolution_arm64_bvN-9.9.3-unofficial-20250422.img.xz"

verify_local() {
  local src="$1" kind
  [ -f "$src" ] || { echo "!! 文件不存在：$src"; exit 1; }
  kind=$(file -b "$src")
  case "$kind" in
    *XZ*)    echo "== 校验 xz =="; xz -t "$src" || { echo "!! 包不完整"; exit 1; }
             echo "== 解压（1G 左右，约 1 分钟）=="; xz -dc "$src" > "$OUT" ;;
    *gzip*)  echo "== 校验 gzip =="; gzip -t "$src" || { echo "!! 包不完整"; exit 1; }
             echo "== 解压 =="; gunzip -c "$src" > "$OUT" ;;
    *ext4*|*"Android"*|*"Linux rev"*) echo "== 已是 raw 镜像 =="
             cp -f "$src" "$OUT" ;;
    *)       if [ "${src##*.}" = "img" ]; then cp -f "$src" "$OUT"
             else echo "!! 不认识的格式：$kind"; exit 1; fi ;;
  esac
  echo "✔ $OUT  $(du -h "$OUT" | cut -f1)"
  echo "下一步：bash ~/TB310FU-启天K9/4-刷入系统.sh"
  exit 0
}
[ "${1:-}" = "local" ] && verify_local "${2:?用法: 5-下载镜像.sh local <文件>}"

need_aria2() {
  command -v aria2c >/dev/null 2>&1 && return 0
  echo "装 aria2（多线程下载器）..."
  sudo pacman -S --needed --noconfirm aria2
}
ARIA_PROXY=(); [ -n "$PROXY" ] && ARIA_PROXY=(--all-proxy="$PROXY") && echo "使用代理：$PROXY"
CURL_PROXY=(); [ -n "$PROXY" ] && CURL_PROXY=(--proxy "$PROXY")

# ---------- GitHub 模式：Evolution X 9.9.3 (Android 14, vanilla)，来源 GitHub，国内通常很快 ----------
if [ "${1:-}" = "gh" ]; then
  F="$D/evo_a14.img.xz"
  if need_aria2; then
    aria2c -x16 -s16 -k1M -c --console-log-level=warn --summary-interval=10 \
           "${ARIA_PROXY[@]}" --dir="$D" -o evo_a14.img.xz "$GH_URL"
  else
    curl -L -C - --retry 30 "${CURL_PROXY[@]}" --progress-bar -o "$F" "$GH_URL"
  fi
  verify_local "$F"
fi

speed_test() {
  local s
  s=$(curl -sL -o /dev/null --max-time 8 -r 0-6000000 "${CURL_PROXY[@]}" \
        -w '%{speed_download}' "https://$1.dl.sourceforge.net/$PATHQ" 2>/dev/null || echo 0)
  printf "%s %s\n" "$1" "${s%.*}"
}

echo "== 测速 20 个 SourceForge 节点（约 20 秒）=="
TMP=$(mktemp)
for m in "${MIRRORS[@]}"; do speed_test "$m" >> "$TMP" & done
wait
echo
sort -k2 -nr "$TMP" | awk '{printf "  %-16s %8.1f KB/s\n",$1,$2/1024}' | head -6
BEST=$(sort -k2 -nr "$TMP" | awk '$2>80000 {print $1}' | head -3)
[ -z "$BEST" ] && BEST=$(sort -k2 -nr "$TMP" | awk '{print $1}' | head -3)
echo "  → 选用：$(echo $BEST)"
[ "${1:-}" = "test" ] && { rm -f "$TMP"; echo "测速完成，未下载。"; exit 0; }

if [ -s "$OUT" ]; then
  echo "镜像已就绪：$OUT"; rm -f "$TMP"; exit 0
fi

URLS=(); for m in $BEST; do URLS+=("https://$m.dl.sourceforge.net/$PATHQ"); done
URLS+=("https://downloads.sourceforge.net/$PATHQ")
[ -s "$D/$FILE" ] && ! gzip -t "$D/$FILE" 2>/dev/null && rm -f "$D/$FILE"

if need_aria2; then
  echo "== aria2 多源 × 8 线程（断了重跑可续传）=="
  aria2c -x8 -s8 -k1M -c --console-log-level=warn --summary-interval=10 \
         "${ARIA_PROXY[@]}" --dir="$D" -o "$FILE" "${URLS[@]}"
else
  echo "== curl 断点续传 =="
  curl -L -C - --retry 50 --retry-delay 3 "${CURL_PROXY[@]}" \
       --progress-bar -o "$D/$FILE" "${URLS[0]}"
fi

echo "== 校验 =="
gzip -t "$D/$FILE" 2>/dev/null || {
  echo "!! 文件不完整（被限速或中断）。三种更快的办法："
  echo "   1) 把下面直链丢进迅雷/IDM（多线程通常能到 MB/s）："
  echo "      ${URLS[0]}"
  echo "   2) 有代理：https_proxy=http://127.0.0.1:7890 bash ~/TB310FU-启天K9/5-下载镜像.sh"
  echo "   3) 走 GitHub（国内快）：bash ~/TB310FU-启天K9/5-下载镜像.sh gh"
  echo "   4) 浏览器/网盘下好后：bash ~/TB310FU-启天K9/5-下载镜像.sh local <文件>"
  exit 1; }
gunzip -c "$D/$FILE" > "$OUT" && rm -f "$D/$FILE"
echo "  ✔ $OUT  $(du -h "$OUT" | cut -f1)"

if [ "${1:-}" = "rom" ]; then
  echo "== 官方 ROW 固件（lolinet 单源 3.5G，很慢，可挂一夜）=="
  if need_aria2; then
    aria2c -x16 -s16 -k1M -c --console-log-level=warn --summary-interval=15 \
           "${ARIA_PROXY[@]}" --dir="$D" -o TB310FU_ROW.zip "$ROM_URL"
  else
    curl -L -C - --retry 50 "${CURL_PROXY[@]}" --progress-bar -o "$D/TB310FU_ROW.zip" "$ROM_URL"
  fi
fi

rm -f "$TMP"
echo; echo "下一步：bash ~/TB310FU-启天K9/4-刷入系统.sh"
