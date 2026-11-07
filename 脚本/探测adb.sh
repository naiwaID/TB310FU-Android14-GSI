#!/usr/bin/env bash
# 在"原生桌面"闪出来的那几秒里，快速探测这台学习机的 adb 通道是否可用
# 全程只读，不改任何设置、不卸载任何东西
# 用法：bash ~/TB310FU-启天K9/adb-probe.sh
set -uo pipefail

command -v adb >/dev/null || { echo "!! 先装 adb：sudo pacman -S android-tools"; exit 1; }

echo "== 等待设备（最多 120 秒；平板开机中会一直等）=="
echo "   建议：先插好 USB，再按电源开机，看到原生桌面别动它"
timeout 120 adb wait-for-device || {
  echo
  echo "✘ 120 秒没等到 adb 设备。"
  echo "  → 说明 USB 调试是关的，旋转闪现这条路做不了跳板，老老实实走 BROM。"
  exit 1; }

echo "✔ adb 通了"
echo
echo "== 设备信息 =="
for p in ro.product.model ro.product.device ro.build.version.release ro.build.version.sdk ro.lenovo.mtm ro.serialno; do
  printf "  %-28s %s\n" "$p" "$(adb shell getprop $p 2>/dev/null | tr -d '\r')"
done

echo
echo "== 谁在管这台机器（DeviceOwner）=="
adb shell dpm list-owners 2>&1 | tr -d '\r' | sed 's/^/  /'

echo
echo "== 当前默认桌面 =="
adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>&1 | tr -d '\r' | sed 's/^/  /'

echo
echo "== 无障碍开关（看门狗是不是它）=="
adb shell settings get secure enabled_accessibility_services 2>&1 | tr -d '\r' | sed 's/^/  /'

echo
echo "== 学习机相关包 =="
adb shell pm list packages 2>/dev/null | tr -d '\r' | grep -iE "gszx|zhiniu|study|learn|launcher|kiosk" | sed 's/^/  /'

echo
cat <<'TIP'
────────────────────────────────────────────
如果上面能看到 adb 通了，先别急着刷机，有三条低风险选项：

A. 只想让它变成普通平板（不刷机、不清数据）
   pm disable-user --user 0 com.gszx.smartword.phone   # 关掉学习机主程序
   再装个第三方桌面并设为默认，锁就废了

B. 只是想要能装应用
   pm disable-user 掉看门狗，然后正常装 apk

C. 还是要刷机
   adb 已经是白送的：adb reboot bootloader 比抠按键省事

需要哪条，把本脚本输出贴给我，我给你具体命令。
────────────────────────────────────────────
TIP
