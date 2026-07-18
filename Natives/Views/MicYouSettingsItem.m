#import "MicYouSettingsItem.h"
#import "MicYouColors.h"
#import <QuartzCore/QuartzCore.h>

static const CGFloat kCornerRadius = 28.0f;       // outer corner radius
static const CGFloat kInnerCornerRadius = 10.0f;  // inner corner radius (middle items & adjacent corners)
static const CGFloat kPaddingHorizontal = 20.0f;
static const CGFloat kPaddingVertical = 18.0f;
static const CGFloat kTitleFontSize = 16.0f;       // bodyLarge
static const CGFloat kSubtitleFontSize = 12.0f;    // bodySmall
static const CGFloat kValueFontSize = 16.0f;       // bodyLarge
static const CGFloat kIconSize = 24.0f;
static const CGFloat kIconTextSpacing = 16.0f;
static const CGFloat kTextTrailingSpacing = 12.0f; // text <-> right element
static const CGFloat kValueChevronSpacing = 4.0f;
static const CGFloat kTitleSubtitleSpacing = 2.0f;
static const CGFloat kChevronDownPointSize = 12.0f;
static const CGFloat kChevronRightPointSize = 14.0f;
static const CGFloat kDisabledOpacity = 0.6f;

@interface MicYouSettingsItem ()
@property (nonatomic, assign) MicYouSettingsItemStyle style;
@property (nonatomic, assign) BOOL isFirst;
@property (nonatomic, assign) BOOL isLast;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong, nullable) UISwitch *toggleSwitch;
@property (nonatomic, strong, nullable) UILabel *valueLabel;
@property (nonatomic, strong, nullable) UIImageView *iconImageView;
@property (nonatomic, strong, nullable) UIImageView *chevronImageView;
@property (nonatomic, strong, nullable) UIStackView *textStackView;
@property (nonatomic, strong, nullable) CAShapeLayer *cornerMaskLayer;
@end

@implementation MicYouSettingsItem

#pragma mark - Init

- (instancetype)initWithStyle:(MicYouSettingsItemStyle)style
                      isFirst:(BOOL)isFirst
                       isLast:(BOOL)isLast {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _style = style;
        _isFirst = isFirst;
        _isLast = isLast;
        _enabled = YES;
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    self.backgroundColor = [MicYouColors shared].surfaceBright;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.clipsToBounds = YES;

    [self setupLabelsAndTextStack];

    switch (self.style) {
        case MicYouSettingsItemStyleSwitch:
            [self setupSwitchStyle];
            break;
        case MicYouSettingsItemStyleDropdown:
            [self setupDropdownStyle];
            break;
        case MicYouSettingsItemStyleList:
            [self setupListStyle];
            break;
    }

    [self refreshColors];
    [self applyEnabledState];
}

#pragma mark - Common labels & text stack

- (void)setupLabelsAndTextStack {
    self.titleLabel = [self makeLabelWithFontSize:kTitleFontSize];
    self.subtitleLabel = [self makeLabelWithFontSize:kSubtitleFontSize];
    self.subtitleLabel.hidden = YES;

    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.titleLabel, self.subtitleLabel]];
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.alignment = UIStackViewAlignmentLeading;
    textStack.distribution = UIStackViewDistributionFill;
    textStack.spacing = kTitleSubtitleSpacing;
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:textStack];
    self.textStackView = textStack;

    // Vertical padding drives self-sizing: top pinned to self, bottom drives self.bottom.
    [NSLayoutConstraint activateConstraints:@[
        [textStack.topAnchor constraintEqualToAnchor:self.topAnchor constant:kPaddingVertical],
        [self.bottomAnchor constraintEqualToAnchor:textStack.bottomAnchor constant:kPaddingVertical],
    ]];
}

- (UILabel *)makeLabelWithFontSize:(CGFloat)fontSize {
    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [UIFont systemFontOfSize:fontSize weight:UIFontWeightRegular];
    label.numberOfLines = 1;
    label.adjustsFontForContentSizeCategory = YES;
    label.textAlignment = NSTextAlignmentLeft;
    return label;
}

- (UIImageView *)makeChevronWithImageNamed:(NSString *)name pointSize:(CGFloat)pointSize {
    UIImageView *imageView = [UIImageView new];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.tintColor = [MicYouColors shared].onSurfaceVariant;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:pointSize
                                                                                            weight:UIImageSymbolWeightRegular];
        UIImage *image = [UIImage systemImageNamed:name withConfiguration:config];
        imageView.image = image;
    }
    // iOS 11-12 fallback (Phase 6): leave image nil for now.
    return imageView;
}

