# 开发说明

## 常用命令

| 命令 | 作用 |
| --- | --- |
| `xtool dev build` | 编译并输出到 `xtool/MicYou.app` |
| `xtool dev run` | 编译、签名并安装到已连接的设备 |
| `swift test --package-path Packages/MicYouProtocol` | 运行协议库测试（可在 Linux 上直接跑） |
| `swift test --package-path Packages/MicYouCore` | 运行核心逻辑测试（可在 Linux 上直接跑） |
| `Tools/check-strings.py` | 检查三语文案的键名与格式占位符是否一致、有无缺失或未使用的键 |
| `Tools/build-livecontainer.sh` | 生成去掉小组件扩展的 IPA，供 LiveContainer 使用 |
| `python3 Tools/mock_receiver.py --mdns` | 在本机模拟桌面端接收，加 `--help` 查看全部参数 |

## xtool 注意事项

### SDK 版本与液态玻璃

链接器 `lld` 默认会把部署目标（`18.0`）写进 Mach-O `LC_BUILD_VERSION` 的 SDK 版本字段。iOS 看到旧 SDK 版本号后会按兼容模式运行应用，没有液态玻璃效果。

`Package.swift` 里通过链接参数 `-platform_version ios 18.0 <sdkVersion>` 修正了这个问题。更换本机的 Darwin SDK 后记得同步更新 `sdkVersion`，可以用下面两条命令核对：

```bash
xtool sdk status
llvm-objdump --macho --private-headers xtool/MicYou.app/MicYou | grep -A4 LC_BUILD_VERSION
```

### 小组件扩展入口

xtool 链接扩展时固定传入 `-e _NSExtensionMain`，导致 SwiftUI 小组件的 `@main` 入口（`_main`）因为没有被直接引用而被链接器整段裁掉，装到手机上只是个空壳。

这里不能把入口改成 `-e _main`，否则 `ExtensionFoundation` 启动时会断言崩溃。正确做法是保留原入口，同时在 `Package.swift` 里给 `MicYouWidget` 加上 `-u _main` 强制保留 `_main` 符号。

### 资源打包

项目不用 SwiftPM 的资源包，而是靠 `xtool.yml` 的 `resources` 把图标、许可证和 `Support/Localization/*.lproj` 原样复制到 `.app` 根目录，这样 `Bundle.main` 和 `InfoPlist.strings` 才能直接生效。小组件扩展也单独列了一份本地化目录。

### App Intents

xtool 没法运行 Xcode 自带的 App Intents 元数据处理器，系统“快捷指令”里可能看不到 `Sources/MicYou/Intents` 定义的操作。因此实时活动按钮改用 `Link` 打开 `micyou://`，控制中心按钮则用系统自带的 `OpenURLIntent`。

### 免费开发者账号限制

- 免费账号每 7 天最多只能创建 10 个 App ID（删掉旧的也不会退还额度），主应用和小组件扩展各占 1 个。
- 名额不够用时，可以临时删掉 `xtool.yml` 里的 `extensions` 段，只编译安装主应用。
- 换账号后 Bundle ID 前缀会变，手机桌面上可能会同时出现两个 MicYou。

## CI 与发版

仓库里有两个构建工作流，都在 macOS runner 上使用 Xcode 自带的 SDK 和固定版本的 xtool（校验 SHA-256），不依赖外部的 Darwin SDK：

- `.github/workflows/build.yml`：推送到 `swiftui` 分支或提 PR 时触发，产物保留 14 天。因为 GitHub Actions 里由 tag 触发的构建只能读取默认分支存下的缓存，这个工作流也负责把构建缓存热好（冷启动编译大约要 10 分钟，命中缓存后只编译改动部分）。
- `.github/workflows/release.yml`：推送 `v*` 标签时触发，自动跑检查、构建 IPA 并发布到 GitHub Releases。也可以在 Actions 页面手动触发，手动运行时只构建不发版，IPA 留在构建产物里，方便发版前验证。

两个工作流共用 `.github/actions/setup-xtool` 和 `Tools/verify-ipa.sh`。`Package.swift` 里修正 SDK 版本的链接参数在 macOS 上同样需要（xtool 在两边都会把部署目标写成 SDK 版本），CI 会通过环境变量 `MICYOU_IOS_SDK_VERSION` 传入当前 Xcode 的 SDK 版本。

### 发布新版本

