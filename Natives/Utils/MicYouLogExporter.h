#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * MicYouLogExporter exports the current MicYou log file
 * (<Documents>/micyou.log managed by MicYouLogger) via a UIActivityViewController.
 *
 * The log file is first copied into NSTemporaryDirectory() so the share sheet
 * can read it without requiring the Documents folder to be exposed through
 * the app's UIFileSharingEnabled capability.
 */
@interface MicYouLogExporter : NSObject

+ (instancetype)shared;

/**
 * Present a share sheet for the current log file from the given view controller.
 * Must be called on the main thread. If no log file exists, the call is a no-op.
 */
- (void)exportLogFromViewController:(UIViewController *)viewController;

@end

NS_ASSUME_NONNULL_END
