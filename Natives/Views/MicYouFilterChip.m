#import "MicYouFilterChip.h"
#import "MicYouColors.h"
#import "MicYouAnimator.h"

static const CGFloat kChipHorizontalPadding   = 12.0;
static const CGFloat kChipVerticalPadding     = 8.0;
static const CGFloat kChipCheckmarkSize       = 16.0;
static const CGFloat kChipCheckmarkSpacing    = 4.0;
static const CGFloat kChipMinHeight           = 32.0;
static const CGFloat kChipAnimationDuration   = 0.2;
static const CGFloat kChipPressScale          = 0.96;
static const CGFloat kChipPressInDuration     = 0.10;
static const CGFloat kChipCheckmarkFontSize   = 14.0;

@interface MicYouFilterChip ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *checkmarkLabel;
@property (nonatomic, assign) BOOL pressed;
@end

@implementation MicYouFilterChip

#pragma mark - Init

- (instancetype)initWithTitle:(NSString *)title selected:(BOOL)selected {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _title = [title copy];
        _selected = selected;
        _pressed = NO;
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    self.backgroundColor = [self currentBackgroundColor];
    self.layer.masksToBounds = YES;
    self.layer.cornerRadius = 0.0;

    // Title label
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.text = self.title;
    _titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    _titleLabel.textColor = [self currentTitleColor];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = YES;
    [self addSubview:_titleLabel];

    // Checkmark label
    _checkmarkLabel = [[UILabel alloc] init];
    _checkmarkLabel.text = @"\u2713"; // CHECK MARK
    _checkmarkLabel.font = [UIFont systemFontOfSize:kChipCheckmarkFontSize weight:UIFontWeightMedium];
    _checkmarkLabel.textColor = [self currentCheckmarkColor];
    _checkmarkLabel.textAlignment = NSTextAlignmentCenter;
    _checkmarkLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    _checkmarkLabel.clipsToBounds = YES;
    _checkmarkLabel.translatesAutoresizingMaskIntoConstraints = YES;
    _checkmarkLabel.alpha = self.isSelected ? 1.0 : 0.0;
    [self addSubview:_checkmarkLabel];

    [self applyVisualState:NO];
}

#pragma mark - Setters

- (void)setTitle:(NSString *)title {
    _title = [title copy];
    self.titleLabel.text = _title;
    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
}

- (void)setSelected:(BOOL)selected {
    if (_selected == selected) return;
    _selected = selected;
    [self invalidateIntrinsicContentSize];
    [self applyVisualState:NO];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    _selected = selected;
    [self invalidateIntrinsicContentSize];
    [self applyVisualState:animated];
    if (self.onTap) {
        self.onTap(selected);
    }
}

#pragma mark - Visual State

- (void)applyVisualState:(BOOL)animated {
    BOOL isSelected       = self.isSelected;
    UIColor *bgColor      = [self currentBackgroundColor];
    UIColor *titleColor   = [self currentTitleColor];
    UIColor *checkColor   = [self currentCheckmarkColor];
    CGFloat targetAlpha   = isSelected ? 1.0 : 0.0;

    void (^updateBlock)(void) = ^{
        self.backgroundColor        = bgColor;
        self.titleLabel.textColor   = titleColor;
        self.checkmarkLabel.textColor = checkColor;
        self.checkmarkLabel.alpha   = targetAlpha;
        [self setNeedsLayout];
        [self layoutIfNeeded];
    };

    if (animated) {
        [UIView animateWithDuration:kChipAnimationDuration
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:updateBlock
                         completion:nil];
    } else {
        updateBlock();
    }
}

- (void)refreshColors {
    [self applyVisualState:NO];
}

#pragma mark - Colors

- (UIColor *)currentBackgroundColor {
    MicYouColors *colors = [MicYouColors shared];
    return self.isSelected ? colors.primary : colors.surfaceContainerHighest;
}

- (UIColor *)currentTitleColor {
    MicYouColors *colors = [MicYouColors shared];
    return self.isSelected ? colors.onPrimary : colors.onSurfaceVariant;
}

- (UIColor *)currentCheckmarkColor {
    // Spec: checkmark uses onPrimary when selected.
    return [MicYouColors shared].onPrimary;
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];

    CGRect bounds = self.bounds;
    if (bounds.size.height > 0) {
        self.layer.cornerRadius = bounds.size.height / 2.0;
    }

    BOOL isSelected = self.isSelected;
    CGFloat checkmarkWidth = isSelected ? kChipCheckmarkSize : 0.0;
    CGFloat spacing        = isSelected ? kChipCheckmarkSpacing : 0.0;

    // Measure title at current font
    CGSize titleMeasure = [self.titleLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, bounds.size.height)];
    CGFloat contentWidth = checkmarkWidth + spacing + titleMeasure.width;
    CGFloat startX = (bounds.size.width - contentWidth) / 2.0;
    if (startX < kChipHorizontalPadding) {
        startX = kChipHorizontalPadding;
    }

    CGRect checkmarkFrame = CGRectMake(startX, 0.0, checkmarkWidth, bounds.size.height);
    self.checkmarkLabel.frame = checkmarkFrame;

    CGRect titleFrame = CGRectMake(startX + checkmarkWidth + spacing,
                                   0.0,
                                   titleMeasure.width,
                                   bounds.size.height);
    self.titleLabel.frame = titleFrame;
}

- (CGSize)intrinsicContentSize {
    CGSize titleSize = [self.titleLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
    BOOL isSelected = self.isSelected;
    CGFloat checkmarkWidth = isSelected ? kChipCheckmarkSize : 0.0;
    CGFloat spacing        = isSelected ? kChipCheckmarkSpacing : 0.0;

    CGFloat width  = checkmarkWidth + spacing + titleSize.width + kChipHorizontalPadding * 2.0;
    CGFloat height = MAX(titleSize.height + kChipVerticalPadding * 2.0, kChipMinHeight);
    return CGSizeMake(width, height);
}

#pragma mark - Touch Feedback

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    if (self.pressed) return;
    self.pressed = YES;
    [UIView animateWithDuration:kChipPressInDuration
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self.transform = CGAffineTransformMakeScale(kChipPressScale, kChipPressScale);
    }
                     completion:nil];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event {
    [super touchesEnded:touches withEvent:event];

    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self];
    BOOL isInside = CGRectContainsPoint(self.bounds, location);

    self.pressed = NO;
    [UIView animateWithDuration:0.25
                          delay:0.0
         usingSpringWithDamping:0.7
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.transform = CGAffineTransformIdentity;
    }
                     completion:nil];

    if (isInside) {
        // Toggle selection; setSelected:animated: also fires onTap.
        [self setSelected:!self.isSelected animated:YES];
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    if (!self.pressed) return;
    self.pressed = NO;
    [UIView animateWithDuration:kChipAnimationDuration
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.transform = CGAffineTransformIdentity;
    }
                     completion:nil];
}

@end
