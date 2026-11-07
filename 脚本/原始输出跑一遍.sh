#!/usr/bin/env bash
# 原始输出模式：不做任何过滤、不加任何提示，直接跑 mtkclient
# 用法：bash ~/TB310FU-启天K9/run-raw.sh
cd "$(dirname "$0")/mtkclient" || exit 1
PY=../venv/bin/python
mkdir -p ../backup

$PY mtk.py printgpt
$PY mtk.py r preloader ../backup/preloader.bin --parttype boot1
$PY mtk.py r vbmeta_a ../backup/vbmeta_a.img
$PY mtk.py r vbmeta_b ../backup/vbmeta_b.img
$PY mtk.py r vbmeta_system_a ../backup/vbmeta_system_a.img
$PY mtk.py r vbmeta_vendor_a ../backup/vbmeta_vendor_a.img
$PY mtk.py r boot_a ../backup/boot_a.img
$PY mtk.py r boot_b ../backup/boot_b.img
$PY mtk.py r nvram ../backup/nvram.img
$PY mtk.py r nvdata ../backup/nvdata.img
$PY mtk.py r nvcfg ../backup/nvcfg.img
$PY mtk.py r persist ../backup/persist.img
$PY mtk.py r seccfg ../backup/seccfg.img
$PY mtk.py r proinfo ../backup/proinfo.img
$PY mtk.py multi "da seccfg unlock;e metadata,userdata,md_udc;da vbmeta 3;reset"
