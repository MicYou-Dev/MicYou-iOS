#import "TransportClient.h"
#import "Protocol.h"
#import "MicYouLogger.h"
#import <CFNetwork/CFNetwork.h>
#import <UIKit/UIKit.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>

@interface TransportClient ()

@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) NSOutputStream *outputStream;
@property (nonatomic, strong) dispatch_queue_t networkQueue;
@property (nonatomic, assign, readwrite) BOOL isConnected;
@property (nonatomic, assign, readwrite) BOOL disconnecting;
@property (nonatomic, strong, readwrite) NSString *host;
@property (nonatomic, assign, readwrite) int port;
@property (nonatomic, strong) NSMutableData *readBuffer;
@property (nonatomic, assign) CFSocketRef udpSocket;
@property (nonatomic, assign) int udpPort;
@property (nonatomic, assign) uint32_t sequenceCounter;
@property (nonatomic, strong) NSTimer *keepAliveTimer;

@end

@implementation TransportClient

- (instancetype)init {
    self = [super init];
    if (self) {
        _networkQueue = dispatch_queue_create("com.lanrhyme.micyou.network", DISPATCH_QUEUE_SERIAL);
        _readBuffer = [[NSMutableData alloc] init];
        _udpPort = 0;
        _sequenceCounter = 0;
    }
    return self;
}

- (void)connectToHost:(NSString *)host port:(int)port completion:(void (^)(BOOL success))completion {
    if (self.isConnected) {
        if (completion) completion(YES);
        return;
    }

    self.host = host;
    self.port = port;
    
    [[MicYouLogger sharedLogger] log:[NSString stringWithFormat:@"TransportClient: Connecting to %@:%d", host, port]];

    dispatch_async(self.networkQueue, ^{
        CFReadStreamRef readStream = NULL;
        CFWriteStreamRef writeStream = NULL;
        CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)host, port, &readStream, &writeStream);

        if (!readStream || !writeStream) {
            [[MicYouLogger sharedLogger] logError:@"TransportClient: Failed to create socket pair"];
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO);
                });
            }
            return;
        }

        self.inputStream = (__bridge_transfer NSInputStream *)readStream;
        self.outputStream = (__bridge_transfer NSOutputStream *)writeStream;

        [self.inputStream setDelegate:self];
        [self.outputStream setDelegate:self];

        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [self.inputStream scheduleInRunLoop:runLoop forMode:NSDefaultRunLoopMode];
        [self.outputStream scheduleInRunLoop:runLoop forMode:NSDefaultRunLoopMode];

        [self.inputStream open];
        [self.outputStream open];

        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 2.0, false);

        if (self.outputStream.streamStatus == NSStreamStatusOpen) {
            self.isConnected = YES;
            [[MicYouLogger sharedLogger] log:@"TransportClient: TCP connected successfully"];
            [self sendHello];
            [self startKeepAliveTimer];
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(YES);
                });
            }
            if ([self.delegate respondsToSelector:@selector(transportClientDidConnect:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate transportClientDidConnect:self];
                });
            }
        } else {
            [[MicYouLogger sharedLogger] logError:[NSString stringWithFormat:@"TransportClient: Failed to open stream, status=%ld", (long)self.outputStream.streamStatus]];
            [self cleanupStreamsInRunLoop:runLoop];
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO);
                });
            }
        }
    });
}

