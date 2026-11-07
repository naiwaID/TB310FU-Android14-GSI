# TB310FU-Android14-GSI

联想 Tab M9 / 启天K9（**TB310FU**）从锁死的学习机系统刷成 Android 14 GSI 的完整记录：逆向分析、救砖方法、全部脚本、以及一份可以直接贴给 AI 的提示词。

> 这台机器出厂是联想定制的学习机系统（主入口「智牛英语」），默认桌面被替换、返回键和最近任务被拦截、设置进不去、装不了第三方应用。刷完后运行 Evolution X 9.9.3（Android 14，arm64_bvN）。

## 为什么单独开一个仓库

网上的 TB310FU 刷机资料基本是空白的。少数几篇讲「用官方工具」的文章，方向是错的——**官方「平板自助刷机工具」的服务端白名单只有 44 个国内机型，不包含 TB310FU**，改 SN、改 MTM 都没有用，因为服务端根本没有这个机型的包。

真正可行的只有一条路：**mtkclient 走 BROM 直连，解锁引导，再刷 GSI**。这个仓库把这套流程、踩过的坑、以及能自动跑的脚本全放进来。

## 三个最值钱的结论

**1. 进 BROM 用音量加（V+），不是音量减**

这是最容易卡住的地方。网上的教程普遍写「按住音量减」，那是给 SP Flash Tool 用的：

- **V+ 接地 + 插 USB → BROM（`0e8d:0003`）** ← mtkclient 走这条
- **V− 接地 + 插 USB → Preloader（`0e8d:2000`）** ← DAA 会拒绝未签名 DA，报 `upload_data failed 0x1d18`

**2. 备份中途拔线会让设备假死**

mtkclient 工作时会主动关掉芯片的看门狗（防止长读取被复位）。这时候拔线，芯片永远停在 DA 状态：屏幕全黑、按键无反应、USB 也认不到。

看起来像砖，**其实一个字节都没改**（读操作不写 flash）。唯一救法是物理断电——拆后盖断开电池，或者把整块主板拆下来。

**3. 卡开机动画时不要用 `fastboot reboot fastboot`**

擦空 data/metadata 之后，fastbootd 启动时挂载失败，设备会无限重启，永远进不去。

正确做法是绕过 fastboot，直接在 BROM 里擦物理分区：

```bash
../venv/bin/python mtk.py e userdata,metadata,cache
../venv/bin/python mtk.py reset
```

## 目录

```
说明.md              总索引
文档/
  1-逆向分析-官方刷机工具.md    拆了官方 exe，拿出接口和机型白名单
  2-刷机实战.md                完整实战记录（九章）
  3-AI提示词.txt               纯文本，整段贴给任意 AI 就能获得向导
  4-设备资料.md                硬件参数、飞线定义、拆机步骤
  5-交接说明.md                技术备忘与踩坑清单
脚本/                24 个脚本，中文命名
记录/                镜像下载直链
```

## 快速开始

**零基础**：打开 `文档/3-AI提示词.txt`，从第一条分隔线之后全选复制，粘给任意 AI，然后说「我有一台联想 TB310FU，现在开不了机」。它会一次只让你做一件事。

**有基础**：

```bash
# 环境
sudo pacman -S android-tools          # Arch；Debian 系用 apt
git clone --depth 1 https://github.com/bkerler/mtkclient
python3 -m venv venv && ./venv/bin/pip install pyusb colorama pyserial pycryptodome pycryptodomex capstone

# 备份（唯一不能省的一步）
bash 脚本/2-备份分区.sh

# 解锁（会清空数据）
bash 脚本/3-解锁.sh

# 刷入
bash 脚本/4-刷入系统.sh
```

## 安全红线

- `BAT+` 是电池正极裸铜点，**绝不能短接到地**，5100 mAh 直接短路
- 不剪任何排线，剪断电池 FPC 等于报废
- 不从屏幕那面撬，全贴合屏一撬就废
- **不要整包刷官方 ROW 固件**，跨分支整包刷会导致触摸失效和 IMEI 丢失且不可修复。只替换 `system` 分区是安全的

## 关于 AI 和这份资料

刷机领域 AI 编造命令的概率很高。这个仓库里的 `emergency_recover`、`--reset-preloader` 两条「常用命令」经核实**在 mtkclient 中并不存在**，是多篇 AI 生成文章编出来的。

用 AI 辅助的话：别用幻觉率高的模型，任何命令先 `--help` 验证，让它给出处。

## 已知遗留

- 拆机救砖时碰掉两个贴片元件，WiFi 不可用（需要补焊）
- 后盖是破坏性拆的，需要自制外壳
- 每次开机有 5 秒 Orange State 提示，解锁的正常代价

## 免责

刷机有风险，操作前请备份。因操作不当导致的设备损坏、数据丢失，作者不承担责任。本文档记录的是一台真实设备上验证过的流程，但不同批次硬件可能存在差异。

## License

MIT
