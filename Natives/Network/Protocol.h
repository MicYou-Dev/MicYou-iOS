#import <Foundation/Foundation.h>

#define kMicYouMagicHeader 0x694F5354

typedef NS_ENUM(uint32_t, MicYouMessageType) {
    MicYouMessageTypeHello = 1,
    MicYouMessageTypeAck = 2,
    MicYouMessageTypeKeepAlive = 3,
    MicYouMessageTypeDisconnect = 4,
    MicYouMessageTypeAudioFrame = 16
};

typedef struct {
    uint32_t magic;
    uint32_t type;
    uint32_t payloadLength;
    uint32_t sequence;
} __attribute__((packed)) MicYouMessageHeader;

typedef struct {
    uint32_t sampleRate;
    uint32_t channelCount;
    uint32_t bitDepth;
} __attribute__((packed)) MicYouAudioConfig;

@interface MicYouProtocol : NSObject

+ (NSData *)encodeHelloWithDeviceName:(NSString *)deviceName
                             deviceId:(NSString *)deviceId
                           sampleRate:(uint32_t)sampleRate
                          channelCount:(uint32_t)channelCount;

+ (NSData *)encodeAudioFrame:(NSData *)pcmData
                   timestamp:(uint64_t)timestamp
                    sequence:(uint32_t)sequence
                  sampleRate:(uint32_t)sampleRate
                 channelCount:(uint32_t)channelCount;

+ (NSData *)encodeKeepAliveWithSequence:(uint32_t)sequence;

+ (NSData *)encodeDisconnectWithReason:(NSString *)reason;

+ (BOOL)decodeHeader:(NSData *)data header:(MicYouMessageHeader *)header;

+ (NSData *)decodePayload:(NSData *)data header:(MicYouMessageHeader)header;

@end
