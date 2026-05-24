#import "MicYouColors.h"

// HSL color structure for internal palette generation
typedef struct {
    CGFloat h; // 0-360
    CGFloat s; // 0-1
    CGFloat l; // 0-1
} MicYouHSL;

@interface MicYouColors ()

@property (nonatomic, readwrite) UIColor *primary;
@property (nonatomic, readwrite) UIColor *onPrimary;
@property (nonatomic, readwrite) UIColor *primaryContainer;
@property (nonatomic, readwrite) UIColor *onPrimaryContainer;
@property (nonatomic, readwrite) UIColor *secondary;
@property (nonatomic, readwrite) UIColor *onSecondary;
@property (nonatomic, readwrite) UIColor *secondaryContainer;
@property (nonatomic, readwrite) UIColor *tertiary;
@property (nonatomic, readwrite) UIColor *onTertiary;
@property (nonatomic, readwrite) UIColor *error;
@property (nonatomic, readwrite) UIColor *onError;
@property (nonatomic, readwrite) UIColor *background;
@property (nonatomic, readwrite) UIColor *onBackground;
@property (nonatomic, readwrite) UIColor *surface;
@property (nonatomic, readwrite) UIColor *surfaceDim;
@property (nonatomic, readwrite) UIColor *surfaceBright;
@property (nonatomic, readwrite) UIColor *surfaceVariant;
@property (nonatomic, readwrite) UIColor *onSurface;
@property (nonatomic, readwrite) UIColor *onSurfaceVariant;
@property (nonatomic, readwrite) UIColor *outline;
@property (nonatomic, readwrite) UIColor *outlineVariant;

@end

@implementation MicYouColors

#pragma mark - Singleton

+ (MicYouColors *)shared {
    static MicYouColors *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MicYouColors alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _colorScheme = MicYouColorSchemeLight;
        _useOLEDBlack = NO;
        UIColor *defaultSeed = [MicYouColors colorFromHex:0x4A672D];
        _seedColor = defaultSeed;
        [self regeneratePalette];

        // Listen for trait changes on iOS 13+
        if (@available(iOS 13.0, *)) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(traitCollectionDidChangeNotification:)
                                                         name:UIContentSizeCategoryDidChangeNotification
                                                       object:nil];
        }
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)traitCollectionDidChangeNotification:(NSNotification *)notification {
    // Detect if dark mode changed and auto-adjust
    if (_colorScheme != MicYouColorSchemeOLED) {
        if (@available(iOS 13.0, *)) {
            UITraitCollection *currentTrait = [UITraitCollection currentTraitCollection];
            if (currentTrait.userInterfaceStyle == UIUserInterfaceStyleDark) {
                if (_colorScheme != MicYouColorSchemeDark) {
                    [self setColorScheme:MicYouColorSchemeDark];
                }
            } else {
                if (_colorScheme != MicYouColorSchemeLight) {
                    [self setColorScheme:MicYouColorSchemeLight];
                }
            }
        }
    }
}

#pragma mark - Preset Colors (19 colors matching Android Theme.kt)

+ (NSArray<UIColor *> *)presetColors {
    static NSArray<UIColor *> *colors = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        colors = @[
            [MicYouColors colorFromHex:0x4A672D],    // 0:  Default
            [MicYouColors colorFromHex:0xC62828],    // 1:  Red
            [MicYouColors colorFromHex:0xAD1457],    // 2:  Pink
            [MicYouColors colorFromHex:0x6A1B9A],    // 3:  Purple
            [MicYouColors colorFromHex:0x4527A0],    // 4:  DeepPurple
            [MicYouColors colorFromHex:0x283593],    // 5:  Indigo
            [MicYouColors colorFromHex:0x1565C0],    // 6:  Blue
            [MicYouColors colorFromHex:0x0277BD],    // 7:  LightBlue
            [MicYouColors colorFromHex:0x00838F],    // 8:  Cyan
            [MicYouColors colorFromHex:0x00695C],    // 9:  Teal
            [MicYouColors colorFromHex:0x2E7D32],    // 10: Green
            [MicYouColors colorFromHex:0x558B2F],    // 11: LightGreen
            [MicYouColors colorFromHex:0x9E9D24],    // 12: Lime
            [MicYouColors colorFromHex:0xF9A825],    // 13: Yellow
            [MicYouColors colorFromHex:0xFF8F00],    // 14: Amber
            [MicYouColors colorFromHex:0xEF6C00],    // 15: Orange
            [MicYouColors colorFromHex:0xD84315],    // 16: DeepOrange
            [MicYouColors colorFromHex:0x4E342E],    // 17: Brown
            [MicYouColors colorFromHex:0x5F6162],    // 18: Grey
        ];
    });
    return colors;
}

#pragma mark - Hex Utility

