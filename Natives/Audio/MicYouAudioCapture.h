#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class MicYouAudioCapture;

@protocol MicYouAudioCaptureDelegate <NSObject>

- (void)audioCapture:(MicYouAudioCapture *)capture didCaptureBuffer:(NSData *)buffer timestamp:(uint64_t)timestamp;
- (void)audioCapture:(MicYouAudioCapture *)capture didUpdateLevel:(float)level;

@end

/// Noise suppression algorithm selection.
typedef NS_ENUM(NSInteger, MicYouNoiseSuppressionType) {
    MicYouNoiseSuppressionTypeOff     = 0,
    MicYouNoiseSuppressionTypeRNNoise = 1,
    MicYouNoiseSuppressionTypeSystem  = 2,
};

@interface MicYouAudioCapture : NSObject

@property (nonatomic, weak) id<MicYouAudioCaptureDelegate> delegate;
@property (nonatomic, readonly) BOOL isCapturing;
@property (nonatomic, assign) double sampleRate;
@property (nonatomic, assign) NSUInteger channelCount;
@property (nonatomic, assign) NSUInteger bufferSize;

/// Master switch for noise suppression. Default NO.
@property (nonatomic, assign) BOOL noiseSuppressionEnabled;

/// Algorithm to use when `noiseSuppressionEnabled == YES`. Default Off.
@property (nonatomic, assign) MicYouNoiseSuppressionType noiseSuppressionType;

/// RNNoise intensity in [0, 100]. Only meaningful when type == RNNoise. Default 70.
@property (nonatomic, assign) float noiseSuppressionIntensity;

- (BOOL)startCapture;
- (void)stopCapture;

@end
