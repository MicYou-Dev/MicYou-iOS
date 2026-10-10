<div align="center">

  <h1>MicYou for iOS</h1>

  <img src="docs/images/app-icon.png" width="128" height="128" alt="MicYou">

  <br>
  <br>

  <a href="https://github.com/MicYou-Dev/MicYou-iOS/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/MicYou-Dev/MicYou-iOS?logo=github&label=release"></a>
  <img alt="iOS 18+" src="https://img.shields.io/badge/iOS-18%2B-000000?logo=apple&logoColor=white">
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-GPL--3.0-blue"></a>
  <a href="https://qm.qq.com/q/V16hPpWPKO"><img alt="QQ" src="https://img.shields.io/badge/QQ-995452107-12B7F5?style=flat&logo=qq&logoColor=white"></a>
  <a href="https://t.me/MicYouChannel"><img alt="TG" src="https://img.shields.io/badge/Telegram-@MicYouChannel-2CA5E0?style=flat&logo=telegram&logoColor=white"></a>

  <p>把 iPhone 变成电脑麦克风的原生 iOS 客户端</p>

  与 <a href="https://github.com/MicYou-Dev/MicYou">MicYou</a> 桌面端 2.x 互通 · SwiftUI · Wi-Fi · 锁屏与后台持续传输

</div>

## 主要功能

- Bonjour 自动发现局域网内的桌面端，也可以手动输入地址，支持 `地址:端口` 写法
- 传输方式 TCP + UDP（默认，延迟最低）或仅 TCP，UDP 可开前向纠错（每 12 包一个 XOR 校验包）
- 编码 Opus（系统编码器）或 PCM 16 位，采样率 48 / 44.1 / 16 kHz，单声道或立体声
- 软件输入增益（0 到 +24 dB）与限幅器，可选系统人声处理（回声消除、降噪、自动增益）
- 低延迟、稳定、无损三个场景预设，一次切换传输方式、编码与采样率
- 与桌面端双向同步静音，心跳超时后自动重连，最多 6 次
- 锁屏与后台持续传输，实时活动和灵动岛显示状态、当前麦克风和格式，可直接静音或断开
- 控制中心按钮、快捷指令、`micyou://` URL
- 简体中文、繁体中文、英文

## 软件截图

| 首页 | 传输中 | 设置 |
| :---: | :---: | :---: |
| <img src="docs/screenshots/home.png" width="240" alt="首页"> | <img src="docs/screenshots/streaming.png" width="240" alt="传输中"> | <img src="docs/screenshots/settings.png" width="240" alt="设置"> |

| 锁屏实时活动 | 灵动岛 |
| :---: | :---: |
| <img src="docs/screenshots/live-activity.png" width="380" alt="锁屏实时活动"> | <img src="docs/screenshots/dynamic-island-compact.png" width="380" alt="灵动岛"><br><img src="docs/screenshots/dynamic-island-expanded.png" width="380" alt="展开的灵动岛"> |

## 安装

从 [GitHub Releases](https://github.com/MicYou-Dev/MicYou-iOS/releases/latest) 下载，需要 iOS 18 或更高版本

| 文件 | 说明 |
| --- | --- |
| `MicYou-<版本>.ipa` | 未签名，用 AltStore、SideStore、Sideloadly 或 xtool 签名安装 |
| `MicYou-<版本>-LiveContainer.ipa` | 去掉了小组件扩展，用于 LiveContainer，没有实时活动、灵动岛与控制中心按钮 |
| `SHA256SUMS.txt` | 两个 IPA 的校验值 |

电脑端从 [MicYou Releases](https://github.com/MicYou-Dev/MicYou/releases) 下载桌面端，并按[快速开始指南](https://micyou.top/docs/quick-start)配置虚拟麦克风

## 使用指南

1. 在电脑上打开 MicYou 桌面端，连接模式选 Wi-Fi，确认手机和电脑在同一个局域网
2. 打开 App，点顶部的电脑卡片，在“附近的电脑”里选中你的电脑，找不到时下拉重新查找，或在“手动连接”里输入地址
3. 点中间的“连接”，首次使用需要允许麦克风和本地网络权限
4. 开始传输后可以锁屏或切到后台，界面会显示时长、输入电平、格式与码率，输入增益可以直接调整
5. 在通话、游戏、直播或录音软件里选择桌面端配置好的虚拟麦克风

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

## 技术栈

- 界面：SwiftUI、Observation，实时活动与灵动岛用 ActivityKit，控制中心按钮用 WidgetKit，快捷指令用 App Intents
- 音频：AVAudioEngine 采集，AVAudioConverter 重采样与 Opus 编码，自带峰值限幅器
- 网络：Network.framework，NWBrowser 做 Bonjour 发现，TCP 控制通道与 UDP 音频
- 协议：`MicYouProtocol` 纯 Foundation 实现 protobuf 编解码、分帧与 FEC，可在 Linux 上测试
- 构建：Swift 6 与 [xtool](https://github.com/xtool-org/xtool)，在 Linux 上即可构建与签名

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
Packages/MicYouProtocol   协议编解码、分帧、FEC、地址解析，纯 Foundation，可在 Linux 测试
  Proto/network.proto     上游协议定义原文
Sources/MicYou            应用本体
  App/                    入口、全局状态 AppModel、采集到会话的桥接
  Model/                  持久化设置、传输与编码选项、预设、StreamConfig
  Audio/                  麦克风采集、限幅器、Opus 编码
  Network/                Bonjour 发现、TCP 控制通道、UDP 音频与会话
  Live/                   实时活动驱动与当前麦克风信息
  Intents/                快捷指令
  Views/Home              主屏：待机、会话、电平表、底部控制条
  Views/Picker            选择电脑
  Views/Settings          设置与关于
  Views/Common            玻璃样式、提示卡片、增益滑块、格式文案
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

## 交流

- QQ 群 [995452107](https://qm.qq.com/q/V16hPpWPKO)
- Telegram 频道 [@MicYouChannel](https://t.me/MicYouChannel)

## 致谢

- [MicYou](https://github.com/MicYou-Dev/MicYou) 由 LanRhyme 及贡献者开发，本项目的协议与客户端行为移植自它的 Android 端
- 液态玻璃图标来自 MicYou [#350](https://github.com/MicYou-Dev/MicYou/pull/350)，作者 WhatDamon
- [xtool](https://github.com/xtool-org/xtool) 让 iOS 应用可以在 Linux 上构建

## 许可

GPL-3.0-or-later，详见 [LICENSE](LICENSE) 与 [NOTICE](NOTICE)
