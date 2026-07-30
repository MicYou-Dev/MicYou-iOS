#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Wrapper for RNNoise C library. Per-channel DenoiseState to avoid RNN state
/// cross-contamination. Processes 480-sample frames (RNNoise fixed frame size);
/// samples below this threshold are accumulated internally.
@interface MicYouRNNoiseProcessor : NSObject

/// Initialize with sample rate and channel count.
/// - Parameters:
///   - sampleRate: PCM sample rate (e.g., 44100, 48000). Currently RNNoise is
///     sample-rate agnostic (it always operates on 480-sample frames), but we
///     keep the parameter for future extensibility.
///   - channels: Number of interleaved channels (1=mono, 2=stereo).
- (instancetype)initWithSampleRate:(double)sampleRate
                           channels:(NSUInteger)channels NS_DESIGNATED_INITIALIZER;

/// Process a chunk of interleaved PCM16 (little-endian signed 16-bit) audio data.
/// - Parameters:
///   - pcm16Data: Input NSData containing interleaved int16 samples (host-endian,
///     which is little-endian on arm64).
///   - intensity: Noise suppression intensity in [0, 100]. 0 = bypass (passthrough),
///     100 = full denoised output. Internally implemented as wet/dry mix:
///       output = original * (1 - mix) + clean * mix, where mix = intensity / 100.
/// - Returns: New NSData containing processed PCM16 (same length as input if
///   accumulation aligns; otherwise output length matches input length by
///   truncating or padding leftover samples as transparent passthrough).
- (NSData *)process:(NSData *)pcm16Data intensity:(float)intensity;

/// Reset internal state: destroy and recreate DenoiseState for each channel,
/// clear accumulation buffers. Call this when audio session is interrupted or
/// sample rate changes.
- (void)reset;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