- (void)setupUDPSocket:(NSString *)host port:(int)port {
    if (self.udpSocket) {
        CFSocketInvalidate(self.udpSocket);
        CFRelease(self.udpSocket);
        self.udpSocket = NULL;
    }

    CFSocketContext context = {0, (__bridge void *)self, NULL, NULL, NULL};
    self.udpSocket = CFSocketCreate(NULL, AF_INET, SOCK_DGRAM, IPPROTO_UDP, 0, NULL, &context);

    if (!self.udpSocket) {
        [[MicYouLogger sharedLogger] logError:@"TransportClient: Failed to create UDP socket"];
        return;
    }

    struct sockaddr_in localAddr;
    memset(&localAddr, 0, sizeof(localAddr));
    localAddr.sin_len = sizeof(localAddr);
    localAddr.sin_family = AF_INET;
    localAddr.sin_port = htons(0);
    localAddr.sin_addr.s_addr = INADDR_ANY;

    CFDataRef localAddressData = CFDataCreate(NULL, (const UInt8 *)&localAddr, sizeof(localAddr));
    CFSocketError bindResult = CFSocketSetAddress(self.udpSocket, localAddressData);
    if (localAddressData) CFRelease(localAddressData);

    if (bindResult != kCFSocketSuccess) {
        [[MicYouLogger sharedLogger] logError:@"TransportClient: Failed to bind UDP socket"];
        CFSocketInvalidate(self.udpSocket);
        CFRelease(self.udpSocket);
        self.udpSocket = NULL;
        return;
    }

    CFDataRef addrData = CFSocketCopyAddress(self.udpSocket);
    if (addrData) {
        struct sockaddr_in *boundAddr = (struct sockaddr_in *)CFDataGetBytePtr(addrData);
        int localPort = ntohs(boundAddr->sin_port);
        [[MicYouLogger sharedLogger] log:[NSString stringWithFormat:@"TransportClient: UDP socket bound to local port %d", localPort]];
        CFRelease(addrData);
    }

    struct sockaddr_in remoteAddr;
    memset(&remoteAddr, 0, sizeof(remoteAddr));
    remoteAddr.sin_len = sizeof(remoteAddr);
    remoteAddr.sin_family = AF_INET;
    remoteAddr.sin_port = htons(port);
    inet_pton(AF_INET, [host UTF8String], &remoteAddr.sin_addr);

    CFDataRef remoteAddressData = CFDataCreate(NULL, (const UInt8 *)&remoteAddr, sizeof(remoteAddr));
    CFSocketError connectResult = CFSocketConnectToAddress(self.udpSocket, remoteAddressData, 0);
    if (remoteAddressData) CFRelease(remoteAddressData);

    if (connectResult != kCFSocketSuccess) {
        [[MicYouLogger sharedLogger] logError:@"TransportClient: Failed to connect UDP socket to remote address"];
        CFSocketInvalidate(self.udpSocket);
        CFRelease(self.udpSocket);
        self.udpSocket = NULL;
        return;
    }

    [[MicYouLogger sharedLogger] log:@"TransportClient: UDP socket setup complete"];
}

- (void)disconnect {
    if (!self.isConnected || self.disconnecting) return;
    self.disconnecting = YES;

    [self sendDisconnect];

    dispatch_async(self.networkQueue, ^{
        [self cleanupStreams];
        self.isConnected = NO;
        self.disconnecting = NO;

        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(transportClientDidDisconnect:)]) {
                [self.delegate transportClientDidDisconnect:self];
            }
        });
    });
}

- (void)cleanupStreams {
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    [self cleanupStreamsInRunLoop:runLoop];
}

- (void)cleanupStreamsInRunLoop:(NSRunLoop *)runLoop {
    [self stopKeepAliveTimer];

    [self.inputStream setDelegate:nil];
    [self.outputStream setDelegate:nil];

    [self.inputStream close];
    [self.outputStream close];
    [self.inputStream removeFromRunLoop:runLoop forMode:NSDefaultRunLoopMode];
    [self.outputStream removeFromRunLoop:runLoop forMode:NSDefaultRunLoopMode];
    self.inputStream = nil;
    self.outputStream = nil;

    if (self.udpSocket) {
        CFSocketInvalidate(self.udpSocket);
        CFRelease(self.udpSocket);
        self.udpSocket = NULL;
    }

    self.udpPort = 0;
}

- (void)sendHello {
    NSString *deviceName = [[UIDevice currentDevice] name];
    NSString *deviceId = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    if (!deviceId) deviceId = @"unknown";

    NSData *hello = [MicYouProtocol encodeHelloWithDeviceName:deviceName
                                                       deviceId:deviceId
                                                     sampleRate:44100
                                                    channelCount:1];
    [self sendControlMessage:hello];
}

- (void)sendDisconnect {
    NSData *disconnect = [MicYouProtocol encodeDisconnectWithReason:@"User disconnected"];
    [self sendControlMessage:disconnect];
}

- (void)sendKeepAlive {
    if (!self.isConnected) return;
    NSData *keepAlive = [MicYouProtocol encodeKeepAliveWithSequence:++self.sequenceCounter];
    [self sendControlMessage:keepAlive];
}

- (void)startKeepAliveTimer {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.keepAliveTimer invalidate];
        self.keepAliveTimer = nil;
        self.keepAliveTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                                 target:self
                                                               selector:@selector(sendKeepAlive)
                                                               userInfo:nil
                                                                repeats:YES];
    });
}

- (void)stopKeepAliveTimer {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.keepAliveTimer invalidate];
        self.keepAliveTimer = nil;
    });
}

