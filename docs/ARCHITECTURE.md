# 架构

## 模块

| 模块 | 内容 | 依赖 |
| --- | --- | --- |
| `MicYouProtocol` | protobuf 编解码、TCP / UDP 分帧、音频包编号与 FEC、手动地址解析，纯 Foundation | 无 |
| `MicYouShared` | 文案 `L10n`、`DeepLink`、实时活动的 `StreamActivityAttributes` | 无 |
| `MicYou` | 应用本体 | 上面两个 |
| `MicYouWidget` | 实时活动、灵动岛、控制中心按钮 | `MicYouShared` |

小组件不与应用共享数据，也不需要 App Group：实时活动由应用进程直接请求和更新，按钮都通过 `micyou://` 链接回到应用

应用内部按职责分目录：`Model` 只放设置与选项这类值类型，开始传输时由 `AppSettings.streamConfig` 冻结成一份 `StreamConfig`，之后改设置只影响下一次；编码名、传输名等展示文案集中在 `Views/Common/StreamText.swift`，界面与实时活动共用

## 音频数据流

```text
AVAudioEngine 输入 tap（音频线程，每块约 20 ms）
  -> AudioCapture    重采样到目标格式，乘输入增益，PeakLimiter 限幅，转小端 Int16
  -> SessionSink     加锁转交给当前会话，并把电平节流到每秒 30 次给界面
  -> StreamSession   串行队列：Opus 编码或按 1320 字节分块
                     AudioSequencer 编号，开启 FEC 时每 12 包追加校验包
  -> UDP 连接（TCP 端口 + 1）或 ControlChannel 的 TCP 连接
```

`ControlChannel` 负责握手、首帧 `connect`、回复心跳、双向静音同步，并在 5 秒收不到 ping 时判定断线；仅 TCP 模式下音频也走这条连接，积压超过 128 KiB 时直接丢弃音频而不是排队

## 线程

- 主线程（`@MainActor`）：`AppModel`、`AppSettings`、`ServerBrowser`、`LiveActivityController` 与全部界面
- 采集队列：`AudioCapture` 的音频会话激活、引擎启停、中断与换设备后的重启都在一条串行队列上，`start` 是 async，`stop` 立即返回并按顺序排在其后
- 音频线程：`AudioCapture.process`，与采集队列之间只通过锁交换转换器、增益和回调
- 会话队列：每个 `StreamSession` 一条串行队列，它的 `ControlChannel`、UDP 连接、Opus 编码器的创建与编码、计时器都在这条队列上
- 实时活动的 `Activity.request` 在后台任务里发出，结果再回到主线程
- 原则：会阻塞等待系统服务的调用（音频会话、编码器加载、实时活动请求）都不放在主线程，否则点击连接后的过渡动画会掉帧
- 会话事件经 `Task { @MainActor in }` 回到 `AppModel`，并用会话令牌丢弃已被替换的旧会话的迟到事件

## 连接状态

```text
idle -> connecting -> streaming <-> reconnecting(n)
           |              |              |
           +--------------+--------------+--> failed
```

- 自动重连需要同时满足：设置里开启、本次连接至少成功传输过一次、错误可重试（握手失败与协议错误除外）、次数不超过 6
- 重连间隔 1、2、4、8、15、15 秒，期间麦克风采集不停，App 因此能留在后台
- 断开、取消或重连耗尽时停止采集并结束实时活动

## 实时活动

- 只在状态、静音、麦克风或格式变化时更新，内容相同的更新会被跳过
- 不显示音量条：每次内容更新都会让系统对计时器做一次淡入淡出，持续刷新会闪烁
- 计时器用 `Text(timerInterval:)` 由系统自己走
- App 被划走时进程会直接结束，系统却会保留实时活动，所以在 `willTerminateNotification` 里同步等待结束请求发出（最多 2 秒）；崩溃等收不到通知的情况，由下次启动时的 `endStale()` 清理

## 动效

- 时长与曲线统一用 `Views/Common/Motion.swift` 的 `Motion`，转场用其中的 `swap`、`notice`、`bottomBar`，不在各处手写 `.smooth` 或时长
- 出现与消失一律通过 `adaptiveTransition` / `adaptiveAnimation`，开启“减弱动态效果”时自动退化为淡入淡出或直接切换，持续性的动画（重连进度的呼吸）直接关闭
- 两屏切换时离开的一侧 0.15 秒内先淡出，进入的一侧稍后再淡入，避免两层液态玻璃长时间半透明叠加
- 带状态的玻璃控件（静音、预设、主按钮）用 `glassSurface` 只改 tint，保持同一个视图，不要在两种 `buttonStyle` 之间切换，否则会直接替换而不是过渡
- 不用 `blurReplace` 这类滤镜转场作用于玻璃，会触发离屏渲染
- 电平表最多 60 Hz 重绘，指针与峰值都静止后暂停 `TimelineView`
- 触感集中在 `HomeView`：开始与停止传输轻触，断线重连警告，失败报错

## 文案与本地化

- 代码里不直接写用户可见的字符串，一律通过 `Sources/MicYouShared/L10n.swift` 的语义键访问
- 三种语言（含英文）都放在 `Support/Localization/*.lproj`，由 `xtool.yml` 的 `resources` 复制到 `.app` 根目录，所以 `Bundle.main` 与 `InfoPlist.strings` 可用
- 新增文案：先在三个 `Localizable.strings` 加键，再在 `L10n.swift` 加访问器，最后运行 `Tools/check-strings.py`
- 完整句子带句号，标签与按钮不带标点