#pragma mark - Switch style

- (void)setupSwitchStyle {
    [NSLayoutConstraint activateConstraints:@[
        [self.textStackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:kPaddingHorizontal],
    ]];

    UISwitch *toggleSwitch = [UISwitch new];
    toggleSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:toggleSwitch];
    self.toggleSwitch = toggleSwitch;

    [NSLayoutConstraint activateConstraints:@[
        [toggleSwitch.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-kPaddingHorizontal],
        [toggleSwitch.centerYAnchor constraintEqualToAnchor:self.textStackView.centerYAnchor],
        [toggleSwitch.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.textStackView.trailingAnchor constant:kTextTrailingSpacing],
    ]];
}

#pragma mark - Dropdown style

- (void)setupDropdownStyle {
    [NSLayoutConstraint activateConstraints:@[
        [self.textStackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:kPaddingHorizontal],
    ]];

    UILabel *valueLabel = [self makeLabelWithFontSize:kValueFontSize];
    [self addSubview:valueLabel];
    self.valueLabel = valueLabel;

    UIImageView *chevron = [self makeChevronWithImageNamed:@"chevron.down" pointSize:kChevronDownPointSize];
    [self addSubview:chevron];
    self.chevronImageView = chevron;

    [NSLayoutConstraint activateConstraints:@[
        [chevron.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-kPaddingHorizontal],
        [chevron.centerYAnchor constraintEqualToAnchor:self.textStackView.centerYAnchor],
        [valueLabel.trailingAnchor constraintEqualToAnchor:chevron.leadingAnchor constant:-kValueChevronSpacing],
        [valueLabel.centerYAnchor constraintEqualToAnchor:self.textStackView.centerYAnchor],
        [valueLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.textStackView.trailingAnchor constant:kTextTrailingSpacing],
    ]];
}

#pragma mark - List style

- (void)setupListStyle {
    UIImageView *icon = [UIImageView new];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.tintColor = [MicYouColors shared].primary;
    [self addSubview:icon];
    self.iconImageView = icon;

    UIImageView *chevron = [self makeChevronWithImageNamed:@"chevron.right" pointSize:kChevronRightPointSize];
    [self addSubview:chevron];
    self.chevronImageView = chevron;

    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:kPaddingHorizontal],
        [icon.centerYAnchor constraintEqualToAnchor:self.textStackView.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:kIconSize],
        [icon.heightAnchor constraintEqualToConstant:kIconSize],
        [self.textStackView.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:kIconTextSpacing],
        [chevron.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-kPaddingHorizontal],
        [chevron.centerYAnchor constraintEqualToAnchor:self.textStackView.centerYAnchor],
        [self.textStackView.trailingAnchor constraintLessThanOrEqualToAnchor:chevron.leadingAnchor constant:-kTextTrailingSpacing],
    ]];
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateSubtitleVisibility];
    [self refreshCorners];
}

- (void)updateSubtitleVisibility {
    BOOL hasSubtitle = self.subtitleLabel.text.length > 0;
    // UIStackView auto-collapses hidden arranged subviews.
    self.subtitleLabel.hidden = !hasSubtitle;
}

#pragma mark - Corner radius (Expressive continuous card)

