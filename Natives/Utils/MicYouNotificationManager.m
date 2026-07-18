#import "MicYouNotificationManager.h"
#import "MicYouLogger.h"

@interface MicYouNotificationManager () <UNUserNotificationCenterDelegate>
@end

@implementation MicYouNotificationManager

+ (instancetype)shared {
    static MicYouNotificationManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MicYouNotificationManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Configure the shared notification center delegate up-front so that
        // notifications are surfaced while the app is in the foreground too.
        [UNUserNotificationCenter currentNotificationCenter].delegate = self;
    }
    return self;
}

- (void)requestAuthorizationWithCompletion:(void (^)(BOOL granted))completion {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    UNAuthorizationOptions options = UNAuthorizationOptionAlert
                                   | UNAuthorizationOptionBadge
                                   | UNAuthorizationOptionSound;
    [center requestAuthorizationWithOptions:options completionHandler:^(BOOL granted, NSError *error) {
        if (error) {
            [[MicYouLogger sharedLogger] logError:[NSString stringWithFormat:@"Notification auth error: %@", error.localizedDescription]];
        }
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(granted);
            });
        }
    }];
}

- (void)sendNotificationWithTitle:(NSString *)title
                             body:(NSString *)body
                       identifier:(NSString *)identifier {
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = title ?: @"";
    content.body = body ?: @"";
    content.sound = [UNNotificationSound defaultSound];

    UNTimeIntervalNotificationTrigger *trigger =
        [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:0.1 repeats:NO];

    UNNotificationRequest *request =
        [UNNotificationRequest requestWithIdentifier:identifier
                                            content:content
                                            trigger:trigger];

    [[UNUserNotificationCenter currentNotificationCenter]
        addNotificationRequest:request
             withCompletionHandler:^(NSError *error) {
                 if (error) {
                     [[MicYouLogger sharedLogger] logError:
                        [NSString stringWithFormat:@"Failed to post notification: %@", error.localizedDescription]];
                 }
             }];
}

#pragma mark - UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    // Show banner + play sound while the app is in the foreground.
    UNNotificationPresentationOptions options = UNNotificationPresentationOptionAlert
                                              | UNNotificationPresentationOptionSound
                                              | UNNotificationPresentationOptionBadge;
    completionHandler(options);
}

@end
