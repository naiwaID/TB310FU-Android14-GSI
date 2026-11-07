#!/usr/bin/env bash
# 应用安装冷静期（默认 10 天）
# 用法：
#   bash apps.sh add "哔哩哔哩" /path/to/app.apk     # 提交申请，进入 10 天冷静期
#   bash apps.sh list                                # 看队列和剩余天数
#   bash apps.sh check                               # 检查到期项并自动安装
#   bash apps.sh force <序号>                        # 不等了，立刻装（自己破坏规则用）
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
QUEUE="$DIR/waitlist.txt"
COOLDOWN_DAYS="${COOLDOWN_DAYS:-10}"
STAMP="$DIR/installed.log"
touch "$QUEUE" "$STAMP"

cd_today() { date +%s; }
days_since() { echo $(( ( $(cd_today) - $(date -d "$1" +%s) ) / 86400 )); }

case "${1:-}" in
  add)
    NAME="${2:?缺名称}"; SRC="${3:?缺 APK 路径或 URL}"
    printf '%s|%s|%s\n' "$(date +%F)" "$NAME" "$SRC" >> "$QUEUE"
    echo "已进入冷静期：$NAME"
    echo "  提交日期 $(date +%F)，可安装日期 $(date -d "+$COOLDOWN_DAYS days" +%F)"
    ;;

  list)
    [ -s "$QUEUE" ] || { echo "队列为空"; exit 0; }
    n=0
    while IFS='|' read -r d name src; do
      n=$((n+1))
      el=$(days_since "$d"); left=$(( COOLDOWN_DAYS - el ))
      if [ $left -le 0 ]; then
        printf "%2d. %-14s 已到期（提交 %s，等了 %d 天）\n" "$n" "$name" "$d" "$el"
      else
        printf "%2d. %-14s 还要等 %d 天（提交 %s）\n" "$n" "$name" "$left" "$d"
      fi
    done < "$QUEUE"
    ;;

  check)
    [ -s "$QUEUE" ] || { echo "队列为空，没有待装应用"; exit 0; }
    TMP=$(mktemp); changed=0
    while IFS='|' read -r d name src; do
      el=$(days_since "$d")
      if [ $el -lt "$COOLDOWN_DAYS" ]; then
        echo "$d|$name|$src" >> "$TMP"
        echo "· $name 还要等 $(( COOLDOWN_DAYS - el )) 天"
        continue
      fi
      echo "→ $name 已满 $COOLDOWN_DAYS 天，开始安装"
      if [[ "$src" == http* ]]; then
        f="$DIR/$(basename "${src%%\?*}")"
        curl -sL --max-time 180 -A Mozilla/5.0 -o "$f" "$src" || { echo "  下载失败，保留在队列"; echo "$d|$name|$src" >> "$TMP"; continue; }
        src="$f"
      fi
      if [ ! -f "$src" ]; then
        echo "  找不到 APK：$src（保留在队列）"; echo "$d|$name|$src" >> "$TMP"; continue
      fi
      if adb install -r "$src" 2>&1 | grep -q Success; then
        echo "  ✔ 安装成功"; echo "$(date +%F) $name $src" >> "$STAMP"; changed=1
      else
        echo "  ✘ 安装失败，保留在队列"; echo "$d|$name|$src" >> "$TMP"
      fi
    done < "$QUEUE"
    mv -f "$TMP" "$QUEUE"
    [ $changed -eq 1 ] && echo "队列已更新"
    ;;

  force)
    IDX="${2:?缺序号}"
    LINE=$(sed -n "${IDX}p" "$QUEUE")
    [ -z "$LINE" ] && { echo "没有第 $IDX 项"; exit 1; }
    src=$(echo "$LINE" | cut -d'|' -f3); name=$(echo "$LINE" | cut -d'|' -f2)
    if [[ "$src" == http* ]]; then
      f="$DIR/$(basename "${src%%\?*}")"; curl -sL -A Mozilla/5.0 -o "$f" "$src"; src="$f"
    fi
    adb install -r "$src" && { sed -i "${IDX}d" "$QUEUE"; echo "$(date +%F) $name $src (force)" >> "$STAMP"; }
    ;;

  *)
    grep -m1 '^#' "$0" >/dev/null; sed -n '2,8p' "$0"; ;;
esac
