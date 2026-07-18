#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * MicYouNotificationManager manages local user notifications for streaming
 * status events (e.g. connection established / lost) using UNUserNotificationCenter.
 *
 * iOS 10+ API is available on every supported deployment target (iOS 11+),
 * so no @available guard is required.
 */
@interface MicYouNotificationManager : NSObject

+ (instancetype)shared;

/**
 * Request authorization for alert / badge / sound.
 * The completion handler is invoked on the main thread.
 */
- (void)requestAuthorizationWithCompletion:(void (^)(BOOL granted))completion;

/**
 * Schedule a local notification with the given title, body and identifier.
 * Reusing the same identifier will replace the previous notification.
 */
- (void)sendNotificationWithTitle:(NSString *)title
                             body:(NSString *)body
                       identifier:(NSString *)identifier;

@end

NS_ASSUME_NONNULL_END
