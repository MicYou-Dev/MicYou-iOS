#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MicYouUpdateStatus) {
    MicYouUpdateStatusUpToDate,
    MicYouUpdateStatusUpdateAvailable,
    MicYouUpdateStatusError
};

/**
 * MicYouUpdateChecker queries the GitHub Releases API for the latest
 * MicYou-iOS release and compares its tag_name against the installed
 * CFBundleShortVersionString using semantic version comparison.
 *
 * The completion handler is always invoked on the main thread. On error
 * the latestVersion / releaseURL are nil.
 */
@interface MicYouUpdateChecker : NSObject

+ (instancetype)shared;

- (void)checkForUpdateWithCompletion:(void (^)(MicYouUpdateStatus status,
                                               NSString * _Nullable latestVersion,
                                               NSURL * _Nullable releaseURL))completion;

/**
 * Returns the installed app version from CFBundleShortVersionString.
 * Falls back to "0.0.0" when the value is missing.
 */
- (NSString *)currentAppVersion;

@end

NS_ASSUME_NONNULL_END
