# MicYou for iOS

把 iPhone 变成电脑麦克风的原生 iOS 客户端，与 [MicYou](https://github.com/MicYou-Dev/MicYou) 桌面端（2.x）互通，使用 SwiftUI 编写，用 [xtool](https://github.com/xtool-org/xtool) 在 Linux 上构建

## 功能

- Bonjour 自动发现局域网内的 MicYou 桌面端，也可手动输入地址和端口
- TCP + UDP（默认，延迟最低）或仅 TCP 两种传输方式
- Opus（系统自带编码器）或 PCM 16 位，采样率 48 / 44.1 / 16 kHz，单声道或立体声
- UDP 前向纠错（每 12 包一个 XOR 校验包）
- 与桌面端双向同步静音，心跳超时自动重连
- 系统人声处理（回声消除与降噪）开关
- 锁屏后台持续传输，实时活动与灵动岛显示状态
- 控制中心按钮、快捷指令、`micyou://` URL
- 简体中文、繁体中文、英文

## 构建

需要 Swift 6 与配置好的 xtool（`xtool setup`）

```bash
xtool dev build
```

```bash
xtool dev run
```

协议库可以直接在 Linux 上测试

```bash
swift test --package-path Packages/MicYouProtocol
```

LiveContainer 无法签名和运行 App 扩展，用下面的脚本生成去掉小组件的 IPA（`xtool/MicYou-LiveContainer.ipa`），实时活动和控制中心按钮在其中不可用

```bash
Tools/build-livecontainer.sh
```

## 调试

`Tools/mock_receiver.py` 是一个简易的桌面端替身，会回应握手、发送心跳、打印控制消息，并把 PCM 音频写成 WAV

```bash
python3 Tools/mock_receiver.py --mdns --toggle-mute 5
```

## URL

| URL | 作用 |
| --- | --- |
| `micyou://connect` | 连接上次使用的电脑 |
| `micyou://disconnect` | 断开 |
| `micyou://toggle` | 连接或断开 |
| `micyou://mute` `micyou://unmute` `micyou://toggle-mute` | 静音控制 |

## 目录

- `Packages/MicYouProtocol` 协议编解码、分帧、FEC，纯 Foundation
- `Sources/MicYou` 应用本体：音频采集、网络、界面
- `Sources/MicYouShared` 应用与小组件共用的实时活动定义和 URL
- `Sources/MicYouWidget` 实时活动与控制中心小组件
- `Proto/network.proto` 上游协议定义原文
- `docs/PROTOCOL.md` 协议说明

## 已知限制

- xtool 无法运行 Xcode 的 App Intents 元数据处理器，快捷指令里可能看不到本应用的操作，可以用“打开 URL”配合上面的 `micyou://` 链接代替
- 只能在前台开始传输，这是 iOS 对录音的限制，开始后可以锁屏或切到后台
- 不支持 USB（ADB）模式

## 许可

GPL-3.0-or-later，详见 [LICENSE](LICENSE) 与 [NOTICE](NOTICE)
