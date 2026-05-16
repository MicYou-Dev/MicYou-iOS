#import "Protocol.h"
#import <arpa/inet.h>

@implementation MicYouProtocol

+ (uint32_t)hostToBigEndian32:(uint32_t)value {
    return htonl(value);
}

+ (uint32_t)bigEndianToHost32:(uint32_t)value {
    return ntohl(value);
}

+ (NSData *)encodeHeaderWithType:(MicYouMessageType)type payloadLength:(uint32_t)payloadLength sequence:(uint32_t)sequence {
    MicYouMessageHeader header;
    header.magic = [self hostToBigEndian32:kMicYouMagicHeader];
    header.type = [self hostToBigEndian32:(uint32_t)type];
    header.payloadLength = [self hostToBigEndian32:payloadLength];
    header.sequence = [self hostToBigEndian32:sequence];

    return [NSData dataWithBytes:&header length:sizeof(header)];
}

+ (NSData *)encodeHelloWithDeviceName:(NSString *)deviceName
                             deviceId:(NSString *)deviceId
                           sampleRate:(uint32_t)sampleRate
                          channelCount:(uint32_t)channelCount {
    NSMutableData *payload = [NSMutableData data];

    NSData *nameData = [deviceName dataUsingEncoding:NSUTF8StringEncoding];
    NSData *idData = [deviceId dataUsingEncoding:NSUTF8StringEncoding];

    uint32_t nameLen = [self hostToBigEndian32:(uint32_t)nameData.length];
    uint32_t idLen = [self hostToBigEndian32:(uint32_t)idData.length];
    uint32_t sr = [self hostToBigEndian32:sampleRate];
    uint32_t ch = [self hostToBigEndian32:channelCount];

    [payload appendBytes:&nameLen length:4];
    [payload appendData:nameData];
    [payload appendBytes:&idLen length:4];
    [payload appendData:idData];
    [payload appendBytes:&sr length:4];
    [payload appendBytes:&ch length:4];

    NSData *header = [self encodeHeaderWithType:MicYouMessageTypeHello payloadLength:(uint32_t)payload.length sequence:0];

    NSMutableData *packet = [NSMutableData data];
    [packet appendData:header];
    [packet appendData:payload];

    return packet;
}

+ (NSData *)encodeAudioFrame:(NSData *)pcmData
                   timestamp:(uint64_t)timestamp
                    sequence:(uint32_t)sequence
                  sampleRate:(uint32_t)sampleRate
                 channelCount:(uint32_t)channelCount {
    NSMutableData *payload = [NSMutableData data];

    uint32_t seq = [self hostToBigEndian32:sequence];
    uint64_t ts = timestamp;
    uint32_t sr = [self hostToBigEndian32:sampleRate];
    uint32_t ch = [self hostToBigEndian32:channelCount];
    uint32_t dataLen = [self hostToBigEndian32:(uint32_t)pcmData.length];

    [payload appendBytes:&seq length:4];
    [payload appendBytes:&ts length:8];
    [payload appendBytes:&sr length:4];
    [payload appendBytes:&ch length:4];
    [payload appendBytes:&dataLen length:4];
    [payload appendData:pcmData];

    NSData *header = [self encodeHeaderWithType:MicYouMessageTypeAudioFrame payloadLength:(uint32_t)payload.length sequence:sequence];

    NSMutableData *packet = [NSMutableData data];
    [packet appendData:header];
    [packet appendData:payload];

    return packet;
}

+ (NSData *)encodeKeepAliveWithSequence:(uint32_t)sequence {
    NSData *header = [self encodeHeaderWithType:MicYouMessageTypeKeepAlive payloadLength:0 sequence:sequence];
    return header;
}

+ (NSData *)encodeDisconnectWithReason:(NSString *)reason {
    NSData *reasonData = [reason dataUsingEncoding:NSUTF8StringEncoding];
    uint32_t len = [self hostToBigEndian32:(uint32_t)reasonData.length];

    NSMutableData *payload = [NSMutableData data];
    [payload appendBytes:&len length:4];
    [payload appendData:reasonData];

    NSData *header = [self encodeHeaderWithType:MicYouMessageTypeDisconnect payloadLength:(uint32_t)payload.length sequence:0];

    NSMutableData *packet = [NSMutableData data];
    [packet appendData:header];
    [packet appendData:payload];

    return packet;
}

+ (BOOL)decodeHeader:(NSData *)data header:(MicYouMessageHeader *)header {
    if (data.length < sizeof(MicYouMessageHeader)) {
        return NO;
    }

    [data getBytes:header length:sizeof(MicYouMessageHeader)];

    header->magic = [self bigEndianToHost32:header->magic];
    header->type = [self bigEndianToHost32:header->type];
    header->payloadLength = [self bigEndianToHost32:header->payloadLength];
    header->sequence = [self bigEndianToHost32:header->sequence];

    return header->magic == kMicYouMagicHeader;
}

+ (NSData *)decodePayload:(NSData *)data header:(MicYouMessageHeader)header {
    NSUInteger totalLength = sizeof(MicYouMessageHeader) + header.payloadLength;
    if (data.length < totalLength) {
        return nil;
    }

    return [data subdataWithRange:NSMakeRange(sizeof(MicYouMessageHeader), header.payloadLength)];
}

@end
