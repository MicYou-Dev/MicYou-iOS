#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Material 3 Expressive 风格的设置页 ViewController。
/// 不依赖 UINavigationController 的导航栏，自带毛玻璃导航栏 + UIScrollView + 连续卡片系统。
@interface SettingsViewController : UIViewController

/// 当任意设置项变化时触发的回调（同步于通知发送时刻）。
/// 回调参数为变化的 NSUserDefaults key（如 @"micyou_dark_mode"）。
@property (nonatomic, copy, nullable) void (^onSettingsChanged)(NSString *key);

/// 使用默认 init 初始化；不依赖 Nib / Storyboard。
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil
                         bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