1. 确认主分支上的测试和检查都已通过。
2. 打标签并推送。`v1.2.0` 会发成正式版，带后缀的（如 `v1.2.0-beta.1`）会自动标为预发布：

```bash
git tag -s v1.2.0 -m "MicYou 1.2.0"
git push origin v1.2.0
```

`release.yml` 会依次完成以下步骤：

- 先跑一遍与 `check.yml` 相同的测试和本地化检查。
- 把标签里的数字部分写入 `CFBundleShortVersionString`，把总提交数写入 `CFBundleVersion`（只在 CI 里改，不回写仓库）。
- 生成未签名的 `MicYou-<版本>.ipa`、去掉小组件的 `MicYou-<版本>-LiveContainer.ipa` 和 `SHA256SUMS.txt`。release 构建在链接时去掉本地符号和调试信息（`Package.swift` 里的 `stripSymbols`），二进制体积减半，代价是崩溃日志里应用自己的栈帧只显示地址；xtool 打出的 IPA 不压缩，`Tools/build-livecontainer.sh` 会重新压缩一遍，下载体积也减半。
- 用 `Tools/verify-ipa.sh` 检查完整包里有小组件扩展、二进制记录的 SDK 版本不低于 26（否则没有液态玻璃）、LiveContainer 包里不含扩展。
- 收集上一个 `v*` 标签以来的提交标题作为发布说明，创建 GitHub Release。

升级 xtool 时，需要同步修改 `.github/actions/setup-xtool/action.yml` 里的版本号和 SHA-256 摘要。摘要可以用 `gh` 查：

```bash
gh api repos/xtool-org/xtool/releases/tags/<版本> --jq '.assets[] | select(.name=="xtool.app.zip") | .digest'
```

## 编译图标

`Resources/AppIcon/MicYou.icon` 是 Icon Composer 格式的液态玻璃图标，只能用 macOS 上的 `actool` 编译：

1. 在 GitHub Actions 页面手动运行 `Compile icon` 工作流。
2. 下载构建产物 `ios-assets`。
3. 用里面的 `Assets.car` 覆盖 `Resources/AppIcon/Assets.car`。

同目录下的两张 PNG 是不支持 `Assets.car` 时的后备图标。

## 调试

- 日志统一使用子系统 `com.chouchiu.micyou`，分类有 `model`、`capture`、`session`、`control`、`browser`、`activity`。
- 查看实时日志可以用 `idevicesyslog` 或 `pymobiledevice3 syslog live`，按子系统过滤即可。
- 导出崩溃报告用 `pymobiledevice3 crash ls` 和 `pymobiledevice3 crash pull`。
- 如果改了小组件但系统里没刷新，重装一次应用就会重新加载扩展。
- 手头没有桌面端时，可以跑 `python3 Tools/mock_receiver.py --mdns --name <电脑名>` 代替，手机列表里就会搜到这个名字的电脑。

## 真机截图

在 Linux 上可以用 `pymobiledevice3` 给 USB 连接的手机截图。加上 `--userspace` 会在用户态建立 iOS 17+ 需要的调试隧道，不需要 root 权限：

```bash
pymobiledevice3 developer dvt screenshot --userspace shot.png
```

电脑端没法直接模拟手指点击手机屏幕，所以截图时靠启动参数切换界面状态。这些参数会写进 `UserDefaults` 的参数域，只对当次启动生效。先用 `pymobiledevice3 apps list` 查出设备上实际的 Bundle ID（免费签名账号会带前缀），再带参数启动应用：

```bash
pymobiledevice3 developer dvt launch --userspace "<Bundle ID> -welcomeShown NO -host 192.168.1.5"
```

可用的启动参数：

- `-welcomeShown NO`：打开首次启动欢迎页。
- `-tourShown NO`：打开首页引导。
- `-MicYouTourStep 3`：让首页引导直接跳到第 3 步（仅 Debug 构建生效）。
- `-host 192.168.1.5`：预先填入手动连接地址，让首页“连接”按钮显示为可点击状态。

README 用的截图放在 `docs/screenshots/`，分辨率统一缩放到 `660 × 1434`。锁屏实时活动与灵动岛只裁出组件本身，截图前注意避开通知横幅。

## 提交规范

提交信息用英文，格式为 `<type>: <description>`，常用类型：`feat`、`fix`、`refactor`、`style`、`docs`、`chore`。
