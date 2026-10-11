# 架构说明

## 模块

| 模块 | 内容 | 依赖 |
| --- | --- | --- |
| `MicYouProtocol` | protobuf 编解码、TCP / UDP 分帧、音频包编号与 FEC、手动地址解析，纯 Foundation 实现 | 无 |
| `MicYouShared` | 多语言文案 `L10n`、`DeepLink`、实时活动定义 `StreamActivityAttributes` | 无 |
| `MicYou` | 主应用 | `MicYouProtocol`、`MicYouShared` |
| `MicYouWidget` | 锁屏实时活动、灵动岛、控制中心按钮 | `MicYouShared` |

小组件不和主应用共享存储，也不需要配置 App Group：实时活动由主应用直接通过 ActivityKit 请求和更新，小组件与控制中心里的按钮都通过 `micyou://` 链接回到主应用处理。

主应用内部按职责分目录。`Model` 只放设置项与选项这类值类型。点击连接开始传输时，`AppSettings.streamConfig` 会把当前设置固定成一份 `StreamConfig` 传给会话层，传输中途改设置只影响下一次连接。界面和实时活动共用的编码名、传输方式等展示文字集中在 `Views/Common/StreamText.swift`。

## 音频与控制流程

```text
AVAudioEngine 输入 tap（音频线程，约 20 ms 一块）
  -> AudioCapture    重采样到目标格式，乘上输入增益，PeakLimiter 限幅，转为小端 Int16
  -> SessionSink     加锁转发给当前会话，同时按最高 30 Hz 向主线程更新音量电平
  -> StreamSession   会话串行队列：Opus 编码（或把 PCM 按 1320 字节分块）
                     AudioSequencer 编号；开启 FEC 时每满 12 包追加 1 个 XOR 校验包
  -> 网络发送         默认走 UDP（TCP 端口 + 1），“仅 TCP”模式下走 ControlChannel
```

`ControlChannel` 维护 TCP 连接，负责握手、发首帧 `connect`、回复心跳、双向同步静音，并在连续 5 秒收不到 `ping` 时判定断线。“仅 TCP”模式下音频也走这条连接；当发送缓冲积压超过 128 KiB 时会直接丢弃新音频包，避免网络卡顿时延迟越积越大。

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

重连等待间隔依次是 `1、2、4、8、15、15` 秒。重连期间麦克风采集不会停止，靠它保持 iOS 后台录音会话不中断，避免 App 在后台等待重连时被系统挂起。用户主动断开、取消，或者 6 次重连都失败后，才会停止采集并结束实时活动。

## 实时活动

- 只在连接状态、静音状态、麦克风或音频格式变化时才推送更新，内容没变就直接跳过。
- 实时活动里不放音量条。因为每次更新内容都会让系统对 `Text(timerInterval:)` 计时器做一次淡入淡出，高频刷新会导致计时器一直闪烁。计时交由系统原生的 `timerInterval` 自己走。
- 用户在后台多任务里划掉 App 时，进程会直接退出，但锁屏实时活动默认会留在桌面上。因此应用在收到 `willTerminateNotification` 时会同步等待结束请求发出（最多等 2 秒）；如果遇到崩溃没来得及清理，下次启动时会由 `endStale()` 收尾。

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
