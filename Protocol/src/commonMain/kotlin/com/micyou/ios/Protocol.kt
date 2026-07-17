package com.micyou.ios

object MicYouProtocolConstants {
    const val MAGIC_HEADER: UInt = 0x694F5354u

    const val PACKET_TYPE_HANDSHAKE: UInt = 1u
    const val PACKET_TYPE_AUDIO: UInt = 2u
    const val PACKET_TYPE_CONTROL: UInt = 3u
    const val PACKET_TYPE_HEARTBEAT: UInt = 4u
    const val PACKET_TYPE_CONFIG: UInt = 5u

    const val DEFAULT_SAMPLE_RATE = 44100
    const val DEFAULT_CHANNELS = 1
    const val DEFAULT_BITS_PER_SAMPLE = 16
    const val DEFAULT_PORT = 8900
}

data class MicYouPacketHeader(
    val magic: UInt = MicYouProtocolConstants.MAGIC_HEADER,
    val type: UInt,
    val length: UInt,
    val timestamp: ULong,
    val sequence: UInt
)

data class MicYouHandshakePayload(
    val sampleRate: UInt = MicYouProtocolConstants.DEFAULT_SAMPLE_RATE.toUInt(),
    val channels: UInt = MicYouProtocolConstants.DEFAULT_CHANNELS.toUInt(),
    val bitsPerSample: UInt = MicYouProtocolConstants.DEFAULT_BITS_PER_SAMPLE.toUInt()
)

data class MicYouAudioPacket(
    val timestamp: ULong,
    val sequence: UInt,
    val pcmData: ByteArray
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other == null || this::class != other::class) return false
        other as MicYouAudioPacket
        return timestamp == other.timestamp &&
                sequence == other.sequence &&
                pcmData.contentEquals(other.pcmData)
    }

    override fun hashCode(): Int {
        var result = timestamp.hashCode()
        result = 31 * result + sequence.hashCode()
        result = 31 * result + pcmData.contentHashCode()
        return result
    }
}

data class MicYouControlPacket(
    val command: UInt,
    val parameter: UInt
)

data class MicYouConfigPacket(
    val key: String,
    val value: String
)
