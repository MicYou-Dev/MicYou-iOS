#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MicYouSettingsItemStyle) {
    MicYouSettingsItemStyleSwitch,    // 标题 + 副标题(可选) + 右侧 Toggle Switch
    MicYouSettingsItemStyleDropdown,  // 标题 + 右侧选中值 + ▾ 箭头
    MicYouSettingsItemStyleList       // 左侧图标 + 标题 + 副标题(可选) + 右侧 > 箭头
};

/// Expressive continuous card base item for settings page.
/// Handles corner radius logic (first/last) and padding; content depends on style.
@interface MicYouSettingsItem : UIView

/// Style of the item (set at init, cannot change)
@property (nonatomic, readonly) MicYouSettingsItemStyle style;

/// Whether this is the first item in a continuous group (top corners rounded)
@property (nonatomic, readonly) BOOL isFirst;

/// Whether this is the last item in a continuous group (bottom corners rounded)
@property (nonatomic, readonly) BOOL isLast;

/// Title label
@property (nonatomic, readonly) UILabel *titleLabel;

/// Optional subtitle label (hidden if subtitle is nil)
@property (nonatomic, readonly) UILabel *subtitleLabel;

/// Toggle switch for Switch style (nil for other styles)
@property (nonatomic, readonly, nullable) UISwitch *toggleSwitch;

/// Value label for Dropdown style (nil for other styles)
@property (nonatomic, readonly, nullable) UILabel *valueLabel;

/// Icon image view for List style (nil for other styles)
@property (nonatomic, readonly, nullable) UIImageView *iconImageView;

/// Whether the item is enabled. Default YES.
/// When disabled the item is dimmed (opacity 0.6) and ignores interaction.
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;

/// Initialize with style and position in continuous group
- (instancetype)initWithStyle:(MicYouSettingsItemStyle)style
                      isFirst:(BOOL)isFirst
                       isLast:(BOOL)isLast NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

/// Refresh corner radius based on isFirst/isLast (call after init if position changes)
- (void)refreshCorners;

/// Refresh colors when theme changes
- (void)refreshColors;

@end

NS_ASSUME_NONNULL_END