- (void)sendAudioData:(NSData *)data timestamp:(uint64_t)timestamp {
    if (!self.isConnected || !data) return;

    uint32_t seq = ++self.sequenceCounter;
    NSData *packet = [MicYouProtocol encodeAudioFrame:data
                                            timestamp:timestamp
                                             sequence:seq
                                           sampleRate:44100
                                          channelCount:1];

    if (self.udpSocket && self.udpPort > 0) {
        CFSocketError result = CFSocketSendData(self.udpSocket, NULL, (__bridge CFDataRef)packet, 0);
        if (result != kCFSocketSuccess) {
            [self sendControlMessage:packet];
        }
    } else {
        [self sendControlMessage:packet];
    }
}

- (void)sendControlMessage:(NSData *)data {
    if (!self.outputStream || self.outputStream.streamStatus != NSStreamStatusOpen) return;

    dispatch_async(self.networkQueue, ^{
        const uint8_t *bytes = data.bytes;
        NSUInteger length = data.length;
        NSUInteger totalWritten = 0;

        while (totalWritten < length) {
            NSInteger written = [self.outputStream write:&bytes[totalWritten] maxLength:length - totalWritten];
            if (written <= 0) break;
            totalWritten += written;
        }
    });
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventOpenCompleted:
            break;
        case NSStreamEventHasBytesAvailable: {
            uint8_t buffer[4096];
            NSInteger read = [self.inputStream read:buffer maxLength:sizeof(buffer)];
            if (read > 0) {
                [self.readBuffer appendBytes:buffer length:read];
                [self processReadBuffer];
            }
            break;
        }
        case NSStreamEventHasSpaceAvailable:
            break;
        case NSStreamEventErrorOccurred: {
            NSError *error = [aStream streamError];
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(transportClient:didReceiveError:)]) {
                    [self.delegate transportClient:self didReceiveError:error];
                }
            });
            [self disconnect];
            break;
        }
        case NSStreamEventEndEncountered:
            [self disconnect];
            break;
        default:
            break;
    }
}

- (void)processReadBuffer {
    while (self.readBuffer.length >= sizeof(MicYouMessageHeader)) {
        MicYouMessageHeader header;
        [self.readBuffer getBytes:&header length:sizeof(header)];

        header.magic = ntohl(header.magic);
        header.type = ntohl(header.type);
        header.payloadLength = ntohl(header.payloadLength);
        header.sequence = ntohl(header.sequence);

        if (header.magic != kMicYouMagicHeader) {
            [self.readBuffer replaceBytesInRange:NSMakeRange(0, 1) withBytes:NULL length:0];
            continue;
        }

        NSUInteger totalLength = sizeof(MicYouMessageHeader) + header.payloadLength;
        if (self.readBuffer.length < totalLength) break;

        NSData *payload = [self.readBuffer subdataWithRange:NSMakeRange(sizeof(MicYouMessageHeader), header.payloadLength)];
        [self.readBuffer replaceBytesInRange:NSMakeRange(0, totalLength) withBytes:NULL length:0];

        [self handleMessageWithType:header.type payload:payload];
    }
}

- (void)handleMessageWithType:(uint32_t)type payload:(NSData *)payload {
    [[MicYouLogger sharedLogger] log:[NSString stringWithFormat:@"TransportClient: Received message type=%u, payload=%lu bytes", type, (unsigned long)payload.length]];
    
    switch (type) {
        case MicYouMessageTypeAck: {
            [[MicYouLogger sharedLogger] log:@"TransportClient: Received ACK"];
            [self handleAckPayload:payload];
            break;
        }
        case MicYouMessageTypeKeepAlive: {
            break;
        }
        default:
            break;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(transportClient:didReceiveData:)]) {
            [self.delegate transportClient:self didReceiveData:payload];
        }
    });
}

- (void)handleAckPayload:(NSData *)payload {
    if (payload.length < 9) {
        [[MicYouLogger sharedLogger] logError:@"TransportClient: ACK payload too short"];
        return;
    }

    const uint8_t *bytes = payload.bytes;
    BOOL success = bytes[0] != 0;

    uint32_t udpPort;
    memcpy(&udpPort, &bytes[1], sizeof(udpPort));
    udpPort = ntohl(udpPort);

    uint32_t msgLen;
    memcpy(&msgLen, &bytes[5], sizeof(msgLen));
    msgLen = ntohl(msgLen);

    [[MicYouLogger sharedLogger] log:[NSString stringWithFormat:@"TransportClient: ACK success=%d, udpPort=%u", success, (unsigned int)udpPort]];

    if (success && udpPort > 0) {
        self.udpPort = udpPort;
        [self setupUDPSocket:self.host port:udpPort];
    }
}

- (void)dealloc {
    self.delegate = nil;
    [self disconnect];
}

@end