+ (UIColor *)colorFromHex:(NSUInteger)hex {
    return [UIColor colorWithRed:((CGFloat)((hex >> 16) & 0xFF)) / 255.0
                           green:((CGFloat)((hex >> 8) & 0xFF)) / 255.0
                            blue:((CGFloat)(hex & 0xFF)) / 255.0
                           alpha:1.0];
}

+ (UIColor *)colorWithHex:(NSUInteger)hex alpha:(CGFloat)alpha {
    return [UIColor colorWithRed:((CGFloat)((hex >> 16) & 0xFF)) / 255.0
                           green:((CGFloat)((hex >> 8) & 0xFF)) / 255.0
                            blue:((CGFloat)(hex & 0xFF)) / 255.0
                           alpha:alpha];
}

#pragma mark - HSL Conversion

+ (MicYouHSL)hslFromColor:(UIColor *)color {
    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];

    CGFloat max = MAX(MAX(r, g), b);
    CGFloat min = MIN(MIN(r, g), b);
    CGFloat delta = max - min;

    MicYouHSL hsl;
    hsl.l = (max + min) / 2.0;

    if (delta == 0) {
        hsl.h = 0;
        hsl.s = 0;
    } else {
        hsl.s = (hsl.l > 0.5) ? delta / (2.0 - max - min) : delta / (max + min);

        if (max == r) {
            hsl.h = ((g - b) / delta) + (g < b ? 6.0 : 0.0);
        } else if (max == g) {
            hsl.h = ((b - r) / delta) + 2.0;
        } else {
            hsl.h = ((r - g) / delta) + 4.0;
        }
        hsl.h *= 60.0;
    }

    return hsl;
}

+ (UIColor *)colorFromHSL:(MicYouHSL)hsl {
    return [MicYouColors colorFromHSL:hsl alpha:1.0];
}

+ (UIColor *)colorFromHSL:(MicYouHSL)hsl alpha:(CGFloat)alpha {
    CGFloat h = hsl.h;
    CGFloat s = hsl.s;
    CGFloat l = hsl.l;

    if (s == 0) {
        return [UIColor colorWithRed:l green:l blue:l alpha:alpha];
    }

    CGFloat q = (l < 0.5) ? l * (1.0 + s) : l + s - l * s;
    CGFloat p = 2.0 * l - q;

    CGFloat hk = h / 360.0;
    CGFloat tr = hk + 1.0 / 3.0;
    CGFloat tg = hk;
    CGFloat tb = hk - 1.0 / 3.0;

    CGFloat r = [MicYouColors hueToRGB:p q:q t:tr];
    CGFloat g = [MicYouColors hueToRGB:p q:q t:tg];
    CGFloat b = [MicYouColors hueToRGB:p q:q t:tb];

    return [UIColor colorWithRed:r green:g blue:b alpha:alpha];
}

+ (CGFloat)hueToRGB:(CGFloat)p q:(CGFloat)q t:(CGFloat)t {
    if (t < 0) t += 1.0;
    if (t > 1) t -= 1.0;
    if (t < 1.0 / 6.0) return p + (q - p) * 6.0 * t;
    if (t < 1.0 / 2.0) return q;
    if (t < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - t) * 6.0;
    return p;
}

#pragma mark - Luminance (for determining on-colors)

+ (CGFloat)luminanceOfColor:(UIColor *)color {
    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];

    // sRGB relative luminance
    CGFloat lr = (r <= 0.03928) ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4);
    CGFloat lg = (g <= 0.03928) ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4);
    CGFloat lb = (b <= 0.03928) ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4);
    return 0.2126 * lr + 0.7152 * lg + 0.0722 * lb;
}

+ (BOOL)isColorDark:(UIColor *)color {
    return [MicYouColors luminanceOfColor:color] < 0.5;
}

#pragma mark - Seed Color

- (void)setSeedColor:(UIColor *)seedColor {
    if ([_seedColor isEqual:seedColor]) return;
    _seedColor = seedColor;
    [self regeneratePalette];
}

#pragma mark - Color Scheme

- (void)setColorScheme:(MicYouColorScheme)colorScheme {
    if (_colorScheme == colorScheme) return;
    _colorScheme = colorScheme;
    [self regeneratePalette];
}

- (void)setUseOLEDBlack:(BOOL)useOLEDBlack {
    if (_useOLEDBlack == useOLEDBlack) return;
    _useOLEDBlack = useOLEDBlack;
    if (_colorScheme == MicYouColorSchemeDark) {
        _colorScheme = useOLEDBlack ? MicYouColorSchemeOLED : MicYouColorSchemeDark;
    }
    [self regeneratePalette];
}

#pragma mark - Palette Regeneration

