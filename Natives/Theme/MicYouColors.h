#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MicYouColorScheme) {
    MicYouColorSchemeLight,
    MicYouColorSchemeDark,
    MicYouColorSchemeOLED
};

@interface MicYouColors : NSObject

@property (class, nonatomic, readonly) MicYouColors *shared;

// Seed color system - matches Android PresetColors (19 colors)
+ (NSArray<UIColor *> *)presetColors;
@property (nonatomic, strong) UIColor *seedColor;

// Color scheme
@property (nonatomic, assign) MicYouColorScheme colorScheme;
@property (nonatomic, assign) BOOL useOLEDBlack;

// Material You dynamic color tokens
@property (nonatomic, readonly) UIColor *primary;
@property (nonatomic, readonly) UIColor *onPrimary;
@property (nonatomic, readonly) UIColor *primaryContainer;
@property (nonatomic, readonly) UIColor *onPrimaryContainer;
@property (nonatomic, readonly) UIColor *secondary;
@property (nonatomic, readonly) UIColor *onSecondary;
@property (nonatomic, readonly) UIColor *secondaryContainer;
@property (nonatomic, readonly) UIColor *tertiary;
@property (nonatomic, readonly) UIColor *onTertiary;
@property (nonatomic, readonly) UIColor *error;
@property (nonatomic, readonly) UIColor *onError;
@property (nonatomic, readonly) UIColor *background;
@property (nonatomic, readonly) UIColor *onBackground;
@property (nonatomic, readonly) UIColor *surface;
@property (nonatomic, readonly) UIColor *surfaceDim;
@property (nonatomic, readonly) UIColor *surfaceBright;
@property (nonatomic, readonly) UIColor *surfaceVariant;
@property (nonatomic, readonly) UIColor *onSurface;
@property (nonatomic, readonly) UIColor *onSurfaceVariant;
@property (nonatomic, readonly) UIColor *outline;
@property (nonatomic, readonly) UIColor *outlineVariant;

// M3 intermediate surface & container tokens
@property (nonatomic, readonly) UIColor *surfaceContainer;
@property (nonatomic, readonly) UIColor *surfaceContainerLow;
@property (nonatomic, readonly) UIColor *surfaceContainerHigh;
@property (nonatomic, readonly) UIColor *surfaceContainerHighest;
@property (nonatomic, readonly) UIColor *errorContainer;
@property (nonatomic, readonly) UIColor *onErrorContainer;
@property (nonatomic, readonly) UIColor *onSecondaryContainer;

- (void)setSeedColor:(UIColor *)seedColor; // regenerates palette
- (void)setColorScheme:(MicYouColorScheme)colorScheme;

/// sRGB relative luminance of a color (0.0 - 1.0). Used for picking on-color contrast.
+ (CGFloat)luminanceOfColor:(UIColor *)color;
/// Returns YES if the color is dark (luminance < 0.5).
+ (BOOL)isColorDark:(UIColor *)color;

@end

NS_ASSUME_NONNULL_END