/// Build a Bezier path with independent radius per corner.
/// Matches Android Material 3 Expressive continuous card shape:
///   first item: 28 28 10 10 (topLeft topRight bottomLeft bottomRight)
///   middle item: 10 10 10 10
///   last item: 10 10 28 28
///   standalone item: 28 28 28 28
- (UIBezierPath *)roundedPathWithBounds:(CGRect)bounds
                               topLeftR:(CGFloat)topLeftR
                              topRightR:(CGFloat)topRightR
                            bottomLeftR:(CGFloat)bottomLeftR
                           bottomRightR:(CGFloat)bottomRightR {
    CGFloat w = bounds.size.width;
    CGFloat h = bounds.size.height;
    // Clamp radii so they never exceed half the bounds.
    CGFloat maxR = MIN(w, h) / 2.0;
    topLeftR     = MIN(topLeftR, maxR);
    topRightR    = MIN(topRightR, maxR);
    bottomLeftR  = MIN(bottomLeftR, maxR);
    bottomRightR = MIN(bottomRightR, maxR);

    UIBezierPath *path = [UIBezierPath bezierPath];
    // Start at top-left, just after the corner arc.
    [path moveToPoint:CGPointMake(topLeftR, 0.0)];
    // Top edge to top-right corner start.
    [path addLineToPoint:CGPointMake(w - topRightR, 0.0)];
    // Top-right corner arc.
    if (topRightR > 0) {
        [path addArcWithCenter:CGPointMake(w - topRightR, topRightR)
                        radius:topRightR
                    startAngle:-M_PI_2
                      endAngle:0.0
                     clockwise:YES];
    }
    // Right edge to bottom-right corner start.
    [path addLineToPoint:CGPointMake(w, h - bottomRightR)];
    // Bottom-right corner arc.
    if (bottomRightR > 0) {
        [path addArcWithCenter:CGPointMake(w - bottomRightR, h - bottomRightR)
                        radius:bottomRightR
                    startAngle:0.0
                      endAngle:M_PI_2
                     clockwise:YES];
    }
    // Bottom edge to bottom-left corner start.
    [path addLineToPoint:CGPointMake(bottomLeftR, h)];
    // Bottom-left corner arc.
    if (bottomLeftR > 0) {
        [path addArcWithCenter:CGPointMake(bottomLeftR, h - bottomLeftR)
                        radius:bottomLeftR
                    startAngle:M_PI_2
                      endAngle:M_PI
                     clockwise:YES];
    }
    // Left edge to top-left corner start.
    [path addLineToPoint:CGPointMake(0.0, topLeftR)];
    // Top-left corner arc.
    if (topLeftR > 0) {
        [path addArcWithCenter:CGPointMake(topLeftR, topLeftR)
                        radius:topLeftR
                    startAngle:M_PI
                      endAngle:3.0 * M_PI_2
                     clockwise:YES];
    }
    [path closePath];
    return path;
}

- (void)refreshCorners {
    // Outer corners (top of first item, bottom of last item, all corners of standalone) use 28pt.
    // Inner corners (bottom of first item, top of last item, all corners of middle item) use 10pt.
    CGFloat topLeftR     = self.isFirst ? kCornerRadius : kInnerCornerRadius;
    CGFloat topRightR    = self.isFirst ? kCornerRadius : kInnerCornerRadius;
    CGFloat bottomLeftR  = self.isLast  ? kCornerRadius : kInnerCornerRadius;
    CGFloat bottomRightR = self.isLast  ? kCornerRadius : kInnerCornerRadius;

    UIBezierPath *path = [self roundedPathWithBounds:self.bounds
                                           topLeftR:topLeftR
                                          topRightR:topRightR
                                        bottomLeftR:bottomLeftR
                                       bottomRightR:bottomRightR];

    CAShapeLayer *maskLayer = self.cornerMaskLayer;
    if (!maskLayer) {
        maskLayer = [CAShapeLayer layer];
        self.cornerMaskLayer = maskLayer;
    }
    maskLayer.path = path.CGPath;
    self.layer.mask = maskLayer;
}

#pragma mark - Enabled state

- (void)setEnabled:(BOOL)enabled {
    if (_enabled == enabled) return;
    _enabled = enabled;
    [self applyEnabledState];
}

- (void)applyEnabledState {
    self.alpha = self.enabled ? 1.0f : kDisabledOpacity;
    self.userInteractionEnabled = self.enabled;
    if (self.toggleSwitch != nil) {
        self.toggleSwitch.enabled = self.enabled;
    }
}

#pragma mark - Theme colors

- (void)refreshColors {
    MicYouColors *colors = [MicYouColors shared];
    self.backgroundColor = colors.surfaceBright;
    self.titleLabel.textColor = colors.onSurface;
    self.subtitleLabel.textColor = colors.onSurfaceVariant;
    if (self.valueLabel != nil) {
        self.valueLabel.textColor = colors.primary;
    }
    if (self.iconImageView != nil) {
        self.iconImageView.tintColor = colors.primary;
    }
    if (self.chevronImageView != nil) {
        self.chevronImageView.tintColor = colors.onSurfaceVariant;
    }
    if (self.toggleSwitch != nil) {
        self.toggleSwitch.onTintColor = colors.primary;
    }
}

@end
