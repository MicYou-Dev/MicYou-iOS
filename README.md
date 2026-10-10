# MicYou for iOS

把 iPhone 变成电脑麦克风的原生 iOS 客户端，与 [MicYou](https://github.com/MicYou-Dev/MicYou) 桌面端 2.x 互通，SwiftUI 编写，用 [xtool](https://github.com/xtool-org/xtool) 在 Linux 上构建

## 功能

- Bonjour 自动发现局域网内的桌面端，也可以手动输入地址，支持 `地址:端口` 写法
- 传输方式 TCP + UDP（默认，延迟最低）或仅 TCP，UDP 可开前向纠错（每 12 包一个 XOR 校验包）
- 编码 Opus（系统编码器）或 PCM 16 位，采样率 48 / 44.1 / 16 kHz，单声道或立体声
- 软件输入增益（0 到 +24 dB）与限幅器，可选系统人声处理（回声消除、降噪、自动增益）
- 与桌面端双向同步静音，心跳超时后自动重连，最多 6 次
- 锁屏与后台持续传输，实时活动和灵动岛显示状态、当前麦克风和格式，可直接静音或断开
- 控制中心按钮、快捷指令、`micyou://` URL
- 简体中文、繁体中文、英文

## 使用

1. 在电脑上打开 MicYou 桌面端，确认手机和电脑在同一个局域网
2. 打开 App，在“附近的电脑”里选中你的电脑，找不到时下拉重新查找，或用“通过 IP 地址连接”手动输入
3. 点“连接”，首次使用需要允许麦克风和本地网络权限
4. 开始传输后可以锁屏或切到后台，状态卡片会显示时长、格式、码率和输入电平

只能在前台开始传输，这是 iOS 对录音的限制

## URL

| URL | 作用 |
| --- | --- |
| `micyou://connect` | 连接上次使用的电脑 |
| `micyou://disconnect` | 断开 |
| `micyou://toggle` | 连接或断开 |
| `micyou://mute` `micyou://unmute` `micyou://toggle-mute` | 静音控制 |

快捷指令里看不到本应用的操作时，用“打开 URL”配合上面的链接

## 常见问题

| 现象 | 处理 |
| --- | --- |
| 列表里一直找不到电脑 | 确认桌面端在运行且没有开 Web 模式，两台设备在同一网段，路由器没有开 AP 隔离，也可以直接手动输入地址 |
| 提示电脑拒绝了连接 | 端口不对或桌面端没在监听，默认端口 8554 |
| 声音断断续续 | 设置里改用仅 TCP，或开启前向纠错 |
| 声音太小 | 调高设置里的输入增益，限幅器会防止爆音 |
| 小组件与实时活动不可用 | LiveContainer 版本不含扩展，或系统设置里关闭了实时活动 |

## 构建

需要 Swift 6 与配置好的 xtool（`xtool setup`）

```bash
xtool dev run
```

协议库与本地化表可以直接在 Linux 上检查，CI 也跑这两项

```bash
swift test --package-path Packages/MicYouProtocol
```

```bash
Tools/check-strings.py
```

LiveContainer 无法签名和运行 App 扩展，下面的脚本生成去掉小组件的 IPA（`xtool/MicYou-LiveContainer.ipa`）

```bash
Tools/build-livecontainer.sh
```

`Tools/mock_receiver.py` 是一个简易桌面端替身，会回应握手、发送心跳、打印控制消息，并把 PCM 音频写成 WAV

```bash
python3 Tools/mock_receiver.py --mdns --toggle-mute 5
```

xtool 的已知坑、图标编译与调试方法见 [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)

## 目录

```text
Packages/MicYouProtocol   协议编解码、分帧、FEC，纯 Foundation，可在 Linux 测试
  Proto/network.proto     上游协议定义原文
Sources/MicYou            应用本体
  App/                    入口、全局状态 AppModel、采集到会话的桥接
  Audio/                  麦克风采集、限幅器、Opus 编码
  Network/                Bonjour 发现、TCP 控制通道、UDP 音频与会话
  Live/                   实时活动驱动与当前麦克风信息
  Intents/                快捷指令
  Settings/               持久化设置
  Views/                  界面
Sources/MicYouShared      应用与小组件共用：文案 L10n、URL、实时活动定义
Sources/MicYouWidget      实时活动、灵动岛与控制中心按钮
Support/                  Info.plist 与三语本地化表
Resources/AppIcon         液态玻璃图标源文件 MicYou.icon 与 actool 编译产物
Tools/                    桌面端替身、LiveContainer 打包、本地化检查
docs/                     协议、架构与开发说明
```

- [docs/PROTOCOL.md](docs/PROTOCOL.md) 协议说明
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) 模块划分、数据流与线程模型

## 已知限制

- xtool 无法运行 Xcode 的 App Intents 元数据处理器，快捷指令里可能看不到本应用的操作
- 不支持 USB（ADB）模式

## 许可

GPL-3.0-or-later，详见 [LICENSE](LICENSE) 与 [NOTICE](NOTICE)
