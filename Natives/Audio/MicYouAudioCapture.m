#import "MicYouAudioCapture.h"
#import "MicYouRNNoiseProcessor.h"
#import "MicYouSystemNoiseProcessor.h"

@interface MicYouAudioCapture ()

@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, strong) AVAudioInputNode *inputNode;
@property (nonatomic, assign, readwrite) BOOL isCapturing;
@property (nonatomic, strong) dispatch_queue_t audioQueue;
@property (atomic, assign) float currentLevel;

// Noise suppression processors (lazy-initialized on startCapture).
@property (nonatomic, strong, nullable) MicYouRNNoiseProcessor *rnnoiseProcessor;
@property (nonatomic, strong, nullable) MicYouSystemNoiseProcessor *systemProcessor;

@end

@implementation MicYouAudioCapture

- (instancetype)init {
    self = [super init];
    if (self) {
        _sampleRate = 44100.0;
        _channelCount = 1;
        _bufferSize = 1024;
        _audioQueue = dispatch_queue_create("com.lanrhyme.micyou.audio", DISPATCH_QUEUE_SERIAL);

        _noiseSuppressionEnabled = NO;
        _noiseSuppressionType = MicYouNoiseSuppressionTypeOff;
        _noiseSuppressionIntensity = 70.0f;
    }
    return self;
}

- (BOOL)startCapture {
    if (self.isCapturing) {
        return YES;
    }

    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;

    // System-level noise suppression: switch the shared session to
    // VoiceCommunication mode so iOS performs AEC + NS at the system layer.
    NSLog(@"[MicYou] startCapture: noiseSuppression enabled=%d type=%ld intensity=%.1f",
          (int)self.noiseSuppressionEnabled,
          (long)self.noiseSuppressionType,
          (double)self.noiseSuppressionIntensity);
    if (self.noiseSuppressionEnabled
        && self.noiseSuppressionType == MicYouNoiseSuppressionTypeSystem) {
        if (self.systemProcessor == nil) {
            self.systemProcessor = [[MicYouSystemNoiseProcessor alloc] init];
        }
        if (![self.systemProcessor applyToAudioSession:session error:&error]) {
            NSLog(@"[MicYou] System noise suppression failed to apply: %@",
                  error.localizedDescription);
            // Fall through to default category below; don't fail startCapture.
            error = nil;
        }
    } else {
        // Default path: PlayAndRecord + DefaultToSpeaker, no VoiceCommunication mode.
        [session setCategory:AVAudioSessionCategoryPlayAndRecord
                 withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker
                       error:&error];
        if (error) {
            NSLog(@"[MicYou] Failed to set audio session category: %@", error.localizedDescription);
            return NO;
        }
    }

    [session setActive:YES error:&error];
    if (error) {
        NSLog(@"[MicYou] Failed to activate audio session: %@", error.localizedDescription);
        return NO;
    }

    // RNNoise processor lifecycle: created at startCapture, destroyed at stopCapture.
    if (self.noiseSuppressionEnabled
        && self.noiseSuppressionType == MicYouNoiseSuppressionTypeRNNoise
        && self.rnnoiseProcessor == nil) {
        self.rnnoiseProcessor = [[MicYouRNNoiseProcessor alloc] initWithSampleRate:self.sampleRate
                                                                          channels:self.channelCount];
        if (!self.rnnoiseProcessor) {
            NSLog(@"[MicYou] RNNoise processor init failed; falling back to passthrough.");
        }
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
    NSLog(@"[MicYou] Audio capture started at %.0f Hz, %lu channels (NS: %d, type: %ld, intensity: %.1f)",
          self.sampleRate, (unsigned long)self.channelCount,
          (int)self.noiseSuppressionEnabled, (long)self.noiseSuppressionType,
          (double)self.noiseSuppressionIntensity);
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

    // Release RNNoise state to free RNN weights and per-channel accumulators.
    // systemProcessor is lightweight (stateless); kept around in case the user
    // toggles the setting back on next session.
    self.rnnoiseProcessor = nil;

    self.isCapturing = NO;
    NSLog(@"[MicYou] Audio capture stopped");
}

- (void)processAudioBuffer:(AVAudioPCMBuffer *)buffer time:(AVAudioTime *)when {
    if (!buffer || buffer.frameLength == 0) return;

    NSUInteger frameLength = buffer.frameLength;
    NSUInteger channels = buffer.format.channelCount;
    NSUInteger sampleCount = frameLength * channels;

    const int16_t *pcmData = buffer.int16ChannelData[0];

    // Build the working NSData. If RNNoise is active, the working buffer holds
    // denoised samples; otherwise it holds the original PCM16 captured data.
    NSData *audioData;
    if (self.noiseSuppressionEnabled
        && self.noiseSuppressionType == MicYouNoiseSuppressionTypeRNNoise
        && self.rnnoiseProcessor != nil) {
        NSData *rawData = [NSData dataWithBytes:pcmData length:sampleCount * sizeof(int16_t)];
        audioData = [self.rnnoiseProcessor process:rawData intensity:self.noiseSuppressionIntensity];
    } else {
        audioData = [NSData dataWithBytes:pcmData length:sampleCount * sizeof(int16_t)];
    }

    // Level metering on the (possibly denoised) PCM16 data.
    const int16_t *levelData = (const int16_t *)audioData.bytes;
    NSUInteger levelSampleCount = audioData.length / sizeof(int16_t);
    float maxLevel = 0.0f;
    for (NSUInteger i = 0; i < levelSampleCount; i++) {
        float normalized = (float)levelData[i] / 32768.0f;
        float absSample = fabsf(normalized);
        if (absSample > maxLevel) {
            maxLevel = absSample;
        }
    }

    self.currentLevel = maxLevel;

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf && strongSelf.delegate) {
            [strongSelf.delegate audioCapture:strongSelf didUpdateLevel:strongSelf.currentLevel];
        }
    });

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
