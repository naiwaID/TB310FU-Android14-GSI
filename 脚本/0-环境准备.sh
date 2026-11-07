#!/usr/bin/env bash
# 步骤 0：一次性环境准备（Arch Linux）
# 用法：bash ~/TB310FU-启天K9/0-环境准备.sh
set -uo pipefail

echo "== [1/3] 安装 android-tools（提供 adb / fastboot）=="
sudo pacman -S --needed --noconfirm android-tools libusb || {
  echo "!! pacman 失败，请先关掉其他 pacman / pamac 窗口再重跑"; exit 1; }

echo "== [2/3] 写入 USB 权限规则 =="
sudo tee /etc/udev/rules.d/52-mtk.rules >/dev/null <<'EOF'
# MediaTek BROM / Preloader / DA 模式
SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", MODE="0666", TAG+="uaccess"
# Android fastboot / adb
SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666", TAG+="uaccess"
# 高通 9008（备用）
SUBSYSTEM=="usb", ATTR{idVendor}=="05c6", MODE="0666", TAG+="uaccess"
EOF
sudo udevadm control --reload-rules && sudo udevadm trigger

echo "== [3/3] 自检 =="
command -v fastboot >/dev/null && echo "  fastboot: $(fastboot --version | head -1)" || echo "  !! fastboot 未安装"
[ -x "$HOME/TB310FU-启天K9/venv/bin/python" ] && echo "  python venv: OK" || echo "  !! venv 缺失"
cd "$HOME/TB310FU-启天K9/mtkclient" && ../venv/bin/python mtk.py --help >/dev/null 2>&1 \
  && echo "  mtkclient: OK" || echo "  !! mtkclient 无法启动"

echo
echo "准备完成。下一步：bash ~/TB310FU-启天K9/1-检测设备.sh"