- (void)regeneratePalette {
    UIColor *errorBase = [MicYouColors colorFromHex:0xB3261E];
    UIColor *onErrorBase = [UIColor whiteColor];
    UIColor *white = [UIColor whiteColor];
    UIColor *black = [UIColor blackColor];

    // --- Surface / Background ---
    switch (_colorScheme) {
        case MicYouColorSchemeLight: {
            _background = [MicYouColors colorFromHex:0xFFFFFF];
            _surface = [MicYouColors colorFromHex:0xFFFFFF];
            _surfaceDim = [MicYouColors colorFromHex:0xF7F2FA];
            _surfaceBright = [MicYouColors colorFromHex:0xFFFFFF];
            _surfaceVariant = [MicYouColors colorFromHex:0xE7E0EC];
            _onBackground = [MicYouColors colorFromHex:0x1C1B1F];
            _onSurface = [MicYouColors colorFromHex:0x1C1B1F];
            _onSurfaceVariant = [MicYouColors colorFromHex:0x49454F];
            _outline = [MicYouColors colorFromHex:0x79747E];
            _outlineVariant = [MicYouColors colorFromHex:0xCAC4D0];
            break;
        }
        case MicYouColorSchemeDark: {
            _background = [MicYouColors colorFromHex:0x121212];
            _surface = [MicYouColors colorFromHex:0x121212];
            _surfaceDim = [MicYouColors colorFromHex:0x0E0E0E];
            _surfaceBright = [MicYouColors colorFromHex:0x2D2D2D];
            _surfaceVariant = [MicYouColors colorFromHex:0x2D2D2D];
            _onBackground = [MicYouColors colorFromHex:0xE6E1E5];
            _onSurface = [MicYouColors colorFromHex:0xE6E1E5];
            _onSurfaceVariant = [MicYouColors colorFromHex:0xCAC4D0];
            _outline = [MicYouColors colorFromHex:0x938F99];
            _outlineVariant = [MicYouColors colorFromHex:0x49454F];
            break;
        }
        case MicYouColorSchemeOLED: {
            _background = [MicYouColors colorFromHex:0x000000];
            _surface = [MicYouColors colorFromHex:0x000000];
            _surfaceDim = [MicYouColors colorFromHex:0x000000];
            _surfaceBright = [MicYouColors colorFromHex:0x121212];
            _surfaceVariant = [MicYouColors colorFromHex:0x1A1A1A];
            _onBackground = [MicYouColors colorFromHex:0xE6E1E5];
            _onSurface = [MicYouColors colorFromHex:0xE6E1E5];
            _onSurfaceVariant = [MicYouColors colorFromHex:0xCAC4D0];
            _outline = [MicYouColors colorFromHex:0x938F99];
            _outlineVariant = [MicYouColors colorFromHex:0x49454F];
            break;
        }
    }

    // --- Primary (seed color) ---
    _primary = _seedColor;

    MicYouHSL seedHSL = [MicYouColors hslFromColor:_seedColor];
    BOOL isDarkSeed = [MicYouColors isColorDark:_seedColor];

    // onPrimary
    _onPrimary = isDarkSeed ? white : black;

    // primaryContainer (lighter version at ~80% lightness in light mode, darker in dark)
    MicYouHSL containerHSL = seedHSL;
    if (_colorScheme == MicYouColorSchemeLight) {
        containerHSL.l = MIN(1.0, containerHSL.l * 1.5 + 0.2);
        containerHSL.s = containerHSL.s * 0.3;
    } else {
        containerHSL.l = MAX(0.05, containerHSL.l * 0.4);
        containerHSL.s = MIN(1.0, containerHSL.s * 0.8);
    }
    _primaryContainer = [MicYouColors colorFromHSL:containerHSL];
    _onPrimaryContainer = isDarkSeed ? white : black;

    // --- Secondary (hue shifted by 30°, reduced saturation) ---
    MicYouHSL secHSL = seedHSL;
    secHSL.h = fmod(seedHSL.h + 30.0, 360.0);
    secHSL.s = MIN(1.0, seedHSL.s * 0.4);
    _secondary = [MicYouColors colorFromHSL:secHSL];

    BOOL isDarkSecondary = [MicYouColors isColorDark:_secondary];
    _onSecondary = isDarkSecondary ? white : black;

    MicYouHSL secContainerHSL = secHSL;
    if (_colorScheme == MicYouColorSchemeLight) {
        secContainerHSL.l = MIN(1.0, secContainerHSL.l * 1.5 + 0.15);
        secContainerHSL.s = secContainerHSL.s * 0.3;
    } else {
        secContainerHSL.l = MAX(0.05, secContainerHSL.l * 0.4);
        secContainerHSL.s = MIN(1.0, secContainerHSL.s * 0.8);
    }
    _secondaryContainer = [MicYouColors colorFromHSL:secContainerHSL];

    // --- Tertiary (hue shifted by 60°) ---
    MicYouHSL terHSL = seedHSL;
    terHSL.h = fmod(seedHSL.h + 60.0, 360.0);
    _tertiary = [MicYouColors colorFromHSL:terHSL];

    BOOL isDarkTertiary = [MicYouColors isColorDark:_tertiary];
    _onTertiary = isDarkTertiary ? white : black;

    // --- Error ---
    _error = errorBase;
    _onError = onErrorBase;
}

@end