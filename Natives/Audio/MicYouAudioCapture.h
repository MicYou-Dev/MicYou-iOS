#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class MicYouAudioCapture;

@protocol MicYouAudioCaptureDelegate <NSObject>

- (void)audioCapture:(MicYouAudioCapture *)capture didCaptureBuffer:(NSData *)buffer timestamp:(uint64_t)timestamp;
- (void)audioCapture:(MicYouAudioCapture *)capture didUpdateLevel:(float)level;

@end

@interface MicYouAudioCapture : NSObject

@property (nonatomic, weak) id<MicYouAudioCaptureDelegate> delegate;
@property (nonatomic, readonly) BOOL isCapturing;
@property (nonatomic, assign) double sampleRate;
@property (nonatomic, assign) NSUInteger channelCount;
@property (nonatomic, assign) NSUInteger bufferSize;

- (BOOL)startCapture;
- (void)stopCapture;

@end
