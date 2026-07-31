#import "MicYouSystemNoiseProcessor.h"
#import "MicYouLogger.h"

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

    // Log pre-apply state so we can verify the session actually changed.
    NSLog(@"[MicYou] SystemNoise: before apply category=%@ mode=%@",
          session.category, session.mode);
    [[MicYouLogger sharedLogger] log:[NSString stringWithFormat:
        @"[SystemNS] before apply: category=%@ mode=%@", session.category, session.mode]];

    if (@available(iOS 13.0, *)) {
        // iOS 13+: one-shot category + mode + options
        BOOL ok = [session setCategory:AVAudioSessionCategoryPlayAndRecord
                                  mode:AVAudioSessionModeVoiceChat
                               options:AVAudioSessionCategoryOptionDefaultToSpeaker
                                 error:error];
        if (!ok) {
            NSLog(@"[MicYou] SystemNoise: setCategory:mode:options: failed (iOS 13+): %@", error ? *error : nil);
            [[MicYouLogger sharedLogger] logError:[NSString stringWithFormat:
                @"[SystemNS] setCategory:mode:options: failed (iOS 13+): %@", error ? *error : nil]];
            return NO;
        }
        NSLog(@"[MicYou] SystemNoise: after apply category=%@ mode=%@ (iOS 13+ path, ok=YES)",
              session.category, session.mode);
        [[MicYouLogger sharedLogger] log:[NSString stringWithFormat:
            @"[SystemNS] after apply: category=%@ mode=%@ (iOS 13+ path, ok=YES)",
            session.category, session.mode]];
        return YES;
    } else {
        // iOS 11/12: setCategory:withOptions: then setMode:
        BOOL ok = [session setCategory:AVAudioSessionCategoryPlayAndRecord
                          withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker
                                error:error];
        if (!ok) {
            NSLog(@"[MicYou] SystemNoise: setCategory:withOptions: failed (iOS 11/12): %@", error ? *error : nil);
            [[MicYouLogger sharedLogger] logError:[NSString stringWithFormat:
                @"[SystemNS] setCategory:withOptions: failed (iOS 11/12): %@", error ? *error : nil]];
            return NO;
        }
        ok = [session setMode:AVAudioSessionModeVoiceChat error:error];
        if (!ok) {
            NSLog(@"[MicYou] SystemNoise: setMode: failed (iOS 11/12): %@", error ? *error : nil);
            [[MicYouLogger sharedLogger] logError:[NSString stringWithFormat:
                @"[SystemNS] setMode: failed (iOS 11/12): %@", error ? *error : nil]];
            return NO;
        }
        NSLog(@"[MicYou] SystemNoise: after apply category=%@ mode=%@ (iOS 11/12 path, ok=YES)",
              session.category, session.mode);
        [[MicYouLogger sharedLogger] log:[NSString stringWithFormat:
            @"[SystemNS] after apply: category=%@ mode=%@ (iOS 11/12 path, ok=YES)",
            session.category, session.mode]];
        return YES;
    }
}

- (BOOL)isSupportedOnCurrentSystem {
    // AVAudioSessionModeVoiceChat is available on iOS 5.0+.
    return YES;
}

- (void)reset {
    // No-op: system-level processing has no per-app internal state.
}

@end
