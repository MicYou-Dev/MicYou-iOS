# 架构

## 模块

| 模块 | 内容 | 依赖 |
| --- | --- | --- |
| `MicYouProtocol` | protobuf 编解码、TCP / UDP 分帧、音频包编号与 FEC，纯 Foundation | 无 |
| `MicYouShared` | 文案 `L10n`、`DeepLink`、实时活动的 `StreamActivityAttributes` | 无 |
| `MicYou` | 应用本体 | 上面两个 |
| `MicYouWidget` | 实时活动、灵动岛、控制中心按钮 | `MicYouShared` |

小组件不与应用共享数据，也不需要 App Group：实时活动由应用进程直接请求和更新，按钮都通过 `micyou://` 链接回到应用

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
- 音频线程：`AudioCapture.process`，与主线程之间只通过锁交换转换器、增益和回调
- 会话队列：每个 `StreamSession` 一条串行队列，它的 `ControlChannel`、UDP 连接、编码器和计时器都在这条队列上
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

## 文案与本地化

- 代码里不直接写用户可见的字符串，一律通过 `Sources/MicYouShared/L10n.swift` 的语义键访问
- 三种语言（含英文）都放在 `Support/Localization/*.lproj`，由 `xtool.yml` 的 `resources` 复制到 `.app` 根目录，所以 `Bundle.main` 与 `InfoPlist.strings` 可用
- 新增文案：先在三个 `Localizable.strings` 加键，再在 `L10n.swift` 加访问器，最后运行 `Tools/check-strings.py`
- 完整句子带句号，标签与按钮不带标点
