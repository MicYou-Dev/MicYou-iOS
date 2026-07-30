#import "MicYouSystemNoiseProcessor.h"

@implementation MicYouSystemNoiseProcessor

- (BOOL)applyToAudioSession:(AVAudioSession *)session error:(NSError **)error {
    if (session == nil) {
        if (error) {
            *error = [NSError errorWithDomain:@"MicYouSystemNoiseProcessor"
                                          code:1
                                      userInfo:@{NSLocalizedDescriptionKey: @"session is nil"}];
        }
        return NO;
    }

    if (@available(iOS 13.0, *)) {
        // iOS 13+: one-shot category + mode + options
        BOOL ok = [session setCategory:AVAudioSessionCategoryPlayAndRecord
                                  mode:AVAudioSessionModeVoiceCommunication
                               options:AVAudioSessionCategoryOptionDefaultToSpeaker
                                 error:error];
        if (!ok) {
            NSLog(@"[MicYou] Failed to set VoiceCommunication category (iOS 13+): %@", error ? *error : nil);
            return NO;
        }
        return YES;
    } else {
        // iOS 11/12: setCategory:withOptions: then setMode:
        BOOL ok = [session setCategory:AVAudioSessionCategoryPlayAndRecord
                          withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker
                                error:error];
        if (!ok) {
            NSLog(@"[MicYou] Failed to set category (iOS 11/12): %@", error ? *error : nil);
            return NO;
        }
        ok = [session setMode:AVAudioSessionModeVoiceCommunication error:error];
        if (!ok) {
            NSLog(@"[MicYou] Failed to set VoiceCommunication mode (iOS 11/12): %@", error ? *error : nil);
            return NO;
        }
        return YES;
    }
}

- (BOOL)isSupportedOnCurrentSystem {
    // VoiceCommunication mode is available on iOS 11+.
    return YES;
}

- (void)reset {
    // No-op: system-level processing has no per-app internal state.
}

@end
