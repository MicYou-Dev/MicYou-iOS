#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Material 3 FilterChip: pill-shaped selection chip with checkmark when selected
@interface MicYouFilterChip : UIControl

/// Title text shown in the chip
@property (nonatomic, copy) NSString *title;

/// Selection state
@property (nonatomic, assign, getter=isSelected) BOOL selected;

/// Tap callback (fired on touch up inside)
@property (nonatomic, copy, nullable) void (^onTap)(BOOL selected);

/// Initialize with title and initial selection state
- (instancetype)initWithTitle:(NSString *)title selected:(BOOL)selected NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

/// Set selected state with optional animation (200ms color transition)
- (void)setSelected:(BOOL)selected animated:(BOOL)animated;

/// Refresh colors from MicYouColors (call when theme changes)
- (void)refreshColors;

@end

NS_ASSUME_NONNULL_END
