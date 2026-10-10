# 开发说明

## 常用命令

| 命令 | 作用 |
| --- | --- |
| `xtool dev build` | 构建到 `xtool/MicYou.app` |
| `xtool dev run` | 构建、签名并安装到已连接的设备 |
| `swift test --package-path Packages/MicYouProtocol` | 协议库测试，可在 Linux 运行 |
| `Tools/check-strings.py` | 检查三语文案的键与格式参数是否一致、有无缺失或未使用的键 |
| `Tools/build-livecontainer.sh` | 生成不含扩展的 IPA，给 LiveContainer 使用 |
| `python3 Tools/mock_receiver.py --mdns` | 本机模拟桌面端，`--help` 查看全部参数 |

## xtool 注意事项

### SDK 版本

lld 默认把部署目标（18.0）写成 `LC_BUILD_VERSION` 里的 SDK 版本，iOS 会因此按旧 SDK 兼容模式运行应用，没有液态玻璃

`Package.swift` 通过链接参数 `-platform_version ios 18.0 <sdkVersion>` 修正，更换 Darwin SDK 后要同步 `sdkVersion`，可以这样核对

```bash
xtool sdk status
```

```bash
llvm-objdump --macho --private-headers xtool/MicYou.app/MicYou | grep -A4 LC_BUILD_VERSION
```

### 小组件入口

xtool 链接扩展时使用 `-e _NSExtensionMain`，SwiftUI 的 `@main` 小组件因此没有被引用，会被整段裁掉，装到设备上只是空壳；不能改成 `-e _main`（ExtensionFoundation 启动时会断言崩溃），正确做法是保留原入口，并给 `MicYouWidget` 加 `-u _main` 强制保留，见 `Package.swift`

### 资源

不使用 SwiftPM 资源包，`xtool.yml` 的 `resources` 会把列出的文件和目录原样复制到 `.app` 根目录，本地化目录和图标都走这里；小组件扩展单独列一份本地化目录

### App Intents

xtool 无法运行 Xcode 的 App Intents 元数据处理器，系统可能不会列出 `Sources/MicYou/Intents` 里的快捷指令；实时活动按钮因此用 `Link` 打开 `micyou://`，控制中心按钮用系统自带的 `OpenURLIntent`

### 免费开发者账号

- 每 7 天最多创建 10 个 App ID，删除不返还，小组件扩展也占一个
- 名额不够时可以临时删掉 `xtool.yml` 的 `extensions` 段，只装主应用
- 换账号后 Bundle ID 前缀会变，设备上会出现两个独立的 MicYou

## 图标

`Resources/AppIcon/MicYou.icon` 是 Icon Composer 格式的液态玻璃图标，只有 macOS 上的 actool 能编译

1. 在 GitHub Actions 里手动运行 `Compile icon`
2. 下载产物 `ios-assets`
3. 用其中的 `Assets.car` 覆盖 `Resources/AppIcon/Assets.car`

同目录的两张 PNG 是不支持 `Assets.car` 时的后备图标

## 调试

- 日志统一使用子系统 `com.chouchiu.micyou`，分类有 `model`、`capture`、`session`、`control`、`browser`、`activity`
- 实时日志：`idevicesyslog` 或 `pymobiledevice3 syslog live`，按子系统过滤
- 崩溃报告：`pymobiledevice3 crash ls` 与 `pymobiledevice3 crash pull`
- 小组件不出现时重装一次应用，系统会重新加载扩展

## 提交

提交信息用英文，格式 `<type>: <description>`，类型为 `feat`、`fix`、`refactor`、`style`、`docs`、`chore`
