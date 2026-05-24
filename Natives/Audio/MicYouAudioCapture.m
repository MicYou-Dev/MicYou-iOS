#import "MicYouAudioCapture.h"

@interface MicYouAudioCapture ()

@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, strong) AVAudioInputNode *inputNode;
@property (nonatomic, assign, readwrite) BOOL isCapturing;
@property (nonatomic, strong) dispatch_queue_t audioQueue;
@property (atomic, assign) float currentLevel;

@end

@implementation MicYouAudioCapture

- (instancetype)init {
    self = [super init];
    if (self) {
        _sampleRate = 44100.0;
        _channelCount = 1;
        _bufferSize = 1024;
        _audioQueue = dispatch_queue_create("com.lanrhyme.micyou.audio", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (BOOL)startCapture {
    if (self.isCapturing) {
        return YES;
    }

    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;

    [session setCategory:AVAudioSessionCategoryPlayAndRecord
             withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker
                   error:&error];
    if (error) {
        NSLog(@"[MicYou] Failed to set audio session category: %@", error.localizedDescription);
        return NO;
    }

    [session setActive:YES error:&error];
    if (error) {
        NSLog(@"[MicYou] Failed to activate audio session: %@", error.localizedDescription);
        return NO;
    }

    self.audioEngine = [[AVAudioEngine alloc] init];
    self.inputNode = [self.audioEngine inputNode];

    AVAudioFormat *format = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16
                                                              sampleRate:self.sampleRate
                                                                channels:(AVAudioChannelCount)self.channelCount
                                                             interleaved:YES];

    if (!format) {
        NSLog(@"[MicYou] Failed to create audio format");
        return NO;
    }

    __weak typeof(self) weakSelf = self;
    [self.inputNode installTapOnBus:0
                         bufferSize:(AVAudioFrameCount)self.bufferSize
                             format:format
                              block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
        [weakSelf processAudioBuffer:buffer time:when];
    }];

    [self.audioEngine prepare];

    BOOL success = [self.audioEngine startAndReturnError:&error];
    if (!success || error) {
        NSLog(@"[MicYou] Failed to start audio engine: %@", error.localizedDescription);
        [self.inputNode removeTapOnBus:0];
        self.audioEngine = nil;
        return NO;
    }

    self.isCapturing = YES;
    NSLog(@"[MicYou] Audio capture started at %.0f Hz, %lu channels", self.sampleRate, (unsigned long)self.channelCount);
    return YES;
}

- (void)stopCapture {
    if (!self.isCapturing) {
        return;
    }

    [self.inputNode removeTapOnBus:0];
    [self.audioEngine stop];
    self.inputNode = nil;
    self.audioEngine = nil;

    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];

    self.isCapturing = NO;
    NSLog(@"[MicYou] Audio capture stopped");
}

- (void)processAudioBuffer:(AVAudioPCMBuffer *)buffer time:(AVAudioTime *)when {
    if (!buffer || buffer.frameLength == 0) return;

    NSUInteger frameLength = buffer.frameLength;
    NSUInteger channels = buffer.format.channelCount;
    NSUInteger sampleCount = frameLength * channels;

    const int16_t *pcmData = buffer.int16ChannelData[0];

    // Calculate level on the audio callback thread (fast float math only, no dispatch needed).
    float maxLevel = 0.0f;
    for (NSUInteger i = 0; i < sampleCount; i++) {
        float normalized = (float)pcmData[i] / 32768.0f;
        float absSample = fabsf(normalized);
        if (absSample > maxLevel) {
            maxLevel = absSample;
        }
    }

    // Update atomic property directly — no dispatch needed, thread-safe via atomic accessor.
    self.currentLevel = maxLevel;

    // Dispatch level callback to main queue (lightweight, decoupled from audioQueue).
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf && strongSelf.delegate) {
            [strongSelf.delegate audioCapture:strongSelf didUpdateLevel:strongSelf.currentLevel];
        }
    });

    // Audio data must be copied here because pcmData is only valid during this
    // AVAudioEngine tap callback. The copy ensures the data outlives the stack frame
    // when dispatched asynchronously to audioQueue.
    NSData *audioData = [NSData dataWithBytes:pcmData length:sampleCount * sizeof(int16_t)];
    uint64_t timestamp = (uint64_t)(when.sampleTime * 1000.0 / self.sampleRate);

    dispatch_async(self.audioQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf && strongSelf.delegate) {
            [strongSelf.delegate audioCapture:strongSelf didCaptureBuffer:audioData timestamp:timestamp];
        }
    });
}

- (void)dealloc {
    [self stopCapture];
}

@end
