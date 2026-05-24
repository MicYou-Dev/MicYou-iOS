#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class LaunchAnimationViewController;

@protocol LaunchAnimationDelegate <NSObject>
- (void)launchAnimationDidFinish:(LaunchAnimationViewController *)controller;
@end

@interface LaunchAnimationViewController : UIViewController

@property (nonatomic, weak) id<LaunchAnimationDelegate> delegate;
@property (nonatomic, assign, readonly) BOOL isDarkMode;

- (instancetype)initWithDarkMode:(BOOL)darkMode;

@end

NS_ASSUME_NONNULL_END
