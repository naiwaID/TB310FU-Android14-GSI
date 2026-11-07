#!/usr/bin/env bash
# 一键装回全部应用 + 系统设置（在你自己终端跑）
# 用法：bash ~/TB310FU-启天K9/安装全部应用.sh
set -uo pipefail
APK_DIR="${APK_DIR:-$HOME/Downloads/apk}"
VID="${VID:-$HOME/Movies/wallpaper_tablet.mp4}"

step() { echo; echo "════ $* ════"; }

step "0/5 检查 adb"
adb start-server >/dev/null 2>&1
sleep 1
DEV=$(adb devices | tr -d '\r' | grep -v "List of" | grep -v '^$')
if [ -z "$DEV" ]; then
  echo "!! 没看到设备。请：平板插 USB → 弹出【允许 USB 调试吗】→ 勾选一律允许 → 允许"
  echo "   然后重新跑本脚本"
  exit 1
fi
echo "$DEV"
case "$DEV" in
  *unauthorized*) echo "!! 设备未授权，请在平板上点【允许】"; exit 1;;
esac

step "1/5 装本地已有的 APK（B站 HD、视频壁纸）"
for f in "$APK_DIR/bili-hd.apk" "$APK_DIR/vlw.apk"; do
  [ -f "$f" ] || { echo "  跳过（不存在）: $f"; continue; }
  printf "  %-16s " "$(basename "$f")"
  adb install -r -g "$f" 2>&1 | tr -d '\r' | tail -1
done

step "2/5 让平板自己下载并安装（微信/淘宝/DeepSeek/讯飞）"
echo "  前提：平板已连 WiFi。没连的话这一步会失败，先连上再跑。"
dl_install() {
  local name="$1" url="$2" file="$3"
  printf "  %-14s " "$name"
  adb shell "curl -sL --max-time 900 -A Mozilla/5.0 -o /data/local/tmp/$file '$url'" >/dev/null 2>&1
  local sz
  sz=$(adb shell "stat -c %s /data/local/tmp/$file 2>/dev/null || echo 0" | tr -d '\r')
  if [ "${sz:-0}" -lt 1000000 ]; then
    echo "下载失败（${sz:-0} 字节）"
    return 1
  fi
  printf "下载 %sMB → " "$((sz/1048576))"
  adb shell pm install -r -g "/data/local/tmp/$file" 2>&1 | tr -d '\r' | tail -1
  adb shell "rm -f /data/local/tmp/$file" >/dev/null 2>&1
}

dl_install "微信"   "http://imtt.dd.qq.com/sjy.00022/sjy.00004/16891/apk/DF45EF476D4EC3B018BD425CF0618ECE.apk?fsname=com.tencent.mm_8.0.79.apk" wx.apk
dl_install "淘宝"   "http://imtt.dd.qq.com/sjy.00022/sjy.00004/16891/apk/DB87C9037F57C10E4396D71B70B4660A.apk?fsname=com.taobao.taobao_10.69.0.apk" tb.apk
dl_install "DeepSeek" "http://imtt.dd.qq.com/sjy.00022/sjy.00004/16891/apk/AE0042C8A100D5DB0567E2A2C00ED61D.apk?fsname=com.deepseek.chat_2.7.5.apk" ds.apk
dl_install "讯飞输入法" "http://imtt.dd.qq.com/sjy.00022/sjy.00004/16891/apk/9D7ADA9BDA847DDE9C7D9AB71BA1FCE7.apk?fsname=com.iflytek.inputmethod_16.0.2.apk" xf.apk

step "3/5 系统设置：横屏 + 关掉联网检测"
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 1
adb shell wm fixed-to-user-rotation enabled
adb shell settings put global captive_portal_mode 0
adb shell settings put global captive_portal_http_url http://connect.rom.miui.com/generate_204
adb shell settings put global captive_portal_https_url https://connect.rom.miui.com/generate_204
adb shell settings put global captive_portal_use_https 0
echo "  ✔ 横屏已锁定，联网检测已关闭"

step "4/5 设讯飞为默认输入法"
adb shell ime enable com.iflytek.inputmethod/.FlyIME 2>&1 | tr -d '\r'
adb shell ime set com.iflytek.inputmethod/.FlyIME 2>&1 | tr -d '\r'
echo "  当前: $(adb shell settings get secure default_input_method | tr -d '\r')"

step "5/5 推送动态壁纸"
if [ -f "$VID" ]; then
  adb shell mkdir -p /sdcard/Movies 2>/dev/null
  adb push "$VID" /sdcard/Movies/wallpaper_tablet.mp4 2>&1 | tr -d '\r' | tail -1
  adb shell pm grant io.github.codeg0blin.videowallpaper android.permission.READ_MEDIA_VIDEO 2>&1 | tr -d '\r' | head -1
else
  echo "  跳过（视频不存在）"
fi

step "完成 · 当前已装第三方应用"
adb shell pm list packages -3 2>/dev/null | tr -d '\r' | sed 's/package://' | sort | sed 's/^/  /'
echo
echo "动态壁纸手动设置：打开 Video Live Wallpaper → Choose Video → Movies → wallpaper_tablet.mp4 → Set wallpaper"
