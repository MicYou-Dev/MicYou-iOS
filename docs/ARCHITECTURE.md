# 架构说明

## 模块

| 模块 | 内容 | 依赖 |
| --- | --- | --- |
| `MicYouProtocol` | protobuf 编解码、TCP / UDP 分帧、音频包编号与 FEC、手动地址解析，纯 Foundation 实现 | 无 |
| `MicYouCore` | 传输与编码选项、预设、`StreamOptions`、重连策略、采样处理与限幅、电平表动态、输入偏好，纯 Foundation 实现 | `MicYouProtocol` |
| `MicYouShared` | 多语言文案 `L10n`、`DeepLink`、实时活动定义 `StreamActivityAttributes` | 无 |
| `MicYou` | 主应用 | `MicYouProtocol`、`MicYouCore`、`MicYouShared` |
| `MicYouWidget` | 锁屏实时活动、灵动岛、主屏幕与锁屏小组件、控制中心按钮（iOS 18 起） | `MicYouShared` |

小组件不和主应用共享存储，也不需要配置 App Group：实时活动由主应用直接通过 ActivityKit 请求和更新，实时活动、灵动岛、小组件和控制中心里的按钮执行 `MicYouShared` 里的 App Intents，系统在主应用进程里运行它们（静音和断开在后台启动主应用，连接会打开主应用），锁屏小组件则通过 `micyou://` 链接打开主应用。因此小组件和控制中心按钮读不到连接状态，图标固定不变。索引的生成方式见 [DEVELOPMENT.md](DEVELOPMENT.md#app-intents)。

主应用内部按职责分目录。`Model` 只放设置项与 `StreamConfig` 这类值类型。不依赖 Apple 框架的逻辑放在 `MicYouCore`，这样可以在 Linux 上测试。点击连接开始传输时，`AppSettings.streamConfig` 会把当前设置固定成一份 `StreamConfig`（目标地址加 `StreamOptions`）传给会话层。传输中途修改设置默认只影响下一次连接；设置页会在设置与当前会话不一致时提供“立即重连以应用”，由 `AppModel.restart()` 在保留传输界面和实时活动的前提下重新连接。输入增益和麦克风选择则立即生效。界面和实时活动共用的编码名、传输方式等展示文字集中在 `Views/Common/StreamText.swift`。

## 音频与控制流程

```text
AVAudioEngine 输入 tap（音频线程，约 20 ms 一块）
  -> AudioCapture    重采样到目标格式，再由 SampleProcessor 乘上输入增益、PeakLimiter 限幅、转为小端 Int16
  -> SessionSink     加锁转发给当前会话，同时按最高 30 Hz 向主线程更新音量电平
  -> StreamSession   会话串行队列：Opus 编码（或把 PCM 按 1320 字节分块）
                     AudioSequencer 编号；开启 FEC 时每满 12 包追加 1 个 XOR 校验包
  -> 网络发送         默认走 UDP（TCP 端口 + 1），“仅 TCP”模式下走 ControlChannel
```

`ControlChannel` 维护 TCP 连接，负责握手、发首帧 `connect`、回复心跳、双向同步静音、转发桌面端每秒发来的链路统计（端到端延迟和丢包率，显示在传输界面；不发端到端延迟的旧版桌面端显示往返延迟。数值在收到时夹到合法范围），并在连续 5 秒收不到 `ping` 时判定断线。选择“USB 数据线”时，`StreamConfig.link` 为 `.usb`，`ControlChannel` 改为在回环地址上监听，等桌面端通过 usbmuxd 连进来后再执行同样的客户端握手；这种连接只能走 TCP，`StreamOptions.overUSB` 会把传输方式固定为“仅 TCP”。“仅 TCP”模式下音频也走这条连接；当发送缓冲积压超过 128 KiB 时会直接丢弃新音频包，避免网络卡顿时延迟越积越大。

选中的是 Bonjour 搜到的电脑时，连接直接用实例名构造 `NWEndpoint.service`，交给 `NWConnection` 自己解析，不等 `NWBrowser` 的搜索结果。这样从快捷指令、链接冷启动，或开启“打开时自动连接”时，App 刚启动也能立刻连上；解析失败会提示找不到电脑。

电脑选择器里，最近用过的地址单独成组，点按即选用，左滑可删除。在地址栏输入了有效地址后，直接点“完成”或下滑关闭选择器也会改用这个地址，不必再点“使用此地址”。

## 麦克风中断与输入选择

- 来电或其他 App 占用麦克风时，`AudioCapture` 通过事件回调报告 `interrupted`，连接保持不断，界面和实时活动显示“麦克风已暂停”。中断结束后强制重启引擎，成功报告 `resumed`，失败报告 `resumeFailed`。
- 在后台可能无法重新开始录音，所以 App 回到前台时会对 `resumeFailed` 自动重试一次；界面上也提供“恢复”按钮，用于处理系统没有发出中断结束通知的情况。
- 输入设备选择保存为 `InputPreference`：自动（跟随系统，接上耳机就切换）、内置麦克风的某个位置（底部、前置、后置），或按端口 UID 记住的外接设备（未连接时按自动处理）。传输中切换会在采集队列上重启引擎。
- 立体声只能用内置麦克风录制。选择“自动”时沿用原有逻辑，强制使用内置麦克风并选用支持立体声的数据源；立体声方向跟随界面方向，iPad 横屏时也能保持左右声道正确。开启人声处理（`voiceChat` 模式）时，内置麦克风的数据源都不提供立体声指向模式，只能录单声道再复制到左右声道；设置页在声道选项下给出警告，并提供“关闭人声处理”按钮。
- 列出可选输入需要音频会话处于录音类别，所以空闲时首次打开选择器会先设置类别（不激活会话）。
- iOS 26 起，“蓝牙高音质录音”（默认开启）会在类别选项里加上 `.bluetoothHighQualityRecording`，支持的 AirPods 以完整带宽录音，不再走通话音质的 HFP；同时保留 `.allowBluetoothHFP`，不支持的耳机自动回退。这个选项只在 `default` 模式下生效，开启人声处理时不会加上，设置页同样给出警告和“关闭人声处理”按钮。切换后立即在采集队列上重启引擎，日志里的采集开始记录会注明是否真的启用了高音质。
- 用蓝牙耳机录音时，App 的静音状态同步到系统输入静音（`AVAudioApplication.setInputMuted`）：`AppModel.isMuted` 变化时写入，采集开始后和音频线路变化（戴上或摘下耳机）时按当前线路再同步一次，停止采集时恢复为未静音，避免带到下一次会话。每次改变系统输入静音都会播放系统的静音提示音，而且不受响铃/静音开关控制，iOS 也没有读取这个开关的接口，所以用其他麦克风时系统输入静音始终保持关闭，只靠 App 自己的静音停止发送。系统输入静音变化（例如按 AirPods 耳机柄）会通过 `inputMuteStateChangeNotification` 报告 `systemMute` 事件，`AppModel` 据此静音或取消静音并通知电脑端；App 自己写入引起的回声因为值相同会被忽略，不是蓝牙线路时的变化只可能来自 App 自己取消系统静音，不会上报。系统静音时采样会被清零，静音状态下本来也不发送声音，所以没有副作用。

## 增益建议

`SampleProcessor` 在每块音频里记录增益后是否有采样超过限幅器的上限，`SessionSink` 把它和电平一起约 30 次每秒交给主线程。`MicYouCore` 的 `GainAdvisor` 据此给出建议，显示在传输界面电平表下方，替换刻度，附带一键把增益调低或调高 6 dB 的按钮：

- 3 秒内有 6 次以上更新触发限幅时建议降低增益，最后一次限幅后保持 5 秒，避免在两句话之间闪烁。
- 每 10 秒统计一次最响的电平，落在 -48 到 -38 dBFS 之间（像是声音太远或太轻，而不是只有底噪或安静）时建议调高增益，下一个 10 秒更响时取消。文案措辞留有余地，因为安静房间里的底噪也可能落在这个范围。
- 只在声音真正送到电脑时（传输中、未静音、麦克风未中断）统计；静音、中断、修改增益或断开都会清空统计。增益已在滑块两端时不再给出对应方向的建议。

阈值没有在多种设备上实测过，需要根据实际情况调整。

## 线程模型

所有可能阻塞等待系统服务的调用（激活 `AVAudioSession`、加载音频转换器、请求创建实时活动）都不放在主线程，否则点击连接时的过渡动画会掉帧。

- 主线程（`@MainActor`）：运行 `AppModel`、`AppSettings`、`ServerBrowser`、`LiveActivityController` 和所有界面视图。
- 采集队列：`AudioCapture` 专用的串行队列，处理音频会话激活、引擎启停、来电中断恢复以及切换音频设备后的重启。`start` 是 `async` 方法，`stop` 则立即返回并在队列里排在 `start` 之后按序执行。
- 音频线程：跑 `AVAudioEngine` 的输入回调 `AudioCapture.process`，和采集队列之间只通过锁交换转换器、增益和回调函数。
- 会话队列：每个 `StreamSession` 有一条独立的串行队列，里面的 `ControlChannel`、UDP 连接、Opus 编码器（创建与编码）和重连计时器都在这条队列上跑。
- 实时活动请求：`Activity.request` 在后台任务里发出，拿到结果后再切回主线程保存。

会话事件通过 `Task { @MainActor in }` 回到 `AppModel`。每次新建会话都会生成唯一令牌，主线程收到回调时先核对令牌，把旧会话晚到的事件直接丢掉。

## 连接状态与重连

```text
idle -> connecting -> streaming <-> reconnecting(n)
           |              |              |
           +--------------+--------------+--> failed
```

断线后需要同时满足这几个条件才会自动重连：设置里开启了自动重连、本次连接已经成功传输过、错误本身可重试（握手失败和协议错误不重试）、重试次数不超过 6 次。

每次新连接都从未静音开始，开启“按住说话”时则从静音开始；自动重连和“立即重连以应用”沿用当前的静音状态。

重连等待间隔依次是 `1、2、4、8、15、15` 秒。重连期间麦克风采集不会停止，靠它保持 iOS 后台录音会话不中断，避免 App 在后台等待重连时被系统挂起。用户主动断开、取消，或者 6 次重连都失败后，才会停止采集并结束实时活动。等待下一次重连期间，如果 `NetworkMonitor` 报告网络从蜂窝或断网恢复为局域网，`AppModel` 会跳过剩余等待立即重试，这一次仍算当前的尝试次数；USB 连接不受网络影响，不做这个处理。

## 网络提示与快捷操作

- `NetworkMonitor` 用 `NWPathMonitor` 跟踪当前网络路径，判断逻辑放在 `MicYouCore` 的 `NetworkStatus`：有 Wi-Fi、有线或其他接口（VPN 可能经蜂窝网络连到电脑）算局域网，只有蜂窝网络或没有网络时，选择了通过网络连接的电脑就在首页提示，并提供“改用 USB”。关闭提示后，网络变化时会再次显示。
- 主屏幕图标的长按快捷操作由 `QuickActions` 在代码里设置（`UIApplication.shortcutItems`），空闲时为“连接”并以副标题显示当前选择的电脑，连接中为“断开连接”和“静音”/“取消静音”。随连接状态更新，App 进入后台时也会刷新一次。每项的类型就是 `DeepLink` 的值，交给 `AppModel.handle(_:)` 处理，和实时活动、快捷指令走同一条路径。SwiftUI 没有快捷操作的回调，所以通过 `AppDelegate` 指定 `SceneDelegate` 来接收启动时和运行中触发的快捷操作。这种写法只依赖 UIKit，不需要 App Intents 索引。

## 实时活动

- 只在连接状态、静音状态、麦克风或音频格式变化时才推送更新，内容没变就直接跳过。
- 实时活动里不放音量条。因为每次更新内容都会让系统对 `Text(timerInterval:)` 计时器做一次淡入淡出，高频刷新会导致计时器一直闪烁。计时交由系统原生的 `timerInterval` 自己走。
- 用户在后台多任务里划掉 App 时，进程会直接退出，但锁屏实时活动默认会留在桌面上。因此应用在收到 `willTerminateNotification` 时会同步等待结束请求发出（最多等 2 秒）；如果遇到崩溃没来得及清理，下次启动时会由 `endStale()` 收尾。

## 检查更新

- `UpdateChecker` 与安卓端、桌面端一样从 GitHub Releases 获取最新版本：先请求 `releases/latest` API，失败或被限流（每个 IP 每小时 60 次）时改为对 `github.com/.../releases/latest` 发 `HEAD` 请求，从跳转后的地址里解析标签。
- 版本比较、响应解析和“每天最多一次”的间隔放在 `MicYouCore` 的 `AppUpdate.swift`，可在 Linux 上测试；`Protocol-2.0.0-1` 这类非应用版本的标签会被忽略。
- 开启“自动检查更新”（默认开启）时，App 回到前台会按间隔检查；发现新版本后首页空闲时显示提示卡片，关闭后同一版本不再提示。侧载的 App 无法自行安装更新，所以只打开对应的发布页。
- 点首页卡片的“查看”或关于页的下载按钮时，先弹出 `ReleaseNotesView` 展示更新日志，底部按钮再跳转发布页。`ReleaseNotes` 把 API 返回的 `body` 拆成标题、列表项和段落，并去掉 `release.yml` 写入的 “Files” 段；只剩一个标题（“Changes”）时也一并省略。列表项开头的 `feat:`、`fix:` 等提交类型会拆出来，用 App 自己的本地化文案显示成彩色标签。行内的代码、强调和链接交给视图里的 `AttributedString(markdown:)` 渲染。走网页跳转兜底时拿不到正文，仍直接打开发布页。
- iOS 18 起且 App 语言不是英文时，sheet 左上角有“翻译”按钮，通过 Translation 框架的 `translationTask` 把每条描述原地译成 App 语言，可切回原文；提交类型标签不参与翻译。`translationTask` 只在 iOS 18 存在，所以放在私有的 `NotesTranslation` 修饰器里，视图只拿到一个“翻译一段字符串”的函数，iOS 17 上不加修饰器也不显示按钮。在 Linux 上构建时跨模块 overlay 不会自动生效，需要显式 `import _Translation_SwiftUI`，并用 `@preconcurrency import Translation` 绕过 `TranslationSession` 不是 `Sendable` 的检查。

## 布局与 iPad

- iPhone 只支持竖屏；iPad 通过 `UISupportedInterfaceOrientations~ipad` 支持全部方向，立体声方向随界面旋转（见上文）。
- 首页由 `FillingScrollView` 按窗口尺寸决定布局：默认单栏，最宽 `HomeLayout.maxWidth`（520pt）并居中；窗口横向且不窄于 860pt（如 iPad 横屏）时，把 `isWide` 传给 `IdleView` 和 `SessionView` 改为双栏，最宽 `HomeLayout.wideMaxWidth`。分屏、台前调度里的窄窗口和 iPad 竖屏仍是单栏。
  - 待机页：左栏是目标电脑、提示卡片和传输格式，右栏是连接按钮。按钮用自定义对齐 `heroCenter` 与左栏中线对齐，下方的提示文字不参与对齐。
  - 传输页：左栏是计时（放大 1.4 倍）和电平，右栏是提示、传输信息和输入增益。底部控制栏两种布局都保持单栏宽度。
  - 两种布局用的是同一组子视图，调整其中一处时要同时检查另一种。
- 首页引导的说明卡片在水平方向尽量对准被高亮的控件，不超出屏幕边缘，双栏时不会停在屏幕正中。
- 欢迎页在 iOS 18 起使用 `.page` 尺寸的 sheet，默认的表单 sheet 在 iPad 横屏时放不下三个步骤；步骤和底部按钮都限制在 520pt 宽。欢迎页副标题和关于页标语通过 `UIDevice.current.model` 显示 iPhone 或 iPad。
- 外接键盘：`StreamCommands` 在菜单栏（iPadOS 26）加入“传输”菜单，⌘↩ 连接或断开，⇧⌘M 静音（系统用 ⌘M 最小化窗口），另有黑屏模式；首页的设置按钮是 ⌘,，目标电脑卡片是 ⌘K。按住 ⌘ 时系统会列出这些快捷键，所以只有图标的按钮也要用 `Label` 保留标题。

## 动效

- 动画时长与曲线统一放在 `Views/Common/Motion.swift` 的 `Motion` 中（如 `swap`、`notice`、`bottomBar`），不在各个视图里手写 `.smooth` 或时长。
- 视图出现和消失统一用 `adaptiveTransition` / `adaptiveAnimation`。系统开启“减弱动态效果”时会自动退化为淡入淡出或直接切换，重连进度条的呼吸动画这类循环动效则会直接关掉。
- 两个主状态界面切换时，离开的一侧在 0.15 秒内先淡出，进入的一侧稍后再淡入，避免两层半透明液态玻璃长时间叠在一起。
- 带状态的玻璃按钮（静音、预设、主连接按钮）统一用 `glassSurface` 只改 `tint` 颜色，保持同一个底层视图；不要在两种 `buttonStyle` 之间切换，否则视图会被直接替换而没有过渡动画。
- 不要对玻璃视图用 `blurReplace` 这类滤镜转场，会触发离屏渲染。
- 电平表最多按 60 Hz 重绘，指针和峰值都回落静止后会自动暂停 `TimelineView`。
- 触感反馈集中在 `HomeView`：开始和停止传输时轻触，断线重连时发警告振动，连接失败时发错误振动。

## 文案与本地化

- 代码里不直接写用户可见的字符串，统一通过 `Sources/MicYouShared/L10n.swift` 的属性访问。
- 简中、繁中、英文三套翻译都放在 `Support/Localization/*.lproj`，由 `xtool.yml` 的 `resources` 直接复制到 `.app` 根目录，保证 `Bundle.main` 和 `InfoPlist.strings` 都能读到。
- 新增文案时，先在三个 `Localizable.strings` 里加键值，再去 `L10n.swift` 加访问属性，最后跑一遍 `Tools/check-strings.py` 检查有无遗漏。
- 完整的句子带句号，按钮和短标签不带标点。
