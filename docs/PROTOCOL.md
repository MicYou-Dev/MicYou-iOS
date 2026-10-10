# MicYou 协议

依据 MicYou 2.1.0（commit 6a34e09）的桌面端与 Android 端整理，权威定义见 `Packages/MicYouProtocol/Proto/network.proto`

## 发现

- mDNS / DNS-SD 服务类型 `_micyou._tcp`
- 实例名 `MicYou (<主机名>)`，无 TXT 记录
- 默认端口 8554，Web 模式不广播

## 连接

1. 客户端建立 TCP 连接（建议 TCP_NODELAY 与 keepalive）
2. 客户端发送 12 字节 ASCII `MicYouCheck1`，无分帧
3. 桌面端回复 `MicYouCheck2`，每一步超时 5 秒
4. 客户端在 10 秒内发送第一帧 `MessageWrapper{connect{sessionId}}`，`sessionId` 为每次连接唯一的非零 int64
5. 客户端随后发送一次当前静音状态 `mute{isMuted}`
6. 新连接会顶掉旧连接，断开时直接关闭 TCP，没有断开消息

## 分帧

所有头部字段为大端序

| 通道 | 头部 | 方向 |
| --- | --- | --- |
| TCP | `4D 69 63 59`（MicY）+ u32 长度 | 双向 |
| UDP | `4D 69 63 55`（MicU）+ u32 长度 | 仅手机到电脑 |

- 载荷是 protobuf `MessageWrapper`，TCP 长度上限 1 MiB
- UDP 发往 TCP 端口 + 1，整个报文不超过 1472 字节
- 桌面端只接受来源 IP 与 TCP 对端一致且 `sessionId` 匹配的 UDP 包

## 心跳

- 桌面端每 500 毫秒发送 `ping{timestamp}`（Unix 毫秒）
- 客户端原样回复 `pong{timestamp}`，桌面端据此计算 RTT
- 客户端 5 秒收不到 ping 视为断开，桌面端 10 秒收不到数据视为断开

## 静音

- 双向同步，受桌面端 `mute_sync` 设置控制（默认开启）
- 静音期间客户端不发送任何音频包
- `isMuted` 缺省按 false 处理

## 音频

`AudioPacketMessageOrdered` 包裹 `AudioPacketMessage`

- `sequenceNumber` 每次连接从 0 开始，每个常规包加 1
- `timestamp` Unix 毫秒
- `codec` 0 为 PCM，1 为 Opus
- `audioFormat` 使用 Android 常量：2 为 PCM16，3 为 PCM8 无符号，4 为 Float32，6 为 PCM24；PCM 样本为小端序，其他取值会被拒绝
- 采样率 8000 到 192000，声道 1 或 2，单包缓冲不超过 64 KiB
- Opus 只支持 8 / 12 / 16 / 24 / 48 kHz，每包一个原始 Opus 帧（Android 用 20 毫秒）
- 走 UDP 时 PCM 每包不超过 1320 字节，并按帧对齐

## FEC

仅 UDP，可选

- 每 12 个常规包之后追加一个校验包
- 校验包的 `buffer` 是这 12 个载荷补零到最长后的 XOR
- `fecBuffer` 为单字节 `01`，用来与常规包区分
- `fecSequenceNumber` 为本组首个序号，`sequenceNumber` 取下一个常规序号但不递增
- `fecPacketLengths` 为 12 个原始长度，每个在 1 到 1320 之间，常规包不得携带

## 与其他实现的差异

- MicWisp 的协议文档称 UDP 为裸 protobuf，实际有 8 字节 MicU 头
- MicWisp 发送 PCM16 时使用 `audioFormat = 1`，桌面端会拒收，正确值是 2
- 官方 MicYou-iOS（v2 分支）使用另一套协议（魔数 `0x694F5354`、端口 8900），无法连接当前桌面端
