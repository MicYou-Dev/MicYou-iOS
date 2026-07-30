#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Wrapper for iOS system-level noise suppression via AVAudioSession
/// VoiceCommunication mode. On iOS 13+ uses setCategory:mode:options:;
/// on iOS 11/12 falls back to setCategory:withOptions: + setMode:.
@interface MicYouSystemNoiseProcessor : NSObject

/// Apply VoiceCommunication mode to the given audio session.
/// - Parameters:
///   - session: The shared AVAudioSession instance.
///   - error: Pointer to receive error if configuration fails.
/// - Returns: YES if configuration succeeded, NO on error.
- (BOOL)applyToAudioSession:(AVAudioSession *)session error:(NSError **)error;

/// Whether the current system supports VoiceCommunication mode.
/// Always returns YES — VoiceCommunication is available on iOS 11+.
- (BOOL)isSupportedOnCurrentSystem;

/// Reset internal state (no-op for system-level processor, kept for API symmetry).
- (void)reset;

@end

NS_ASSUME_NONNULL_END
