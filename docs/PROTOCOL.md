# MicYou 协议

整理自 MicYou 2.1.0（commit `6a34e09`）的桌面端与 Android 端源码，完整 protobuf 定义见 `Packages/MicYouProtocol/Proto/network.proto`。

> 注：本仓库 `v2` 分支使用的是另一套早期协议（魔数 `0x694F5354`、默认端口 `8900`），与当前 MicYou 2.x 桌面端不互通。本文档描述的是 2.x 桌面端所使用的协议。

## 服务发现

- mDNS / DNS-SD 服务类型：`_micyou._tcp`
- 实例名：`MicYou (<主机名>)`，无 TXT 记录
- 默认端口：TCP `8554`（UDP 端口固定为 `TCP 端口 + 1`，即默认 `8555`）
- 桌面端开启 Web 模式时不会广播 mDNS

## 连接与握手

1. 客户端建立 TCP 连接（建议开启 `TCP_NODELAY` 和 keepalive）。
2. 客户端直接发送 12 字节 ASCII 字符串 `MicYouCheck1`，不带帧头。
3. 桌面端回复 12 字节 `MicYouCheck2`，同样不带帧头。两步的超时均为 5 秒。
4. 握手完成后，客户端在 10 秒内发送第一个 protobuf 帧 `MessageWrapper { connect { sessionId platform } }`，`sessionId` 是每次连接随机生成的非零 `int64`；`platform` 是客户端平台（`"ios"` 或 `"android"`），桌面端从 commit `f319bdd` 起据此显示设备类型；旧版客户端不带这个字段，桌面端按未知设备处理。
5. 客户端紧接着发送一次当前静音状态 `mute { isMuted }`。
6. 桌面端只保留一个活动连接，新连接会直接顶掉旧连接。断开时直接关闭 TCP 即可，没有专门的断开消息。

## 数据分帧

完成明文握手后，TCP 和 UDP 数据包都带 8 字节大端序头部，后面跟着序列化后的 protobuf `MessageWrapper`（UDP 同样必须带 8 字节 `MicU` 头部，不能直接发送裸 protobuf）：

| 通道 | 8 字节头部 | 方向 | 限制 |
| --- | --- | --- | --- |
| TCP | `4D 69 63 59`（`MicY`）+ `u32` 长度 | 双向 | 载荷上限 1 MiB |
| UDP | `4D 69 63 55`（`MicU`）+ `u32` 长度 | 仅手机到电脑 | 整个 UDP 报文不超过 1472 字节 |

UDP 发往 `TCP 端口 + 1`。桌面端只接收来源 IP 与当前 TCP 对端一致、且包内 `sessionId` 匹配的 UDP 包。

## 心跳

- 桌面端每 500 毫秒发送一次 `ping { timestamp }`（Unix 毫秒）。
- 客户端原样回传 `pong { timestamp }`，桌面端用它计算 RTT。
- 客户端连续 5 秒收不到 `ping` 视为断线；桌面端连续 10 秒收不到任何数据则主动断开。

## 链路统计

桌面端在连接期间每秒向手机发送一次 `stats`（`MessageWrapper` 字段 8，`StatsMessage`），内容与桌面端界面显示的一致：

- `rttMs`：平滑后的 ping/pong 往返时间（毫秒），收到第一个 `pong` 之前为 `0`。
- `jitterMs`：音频包到达抖动（毫秒，`float`）。
- `packetLoss`：音频包丢失比例，`0.0` 到 `1.0`（`float`）。
- `latencyMs`：桌面端估算的端到端延迟，即接收缓冲加上往返时间。

旧版客户端不认识这个字段，按 proto3 规则直接跳过。

## 静音

- 静音状态双向同步，受桌面端 `mute_sync` 设置控制（默认开启）。
- 静音期间客户端不发音频包，只保持心跳和控制消息。
- `isMuted` 字段缺省时按 `false` 处理。

## 音频包

音频数据由 `AudioPacketMessageOrdered` 包裹 `AudioPacketMessage`：

- `sequenceNumber`：每次新连接从 `0` 开始，每发一个常规包加 `1`。
- `timestamp`：Unix 毫秒时间戳。
- `codec`：`0` 为 PCM，`1` 为 Opus。
- `audioFormat`：沿用 Android 的 `AudioFormat` 常量，PCM 样本均为小端序。注意 PCM 16-bit 的值是 `2`（`ENCODING_PCM_16BIT`）而不是 `1`（`ENCODING_DEFAULT`），桌面端只接受以下取值：
  - `2`：PCM 16-bit 有符号整型
  - `3`：PCM 8-bit 无符号整型
  - `4`：PCM 32-bit 浮点型
  - `6`：PCM 24-bit 有符号整型
- 采样率支持 8000 到 192000 Hz，声道数为 1 或 2，单包缓冲不超过 64 KiB。
- Opus 只支持 8 / 12 / 16 / 24 / 48 kHz 采样率，每包放一帧裸 Opus 数据（Android 端用 20 ms 帧长）。
- 走 UDP 传 PCM 时，每包音频数据不超过 1320 字节，切分位置必须按采样帧对齐。

## 前向纠错（FEC）

仅在 UDP 模式下可选开启，每 12 个常规音频包后面追加 1 个校验包：

- 校验包的 `buffer` 是前 12 个音频包的 `buffer` 按最长长度在末尾补零后逐字节 XOR 的结果。
- `fecBuffer` 设为单字节 `0x01`，用来和常规包区分（常规包不设此字段）。
- `fecSequenceNumber` 填这组第 1 个常规包的序号。
- `sequenceNumber` 填下一个常规包将要使用的序号，但计数器不递增（即后面的常规包继续用同一个 `sequenceNumber`）。
- `fecPacketLengths` 依次记录这 12 个常规包各自的原始长度（范围 `1..=1320`）。常规包不能带这个字段。

## USB 连接（iOS）

usbmuxd 只允许电脑主动连接手机上的端口，所以 iOS 走 USB 时 TCP 连接的方向是反的，协议内容不变：

1. 手机在回环地址上监听桌面端的服务端口（App 使用“手动连接”中填写的端口，默认 `8554`）。
2. 桌面端处于 USB 模式时，每秒通过 usbmuxd（macOS 自带；Windows 由 iTunes 提供，地址 `127.0.0.1:27015`；Linux 为 `/var/run/usbmuxd`）列出 USB 设备，并对每台设备发送 `Connect`（`PortNumber` 为网络字节序的端口）。
3. 连接成功后，桌面端把这条流转接到本机 TCP 服务端口；手机照常发送 `MicYouCheck1`、`connect` 等，与网络连接完全相同。
4. 这条连接只能承载 TCP，音频按“仅 TCP”方式发送，没有 UDP 和 FEC。

手机端监听 15 秒内没有等到桌面端连接，就报连接失败。断线重连时会重新开始监听。
