# 开发说明

## 常用命令

| 命令 | 作用 |
| --- | --- |
| `xtool dev build` | 编译并输出到 `xtool/MicYou.app` |
| `xtool dev run` | 编译、签名并安装到已连接的设备 |
| `swift test --package-path Packages/MicYouProtocol` | 运行协议库测试（可在 Linux 上直接跑） |
| `swift test --package-path Packages/MicYouCore` | 运行核心逻辑测试（可在 Linux 上直接跑） |
| `Tools/check-strings.py` | 检查三语文案的键名与格式占位符是否一致、有无缺失或未使用的键 |
| `Tools/appintents-metadata.py` | 在 `xtool dev build` 之后由编译期常量生成 App Intents 索引，`--check` 检查提交的索引是否过期 |
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

iOS 只从 `.app` 里的 `Metadata.appintents` 索引读取 App Intents。Xcode 在链接后用闭源的 `appintentsmetadataprocessor` 生成它，这个工具只能在 macOS 上运行，xtool 也不会调用。不过它的输入并不神秘：编译器可以为每个源文件写出 `.swiftconstvalues`（编译期常量，JSON 格式，Linux 上也有）。Linux 上 xtool 底层的 Swift Build 会自己要求输出，macOS 上（CI）xtool 走的是 SwiftPM 自带的构建，不会，所以 `Package.swift` 给含有 intents 的三个目标显式加上 `-emit-const-values` 和 `Tools/appintents-protocols.json` 里的协议列表（与 Swift Build 自己用的相同）。协议列表要用 `-Xfrontend -const-gather-protocols-file` 直接传给前端，driver 的 `-const-gather-protocols-list` 从 Swift 6.4 才有，Xcode 26 不认识。两种构建写出的位置不同：Swift Build 在 `.build/out/Intermediates.noindex/` 下每个源文件一份，SwiftPM 在 `.build/arm64-apple-ios/<配置>/<模块>.build/` 下每个模块一份。`Tools/appintents-metadata.py` 两处都找，取最新的那次构建，按 Xcode 26.6（工具版本 `17F113`）的格式写出 `extract.actionsdata` 和 `version.json`。用 [qyang-nj/llios](https://github.com/qyang-nj/llios/blob/main/articles/BuildAppIntents.md) 里 Xcode 生成的样本对照过，输出一致。

- App 和小组件扩展各有一份索引，提交在 `Resources/AppIntents/<可执行文件名>/Metadata.appintents`，由 `xtool.yml` 分别复制到 `.app` 和 `.appex` 根目录，所以 `xtool dev run` 装的版本也带索引。改了意图之后先 `xtool dev build`，再运行 `Tools/appintents-metadata.py` 并提交结果；`Tools/verify-ipa.sh` 会用 release 构建的常量值检查提交的索引是否过期。
- 意图定义在 App 和小组件共用的 `MicYouShared/StreamIntents.swift`，`MicYouShortcuts`（快捷指令短语）留在 App 里。两份索引都列出这些意图，并在 `mangledTypeNameByBundleIdentifier` 里写明两个 bundle，否则扩展里的按钮会因为找不到元数据而无效（这一点参考了 [cyberneel/xtool-on-linux](https://github.com/cyberneel/xtool-on-linux) 的真机结论，Xcode 自己的样本都是意图只在一个模块里的情况）。
- 小组件按钮、控制中心按钮和实时活动按钮都用这些意图，`perform()` 总在 App 进程里执行，经 `IntentActions.handler` 交给 `AppModel.handle(_:)`。停止和静音遵循 `LiveActivityIntent`，系统在后台拉起 App 执行，不打开界面；索引里对应的系统协议是 `SessionStarting`，取自 Xcode 构建产物（`LinkMetadataDT` 框架里的对照表和其他项目的验证脚本）。开始传输和切换连接用 `openAppWhenRun` 先打开 App：试过 `AudioRecordingIntent` 在后台直接开始录音，连接和实时活动都起来了，但激活麦克风被系统拒绝（混音的 PlayAndRecord 会话算作后台开始播放，纯录音会话又不能打断系统声音的会话，错误码 `'!int'`），所以放弃了。
- 常量值只记录字面量，所以意图的标题、描述和 `shortTitle` 直接写字符串表的键（如 `"intent.start.title"`），不走 `L10n`；`Tools/check-strings.py` 会扫描源码里这些 `intent.` 键。
- 脚本只支持 MicYou 用到的部分：无参数的意图、`LiveActivityIntent` 与 `AudioRecordingIntent` 两种系统协议和一个 `AppShortcutsProvider`。遇到参数、实体、枚举、`@available` 等会直接报错退出，不会写出错误的索引。`perform` 返回 `OpensIntent`、`ReturnsValue` 等结果时 `outputFlags` 的取值也没有核实，同样不支持。
- App 和 `MicYouShared` 都以静态库形式链接，没被引用的归档成员会整个被丢掉，系统即使读到索引也找不到类型。`MicYouApp.init` 里调用 `MicYouShortcuts.updateAppShortcutParameters()` 保证意图被链接进 App，小组件则因为按钮直接引用意图而链接进来；所有意图要放在同一个文件里。
- 锁屏小组件不能放按钮，仍用 `widgetURL` 打开 `micyou://`；主屏幕快捷操作和 `micyou://` 链接也照旧走 `AppModel.handle(_:)`。

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
- 用 `Tools/verify-ipa.sh` 检查完整包里有小组件扩展、二进制记录的 SDK 版本不低于 26（否则没有液态玻璃）、App Intents 索引存在且没有过期、意图类型被链接进二进制、LiveContainer 包里不含扩展。
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
