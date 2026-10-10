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

## 发布

`.github/workflows/release.yml` 在 macOS 上用 Xcode 自带的 SDK 与固定版本的 xtool（校验 SHA-256）构建，不依赖本机的 Darwin SDK

`.github/workflows/build.yml` 在推送到 `swiftui` 与 PR 时用同样的命令构建，产物保留 14 天，同时给发布留好构建缓存：标签触发的构建只能读默认分支存下的缓存，冷启动约 10 分钟，命中缓存后只编译改动部分；两个工作流共用 `.github/actions/setup-xtool` 与 `Tools/verify-ipa.sh`

1. 确认 `main` 上的检查通过
2. 打标签并推送，正式版 `v1.2.0`，带后缀的 `v1.2.0-beta.1` 发布为预发布

```bash
git tag -s v1.2.0 -m "MicYou 1.2.0"
```

```bash
git push origin v1.2.0
```

- 先跑与 `check.yml` 相同的检查，再构建，最后发布到 GitHub Releases
- `CFBundleShortVersionString` 取标签里的数字部分，`CFBundleVersion` 取提交数，只在 CI 里改，不回写仓库
- 产物为未签名的 `MicYou-<版本>.ipa`、去掉小组件的 `MicYou-<版本>-LiveContainer.ipa` 与 `SHA256SUMS.txt`
- 构建后会检查小组件扩展仍在、二进制记录的 SDK 不低于 26（否则没有液态玻璃）、LiveContainer 包里没有扩展
- 发布说明列出上一个 `v*` 标签以来的提交标题
- 在 Actions 里手动运行只构建不发布，IPA 留在运行的产物里，用来提前验证构建
- 升级 xtool 时同步改 `.github/actions/setup-xtool/action.yml` 里的版本与 SHA-256，摘要可以这样查

```bash
gh api repos/xtool-org/xtool/releases/tags/<版本> --jq '.assets[] | select(.name=="xtool.app.zip") | .digest'
```

`Package.swift` 里修正 SDK 版本的链接参数在 macOS 上同样需要，xtool 在两边都会把部署目标写成 SDK 版本；CI 通过环境变量 `MICYOU_IOS_SDK_VERSION` 传入所选 Xcode 的 SDK 版本，构建后由 `Tools/verify-ipa.sh` 确认

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
- 截图：`pymobiledevice3 developer dvt screenshot <文件>`，iOS 17 以上会自动走用户态隧道；README 的截图放在 `docs/screenshots`，缩到 660 宽，锁屏与灵动岛只裁出活动本身
- 没有桌面端时可以用 `Tools/mock_receiver.py --mdns --name <电脑名>` 代替，列表里显示的就是这个名字

## 提交

提交信息用英文，格式 `<type>: <description>`，类型为 `feat`、`fix`、`refactor`、`style`、`docs`、`chore`
