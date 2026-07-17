#import "SettingsViewController.h"
#import "MicYouColors.h"
#import "MicYouLanguageManager.h"
#import "MicYouFilterChip.h"
#import "MicYouSettingsItem.h"
#import <objc/runtime.h>

#pragma mark - Layout Constants

static const CGFloat kNavBarHeight              = 64.0f;
static const CGFloat kScrollViewTopInset        = 96.0f;   // 64 + 32
static const CGFloat kScrollViewSideInset       = 16.0f;
static const CGFloat kScrollViewBottomInset     = 16.0f;
static const CGFloat kSectionSpacing            = 24.0f;
static const CGFloat kSectionTitleBarWidth      = 5.0f;
static const CGFloat kSectionTitleBarHeight     = 18.0f;
static const CGFloat kSectionTitleBarRadius     = 3.0f;
static const CGFloat kSectionTitleSpacing       = 8.0f;
static const CGFloat kSectionTitleBottomSpacing = 12.0f;
static const CGFloat kCardCornerRadius           = 28.0f;
static const CGFloat kCardInternalSpacing       = 2.0f;
static const CGFloat kBoxPadding                = 12.0f;
static const CGFloat kChipSpacing                = 8.0f;
static const CGFloat kSeedColorCircleSize       = 48.0f;
static const CGFloat kSeedColorRingWidth        = 3.0f;
static const CGFloat kSeedColorSpacing          = 12.0f;

#pragma mark - Associated Object Keys

static const void *kSwitchCallbackKey    = &kSwitchCallbackKey;
static const void *kDropdownCallbackKey  = &kDropdownCallbackKey;
static const void *kDropdownOptionsKey    = &kDropdownOptionsKey;
static const void *kDropdownSelectedKey   = &kDropdownSelectedKey;
static const void *kListActionKey         = &kListActionKey;
static const void *kCheckUpdateCallbackKey = &kCheckUpdateCallbackKey;
static const void *kChipCallbackKey       = &kChipCallbackKey;
static const void *kChipIndexKey          = &kChipIndexKey;
static const void *kSeedCircleIndexKey    = &kSeedCircleIndexKey;
static const void *kSeedCircleCallbackKey = &kSeedCircleCallbackKey;

#pragma mark - Private Interface

@interface SettingsViewController ()

// Containers
@property (nonatomic, strong) UIView *navBarContainer;
@property (nonatomic, strong) UIVisualEffectView *navBarBlurView;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *navTitleLabel;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;

// State (loaded from defaults)
@property (nonatomic, assign) NSInteger languageValue;
@property (nonatomic, assign) NSInteger darkModeValue;
@property (nonatomic, assign) BOOL oledBlackValue;
@property (nonatomic, assign) NSInteger seedColorIndex;
@property (nonatomic, assign) BOOL useDynamicColorValue;
@property (nonatomic, assign) BOOL useExpressiveShapesValue;
@property (nonatomic, assign) NSInteger visualizerStyleValue;
@property (nonatomic, assign) NSInteger paletteStyleValue;
@property (nonatomic, assign) NSInteger sampleRateValue;
@property (nonatomic, assign) NSInteger channelCountValue;
@property (nonatomic, assign) BOOL streamingNotificationValue;
@property (nonatomic, assign) BOOL autoCheckUpdateValue;
@property (nonatomic, assign) BOOL useMirrorDownloadValue;
@property (nonatomic, assign) BOOL keepScreenOnValue;

// Tracked views for color refresh
@property (nonatomic, strong) NSMutableArray<MicYouSettingsItem *> *registeredItems;
@property (nonatomic, strong) NSMutableArray<MicYouFilterChip *> *registeredChips;
@property (nonatomic, strong) NSMutableArray<void (^)(void)> *registeredColorRefreshBlocks;
@property (nonatomic, strong) NSMutableArray<UIView *> *seedCircleViews;
@property (nonatomic, strong) NSMutableArray<UIView *> *seedRingViews;

@end

#pragma mark - Implementation

@implementation SettingsViewController

#pragma mark - Init / Dealloc

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _registeredItems = [NSMutableArray array];
        _registeredChips = [NSMutableArray array];
        _registeredColorRefreshBlocks = [NSMutableArray array];
        _seedCircleViews = [NSMutableArray array];
        _seedRingViews = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    // 即便外层仍用 UINavigationController 包裹，也隐藏系统导航栏，使用我们自定义的毛玻璃栏
    [self.navigationController setNavigationBarHidden:YES animated:NO];

    self.view.backgroundColor = [MicYouColors shared].background;

    [self loadSettingsFromDefaults];
    [self loadCurrentValues];

    [self setupNavBar];
    [self setupScrollView];
    [self buildContent];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(settingsDidChangeExternally:)
                                                 name:@"MicYouSettingsDidChange"
                                               object:nil];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // 让滚动视图的内容顶部留出状态栏区域以外不需要的额外偏移
    UIEdgeInsets contentInset = self.scrollView.contentInset;
    contentInset.top = 0;
    self.scrollView.contentInset = contentInset;
}

#pragma mark - Navigation Bar

- (void)setupNavBar {
    UIView *navBar = [[UIView alloc] init];
    navBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:navBar];
    self.navBarContainer = navBar;

    UIBlurEffect *blurEffect;
    if (@available(iOS 13.0, *)) {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    } else {
        blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight];
    }
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.userInteractionEnabled = NO;
    [navBar addSubview:blurView];
    self.navBarBlurView = blurView;

    // 底部细分隔线（用 outlineVariant 模拟 Material 3 分隔）
    UIView *divider = [[UIView alloc] init];
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    divider.backgroundColor = [MicYouColors shared].outlineVariant;
    [navBar addSubview:divider];
    [self registerColorRefreshBlock:^{
        divider.backgroundColor = [MicYouColors shared].outlineVariant;
    }];

    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeSystem];
    backButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImage *backImage = [self backChevronImage];
    [backButton setImage:backImage forState:UIControlStateNormal];
    backButton.tintColor = [MicYouColors shared].onBackground;
    backButton.accessibilityLabel = NSLocalizedString(@"button_back", nil);
    [backButton addTarget:self action:@selector(backTapped:) forControlEvents:UIControlEventTouchUpInside];
    [navBar addSubview:backButton];
    self.backButton = backButton;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = NSLocalizedString(@"button_settings", nil);
    titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightSemibold]; // titleLarge SemiBold
    titleLabel.adjustsFontForContentSizeCategory = YES;
    titleLabel.textColor = [MicYouColors shared].onBackground;
    [navBar addSubview:titleLabel];
    self.navTitleLabel = titleLabel;

    [self registerColorRefreshBlock:^{
        self.backButton.tintColor = [MicYouColors shared].onBackground;
        self.navTitleLabel.textColor = [MicYouColors shared].onBackground;
    }];

    [NSLayoutConstraint activateConstraints:@[
        [navBar.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [navBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [navBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [navBar.heightAnchor constraintEqualToConstant:kNavBarHeight + [self safeTopInset]],

        [blurView.topAnchor constraintEqualToAnchor:navBar.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:navBar.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:navBar.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:navBar.bottomAnchor],

        [divider.leadingAnchor constraintEqualToAnchor:navBar.leadingAnchor],
        [divider.trailingAnchor constraintEqualToAnchor:navBar.trailingAnchor],
        [divider.bottomAnchor constraintEqualToAnchor:navBar.bottomAnchor],
        [divider.heightAnchor constraintEqualToConstant:0.5],

        [backButton.leadingAnchor constraintEqualToAnchor:navBar.leadingAnchor constant:4],
        [backButton.topAnchor constraintEqualToAnchor:navBar.topAnchor constant:[self safeTopInset]],
        [backButton.widthAnchor constraintEqualToConstant:48],
        [backButton.heightAnchor constraintEqualToConstant:kNavBarHeight],

        [titleLabel.leadingAnchor constraintEqualToAnchor:backButton.trailingAnchor constant:-4],
        [titleLabel.centerYAnchor constraintEqualToAnchor:backButton.centerYAnchor],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:navBar.trailingAnchor constant:-16],
    ]];
}

- (CGFloat)safeTopInset {
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = (UIWindowScene *)self.view.window.windowScene;
        if (scene != nil) {
            return scene.statusBarManager.statusBarFrame.size.height;
        }
    }
    return [UIApplication sharedApplication].statusBarFrame.size.height;
}

- (UIImage *)backChevronImage {
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20
                                                                                            weight:UIImageSymbolWeightMedium];
        UIImage *img = [UIImage systemImageNamed:@"chevron.left" withConfiguration:config];
        if (img != nil) return img;
    }
    // iOS 11-12 fallback: 绘制简单 chevron
    CGSize size = CGSizeMake(28, 28);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(18, 4)];
    [path addLineToPoint:CGPointMake(10, 14)];
    [path addLineToPoint:CGPointMake(18, 24)];
    [[UIColor blackColor] setStroke];
    path.lineWidth = 2.2;
    path.lineCapStyle = NSLineCapStyleRound;
    path.lineJoinStyle = NSLineJoinStyleRound;
    [path stroke];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (void)backTapped:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Scroll View

- (void)setupScrollView {
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.alwaysBounceVertical = YES;
    scrollView.backgroundColor = [MicYouColors shared].background;
    scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:scrollView];
    self.scrollView = scrollView;

    [self registerColorRefreshBlock:^{
        scrollView.backgroundColor = [MicYouColors shared].background;
    }];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = kSectionSpacing;
    stack.alignment = UIStackViewAlignmentFill;
    stack.distribution = UIStackViewDistributionFill;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:stack];
    self.contentStack = stack;

    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:kScrollViewTopInset],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [stack.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor constant:kScrollViewSideInset],
        [stack.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor constant:-kScrollViewSideInset],
        [stack.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor constant:-kScrollViewBottomInset],
        [stack.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor constant:-2 * kScrollViewSideInset],
    ]];
}

#pragma mark - Defaults Loading

- (void)loadSettingsFromDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:@{
        @"micyou_language": @0,
        @"micyou_dark_mode": @0,
        @"micyou_oled_black": @NO,
        @"micyou_seed_color_index": @0,
        @"micyou_use_dynamic_color": @YES,
        @"micyou_use_expressive_shapes": @YES,
        @"micyou_visualizer_style": @0,
        @"micyou_palette_style": @0,
        @"micyou_sample_rate": @48000,
        @"micyou_channel_count": @2,
        @"micyou_enable_streaming_notification": @YES,
        @"micyou_auto_check_update": @YES,
        @"micyou_use_mirror_download": @NO,
        @"micyou_keep_screen_on": @NO
    }];
}

- (void)loadCurrentValues {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.languageValue               = [defaults integerForKey:@"micyou_language"];
    self.darkModeValue               = [defaults integerForKey:@"micyou_dark_mode"];
    self.oledBlackValue              = [defaults boolForKey:@"micyou_oled_black"];
    self.seedColorIndex              = [defaults integerForKey:@"micyou_seed_color_index"];
    self.useDynamicColorValue        = [defaults boolForKey:@"micyou_use_dynamic_color"];
    self.useExpressiveShapesValue    = [defaults boolForKey:@"micyou_use_expressive_shapes"];
    self.visualizerStyleValue        = [defaults integerForKey:@"micyou_visualizer_style"];
    self.paletteStyleValue           = [defaults integerForKey:@"micyou_palette_style"];
    self.sampleRateValue             = [defaults integerForKey:@"micyou_sample_rate"];
    self.channelCountValue           = [defaults integerForKey:@"micyou_channel_count"];
    self.streamingNotificationValue  = [defaults boolForKey:@"micyou_enable_streaming_notification"];
    self.autoCheckUpdateValue        = [defaults boolForKey:@"micyou_auto_check_update"];
    self.useMirrorDownloadValue      = [defaults boolForKey:@"micyou_use_mirror_download"];
    self.keepScreenOnValue           = [defaults boolForKey:@"micyou_keep_screen_on"];
}

#pragma mark - Persistence

- (void)persistBool:(BOOL)value forKey:(NSString *)key {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:value forKey:key];
    [defaults synchronize];
    [self notifyChangeForKey:key];
}

- (void)persistInteger:(NSInteger)value forKey:(NSString *)key {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:value forKey:key];
    [defaults synchronize];
    [self notifyChangeForKey:key];
}

- (void)notifyChangeForKey:(NSString *)key {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MicYouSettingsDidChange"
                                                       object:nil
                                                     userInfo:@{@"key": key}];
    if (self.onSettingsChanged != nil) {
        self.onSettingsChanged(key);
    }
}

#pragma mark - Content Building

- (void)buildContent {
    [self.contentStack addArrangedSubview:[self buildGeneralSection]];
    [self.contentStack addArrangedSubview:[self buildAppearanceSection]];
    [self.contentStack addArrangedSubview:[self buildAudioSection]];
    [self.contentStack addArrangedSubview:[self buildAboutSection]];
}

#pragma mark - Section Title

- (UIView *)buildSectionTitle:(NSString *)title {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *bar = [[UIView alloc] init];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    bar.backgroundColor = [MicYouColors shared].primary;
    bar.layer.cornerRadius = kSectionTitleBarRadius;
    bar.layer.masksToBounds = YES;
    [container addSubview:bar];

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold]; // titleMedium Bold
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = [MicYouColors shared].primary;
    [container addSubview:label];

    [self registerColorRefreshBlock:^{
        bar.backgroundColor = [MicYouColors shared].primary;
        label.textColor = [MicYouColors shared].primary;
    }];

    [NSLayoutConstraint activateConstraints:@[
        [bar.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [bar.centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
        [bar.widthAnchor constraintEqualToConstant:kSectionTitleBarWidth],
        [bar.heightAnchor constraintEqualToConstant:kSectionTitleBarHeight],

        [label.leadingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:kSectionTitleSpacing],
        [label.topAnchor constraintEqualToAnchor:container.topAnchor],
        [label.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor],
    ]];

    return container;
}

/// 构建一个 section 容器，包含 title + contentStack，使用垂直 UIStackView 内嵌
- (UIView *)buildSectionContainerWithTitle:(NSString *)title
                                 contentView:(UIView *)contentView
                          titleBottomSpacing:(CGFloat)spacing {
    UIView *section = [[UIView alloc] init];
    section.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = spacing;
    stack.alignment = UIStackViewAlignmentFill;
    stack.distribution = UIStackViewDistributionFill;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [section addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:section.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:section.bottomAnchor],
    ]];

    [stack addArrangedSubview:[self buildSectionTitle:title]];
    [stack addArrangedSubview:contentView];

    return section;
}

#pragma mark - Continuous Group Container

- (UIStackView *)buildContinuousGroupWithItems:(NSArray<UIView *> *)items {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = kCardInternalSpacing;
    stack.alignment = UIStackViewAlignmentFill;
    stack.distribution = UIStackViewDistributionFill;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    for (UIView *v in items) {
        [stack addArrangedSubview:v];
    }
    return stack;
}

#pragma mark - Switch Item Builder

- (MicYouSettingsItem *)buildSwitchItemWithTitle:(NSString *)title
                                         subtitle:(NSString *)subtitle
                                              isOn:(BOOL)isOn
                                           isFirst:(BOOL)isFirst
                                            isLast:(BOOL)isLast
                                          onChange:(void (^)(BOOL on))onChange {
    MicYouSettingsItem *item = [[MicYouSettingsItem alloc] initWithStyle:MicYouSettingsItemStyleSwitch
                                                                  isFirst:isFirst
                                                                   isLast:isLast];
    item.titleLabel.text = title;
    item.subtitleLabel.text = subtitle ?: @"";
    item.toggleSwitch.on = isOn;
    item.toggleSwitch.onTintColor = [MicYouColors shared].primary;

    if (onChange != nil) {
        objc_setAssociatedObject(item.toggleSwitch, kSwitchCallbackKey, [onChange copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
        [item.toggleSwitch addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
    }

    [self.registeredItems addObject:item];
    return item;
}

- (void)switchValueChanged:(UISwitch *)sender {
    void (^callback)(BOOL) = objc_getAssociatedObject(sender, kSwitchCallbackKey);
    if (callback != nil) callback(sender.on);
}

#pragma mark - Dropdown Item Builder

- (MicYouSettingsItem *)buildDropdownItemWithTitle:(NSString *)title
                                           options:(NSArray<NSString *> *)options
                                     selectedIndex:(NSInteger)selectedIndex
                                           enabled:(BOOL)enabled
                                           isFirst:(BOOL)isFirst
                                            isLast:(BOOL)isLast
                                          onChange:(void (^)(NSInteger index))onChange {
    MicYouSettingsItem *item = [[MicYouSettingsItem alloc] initWithStyle:MicYouSettingsItemStyleDropdown
                                                                  isFirst:isFirst
                                                                   isLast:isLast];
    item.titleLabel.text = title;
    item.valueLabel.text = (selectedIndex >= 0 && selectedIndex < (NSInteger)options.count) ? options[selectedIndex] : @"";
    item.enabled = enabled;

    if (onChange != nil) {
        objc_setAssociatedObject(item, kDropdownCallbackKey, [onChange copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
        objc_setAssociatedObject(item, kDropdownOptionsKey, [options copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(item, kDropdownSelectedKey, @(selectedIndex), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        item.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dropdownTapped:)];
        [item addGestureRecognizer:tap];
    }

    [self.registeredItems addObject:item];
    return item;
}

- (void)dropdownTapped:(UITapGestureRecognizer *)tap {
    MicYouSettingsItem *item = (MicYouSettingsItem *)tap.view;
    NSArray<NSString *> *options = objc_getAssociatedObject(item, kDropdownOptionsKey);
    NSNumber *selectedNumber = objc_getAssociatedObject(item, kDropdownSelectedKey);
    NSInteger selectedIndex = selectedNumber.integerValue;
    void (^callback)(NSInteger) = objc_getAssociatedObject(item, kDropdownCallbackKey);
    if (options.count == 0 || callback == nil) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSInteger i = 0; i < (NSInteger)options.count; i++) {
        NSString *title = options[i];
        UIAlertAction *action = [UIAlertAction actionWithTitle:title
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *act) {
            objc_setAssociatedObject(item, kDropdownSelectedKey, @(i), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            item.valueLabel.text = title;
            callback(i);
        }];
        [alert addAction:action];
    }
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"button_cancel", nil)
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    alert.popoverPresentationController.sourceView = item;
    alert.popoverPresentationController.sourceRect = CGRectMake(item.bounds.size.width / 2.0,
                                                              item.bounds.size.height / 2.0,
                                                              1, 1);
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - List Item Builder

- (MicYouSettingsItem *)buildListItemWithIcon:(NSString *)iconName
                                        title:(NSString *)title
                                     subtitle:(NSString *)subtitle
                                       action:(void (^)(void))action
                                      isFirst:(BOOL)isFirst
                                       isLast:(BOOL)isLast {
    MicYouSettingsItem *item = [[MicYouSettingsItem alloc] initWithStyle:MicYouSettingsItemStyleList
                                                                  isFirst:isFirst
                                                                   isLast:isLast];
    item.titleLabel.text = title;
    item.subtitleLabel.text = subtitle ?: @"";

    if (item.iconImageView != nil && iconName.length > 0) {
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18
                                                                                                weight:UIImageSymbolWeightRegular];
            UIImage *img = [UIImage systemImageNamed:iconName withConfiguration:config];
            item.iconImageView.image = img;
        }
        // iOS 11-12: 留空，不绘制图标
    }

    if (action != nil) {
        objc_setAssociatedObject(item, kListActionKey, [action copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
        item.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(listItemTapped:)];
        [item addGestureRecognizer:tap];
    }

    [self.registeredItems addObject:item];
    return item;
}

- (void)listItemTapped:(UITapGestureRecognizer *)tap {
    MicYouSettingsItem *item = (MicYouSettingsItem *)tap.view;
    void (^action)(void) = objc_getAssociatedObject(item, kListActionKey);
    if (action != nil) action();
}

#pragma mark - Version Item (custom: icon + title + subtitle + 检查更新 button, 无 chevron)

- (UIView *)buildVersionItemWithVersionText:(NSString *)versionText
                                    isFirst:(BOOL)isFirst
                                     isLast:(BOOL)isLast
                          onCheckUpdate:(void (^)(void))onCheckUpdate {
    MicYouSettingsItem *item = [[MicYouSettingsItem alloc] initWithStyle:MicYouSettingsItemStyleList
                                                                  isFirst:isFirst
                                                                   isLast:isLast];
    item.titleLabel.text = NSLocalizedString(@"about_version", nil);
    item.subtitleLabel.text = versionText;

    if (item.iconImageView != nil) {
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18
                                                                                                weight:UIImageSymbolWeightRegular];
            item.iconImageView.image = [UIImage systemImageNamed:@"info.circle" withConfiguration:config];
        }
    }

    // 通过 KVC 隐藏原 chevron，腾出右侧空间给 "检查更新" 按钮
    @try {
        UIImageView *chevron = [item valueForKey:@"chevronImageView"];
        chevron.hidden = YES;
    } @catch (NSException *e) { /* 忽略 */ }

    UIButton *checkButton = [UIButton buttonWithType:UIButtonTypeSystem];
    checkButton.translatesAutoresizingMaskIntoConstraints = NO;
    [checkButton setTitle:NSLocalizedString(@"about_check_update", nil) forState:UIControlStateNormal];
    checkButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    checkButton.tintColor = [MicYouColors shared].primary;
    [checkButton addTarget:self action:@selector(checkUpdateTapped:) forControlEvents:UIControlEventTouchUpInside];
    if (onCheckUpdate != nil) {
        objc_setAssociatedObject(checkButton, kCheckUpdateCallbackKey, [onCheckUpdate copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
    [item addSubview:checkButton];

    [NSLayoutConstraint activateConstraints:@[
        [checkButton.trailingAnchor constraintEqualToAnchor:item.trailingAnchor constant:-20],
        [checkButton.centerYAnchor constraintEqualToAnchor:item.centerYAnchor],
        [checkButton.leadingAnchor constraintGreaterThanOrEqualToAnchor:item.titleLabel.superview.trailingAnchor constant:12],
    ]];

    [self registerColorRefreshBlock:^{
        checkButton.tintColor = [MicYouColors shared].primary;
    }];

    [self.registeredItems addObject:item];
    return item;
}

- (void)checkUpdateTapped:(UIButton *)sender {
    void (^callback)(void) = objc_getAssociatedObject(sender, kCheckUpdateCallbackKey);
    if (callback != nil) callback();
}

#pragma mark - Box Item Builder

- (UIView *)buildBoxItemWithTitle:(NSString *)title content:(UIView *)content subtitle:(NSString *)subtitle {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = [MicYouColors shared].surfaceBright;
    container.layer.cornerRadius = kCardCornerRadius;
    container.layer.masksToBounds = YES;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.distribution = UIStackViewDistributionFill;
    stack.spacing = 8;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:stack];

    if (title.length > 0) {
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        titleLabel.text = title;
        titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium]; // titleSmall
        titleLabel.adjustsFontForContentSizeCategory = YES;
        titleLabel.textColor = [MicYouColors shared].primary;
        [stack addArrangedSubview:titleLabel];
        [self registerColorRefreshBlock:^{
            titleLabel.textColor = [MicYouColors shared].primary;
        }];
    }

    if (subtitle.length > 0) {
        UILabel *subtitleLabel = [[UILabel alloc] init];
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        subtitleLabel.text = subtitle;
        subtitleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        subtitleLabel.numberOfLines = 0;
        subtitleLabel.adjustsFontForContentSizeCategory = YES;
        subtitleLabel.textColor = [MicYouColors shared].onSurfaceVariant;
        [stack addArrangedSubview:subtitleLabel];
        [self registerColorRefreshBlock:^{
            subtitleLabel.textColor = [MicYouColors shared].onSurfaceVariant;
        }];
    }

    [stack addArrangedSubview:content];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:container.topAnchor constant:kBoxPadding],
        [stack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:kBoxPadding],
        [stack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-kBoxPadding],
        [stack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-kBoxPadding],
    ]];

    [self registerColorRefreshBlock:^{
        container.backgroundColor = [MicYouColors shared].surfaceBright;
    }];

    return container;
}

#pragma mark - FilterChip Helpers

- (UIScrollView *)buildHorizontalChipScrollWithTitles:(NSArray<NSString *> *)titles
                                          selectedIndex:(NSInteger)selectedIndex
                                                onChange:(void (^)(NSInteger index))onChange {
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.alwaysBounceHorizontal = YES;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = kChipSpacing;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:stack];

    for (NSInteger i = 0; i < (NSInteger)titles.count; i++) {
        MicYouFilterChip *chip = [[MicYouFilterChip alloc] initWithTitle:titles[i] selected:(i == selectedIndex)];
        [self.registeredChips addObject:chip];

        if (onChange != nil) {
            objc_setAssociatedObject(chip, kChipCallbackKey, [onChange copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
            objc_setAssociatedObject(chip, kChipIndexKey, @(i), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            chip.onTap = ^(BOOL selected) {
                if (!selected) {
                    // 不允许取消选中：再次标记为选中
                    [chip setSelected:YES animated:NO];
                    return;
                }
                // 互斥：取消其他 chip 的选中状态
                for (MicYouFilterChip *c in self.registeredChips) {
                    if (c != chip && c.selected) {
                        [c setSelected:NO animated:YES];
                    }
                }
                onChange(i);
            };
        }
        [stack addArrangedSubview:chip];
    }

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor],
        [stack.heightAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.heightAnchor],
        [scrollView.heightAnchor constraintEqualToConstant:40],
    ]];

    return scrollView;
}

- (UIStackView *)buildStaticChipRowWithTitles:(NSArray<NSString *> *)titles
                                selectedIndex:(NSInteger)selectedIndex
                                    onChange:(void (^)(NSInteger index))onChange {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = kChipSpacing;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    for (NSInteger i = 0; i < (NSInteger)titles.count; i++) {
        MicYouFilterChip *chip = [[MicYouFilterChip alloc] initWithTitle:titles[i] selected:(i == selectedIndex)];
        [self.registeredChips addObject:chip];

        if (onChange != nil) {
            chip.onTap = ^(BOOL selected) {
                if (!selected) {
                    [chip setSelected:YES animated:NO];
                    return;
                }
                for (MicYouFilterChip *c in self.registeredChips) {
                    if (c != chip && c.selected) {
                        [c setSelected:NO animated:YES];
                    }
                }
                onChange(i);
            };
        }
        [stack addArrangedSubview:chip];
    }
    return stack;
}

#pragma mark - Seed Color Grid Builder

- (UIView *)buildSeedColorGridWithSelectedIndex:(NSInteger)selectedIndex
                                        onChange:(void (^)(NSInteger index))onChange {
    NSArray<UIColor *> *presets = [MicYouColors presetColors];
    NSInteger count = MIN(9, (NSInteger)presets.count);

    UIStackView *outerStack = [[UIStackView alloc] init];
    outerStack.axis = UILayoutConstraintAxisVertical;
    outerStack.alignment = UIStackViewAlignmentFill;
    outerStack.distribution = UIStackViewDistributionFillEqually;
    outerStack.spacing = kSeedColorSpacing;
    outerStack.translatesAutoresizingMaskIntoConstraints = NO;

    [self.seedCircleViews removeAllObjects];
    [self.seedRingViews removeAllObjects];

    for (NSInteger row = 0; row < 3; row++) {
        UIStackView *rowStack = [[UIStackView alloc] init];
        rowStack.axis = UILayoutConstraintAxisHorizontal;
        rowStack.alignment = UIStackViewAlignmentFill;
        rowStack.distribution = UIStackViewDistributionFillEqually;
        rowStack.spacing = kSeedColorSpacing;
        rowStack.translatesAutoresizingMaskIntoConstraints = NO;
        for (NSInteger col = 0; col < 3; col++) {
            NSInteger idx = row * 3 + col;
            if (idx >= count) break;

            UIButton *circleBtn = [UIButton buttonWithType:UIButtonTypeSystem];
            circleBtn.translatesAutoresizingMaskIntoConstraints = NO;
            circleBtn.backgroundColor = presets[idx];
            circleBtn.layer.masksToBounds = YES;
            circleBtn.layer.cornerRadius = kSeedColorCircleSize / 2.0;
            circleBtn.layer.borderWidth = 0;
            [circleBtn addTarget:self action:@selector(seedCircleTapped:) forControlEvents:UIControlEventTouchUpInside];

            // 选中环
            UIView *ring = [[UIView alloc] init];
            ring.translatesAutoresizingMaskIntoConstraints = NO;
            ring.backgroundColor = [UIColor clearColor];
            ring.layer.masksToBounds = YES;
            ring.layer.cornerRadius = (kSeedColorCircleSize + 8) / 2.0;
            ring.layer.borderWidth = kSeedColorRingWidth;
            ring.layer.borderColor = [MicYouColors shared].primary.CGColor;
            ring.userInteractionEnabled = NO;
            ring.hidden = (idx != selectedIndex);
            [circleBtn addSubview:ring];

            [NSLayoutConstraint activateConstraints:@[
                [ring.topAnchor constraintEqualToAnchor:circleBtn.topAnchor constant:-4],
                [ring.bottomAnchor constraintEqualToAnchor:circleBtn.bottomAnchor constant:4],
                [ring.leadingAnchor constraintEqualToAnchor:circleBtn.leadingAnchor constant:-4],
                [ring.trailingAnchor constraintEqualToAnchor:circleBtn.trailingAnchor constant:4],
            ]];

            objc_setAssociatedObject(circleBtn, kSeedCircleIndexKey, @(idx), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (onChange != nil) {
                objc_setAssociatedObject(circleBtn, kSeedCircleCallbackKey, [onChange copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
            }

            // 用 aspect 约束保证圆形
            UIView *aspectHolder = [[UIView alloc] init];
            aspectHolder.translatesAutoresizingMaskIntoConstraints = NO;
            [aspectHolder addSubview:circleBtn];
            [NSLayoutConstraint activateConstraints:@[
                [circleBtn.topAnchor constraintEqualToAnchor:aspectHolder.topAnchor],
                [circleBtn.bottomAnchor constraintEqualToAnchor:aspectHolder.bottomAnchor],
                [circleBtn.leadingAnchor constraintEqualToAnchor:aspectHolder.leadingAnchor],
                [circleBtn.trailingAnchor constraintEqualToAnchor:aspectHolder.trailingAnchor],
                [circleBtn.widthAnchor constraintEqualToAnchor:circleBtn.heightAnchor],
                [aspectHolder.heightAnchor constraintEqualToConstant:kSeedColorCircleSize],
            ]];

            [self.seedCircleViews addObject:circleBtn];
            [self.seedRingViews addObject:ring];
            [rowStack addArrangedSubview:aspectHolder];
        }
        [outerStack addArrangedSubview:rowStack];
    }

    [self registerColorRefreshBlock:^{
        for (UIView *ring in self.seedRingViews) {
            ring.layer.borderColor = [MicYouColors shared].primary.CGColor;
        }
    }];

    return outerStack;
}

- (void)seedCircleTapped:(UIButton *)sender {
    NSNumber *idxNum = objc_getAssociatedObject(sender, kSeedCircleIndexKey);
    NSInteger idx = idxNum.integerValue;
    void (^callback)(NSInteger) = objc_getAssociatedObject(sender, kSeedCircleCallbackKey);

    // 隐藏所有 ring，显示当前选中的
    for (NSInteger i = 0; i < (NSInteger)self.seedRingViews.count; i++) {
        self.seedRingViews[i].hidden = (i != idx);
    }

    if (callback != nil) callback(idx);
}

#pragma mark - Background Button Builder

- (UIButton *)buildPrimaryButtonWithTitle:(NSString *)title action:(void (^)(void))action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn setTitle:title forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [btn setTitleColor:[MicYouColors shared].onPrimary forState:UIControlStateNormal];
    btn.backgroundColor = [MicYouColors shared].primary;
    btn.layer.cornerRadius = 20;
    btn.layer.masksToBounds = YES;
    btn.contentEdgeInsets = UIEdgeInsetsMake(8, 16, 8, 16);

    if (action != nil) {
        objc_setAssociatedObject(btn, kListActionKey, [action copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
        [btn addTarget:self action:@selector(primaryButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    }

    [self registerColorRefreshBlock:^{
        [btn setTitleColor:[MicYouColors shared].onPrimary forState:UIControlStateNormal];
        btn.backgroundColor = [MicYouColors shared].primary;
    }];

    // 给按钮一个合适的 intrinsic size
    [NSLayoutConstraint activateConstraints:@[
        [btn.heightAnchor constraintEqualToConstant:40],
    ]];

    return btn;
}

- (void)primaryButtonTapped:(UIButton *)sender {
    void (^action)(void) = objc_getAssociatedObject(sender, kListActionKey);
    if (action != nil) action();
}

#pragma mark - General Section

- (UIView *)buildGeneralSection {
    NSMutableArray<UIView *> *items = [NSMutableArray array];

    // 1. 语言 Dropdown
    NSArray<NSString *> *langOptions = @[
        NSLocalizedString(@"language_follow_system", nil),
        NSLocalizedString(@"language_chinese", nil),
        NSLocalizedString(@"language_english", nil),
        NSLocalizedString(@"language_traditional_chinese", nil)
    ];
    MicYouSettingsItem *langItem = [self buildDropdownItemWithTitle:NSLocalizedString(@"general_language", nil)
                                                             options:langOptions
                                                       selectedIndex:self.languageValue
                                                             enabled:YES
                                                             isFirst:YES
                                                              isLast:NO
                                                            onChange:^(NSInteger index) {
        self.languageValue = index;
        [self persistInteger:index forKey:@"micyou_language"];
        // 立即应用语言切换
        NSString *code = @"system";
        if (index == 1) code = @"zh-Hans";
        else if (index == 2) code = @"en";
        else if (index == 3) code = @"zh-Hant";
        [[MicYouLanguageManager shared] setLanguage:code];
        [[MicYouLanguageManager shared] applyLanguage];
    }];
    [items addObject:langItem];

    // 2. 串流通知 Switch
    MicYouSettingsItem *streamingItem = [self buildSwitchItemWithTitle:NSLocalizedString(@"general_streaming_notification", nil)
                                                               subtitle:nil
                                                                    isOn:self.streamingNotificationValue
                                                                 isFirst:NO
                                                                  isLast:NO
                                                                onChange:^(BOOL on) {
        self.streamingNotificationValue = on;
        [self persistBool:on forKey:@"micyou_enable_streaming_notification"];
    }];
    [items addObject:streamingItem];

    // 3. 保持屏幕常亮 Switch
    MicYouSettingsItem *keepScreenItem = [self buildSwitchItemWithTitle:NSLocalizedString(@"general_keep_screen_on", nil)
                                                               subtitle:NSLocalizedString(@"general_keep_screen_on_subtitle", nil)
                                                                    isOn:self.keepScreenOnValue
                                                                 isFirst:NO
                                                                  isLast:NO
                                                                onChange:^(BOOL on) {
        self.keepScreenOnValue = on;
        [UIApplication sharedApplication].idleTimerDisabled = on;
        [self persistBool:on forKey:@"micyou_keep_screen_on"];
    }];
    [items addObject:keepScreenItem];

    // 4. 自动检查更新 Switch
    MicYouSettingsItem *autoUpdateItem = [self buildSwitchItemWithTitle:NSLocalizedString(@"general_auto_check_update", nil)
                                                                subtitle:NSLocalizedString(@"general_auto_check_update_subtitle", nil)
                                                                     isOn:self.autoCheckUpdateValue
                                                                  isFirst:NO
                                                                   isLast:NO
                                                                 onChange:^(BOOL on) {
        self.autoCheckUpdateValue = on;
        [self persistBool:on forKey:@"micyou_auto_check_update"];
    }];
    [items addObject:autoUpdateItem];

    // 5. 镜像下载 Switch
    MicYouSettingsItem *mirrorItem = [self buildSwitchItemWithTitle:NSLocalizedString(@"general_mirror_download", nil)
                                                           subtitle:NSLocalizedString(@"general_mirror_download_subtitle", nil)
                                                                isOn:self.useMirrorDownloadValue
                                                             isFirst:NO
                                                              isLast:YES
                                                            onChange:^(BOOL on) {
        self.useMirrorDownloadValue = on;
        [self persistBool:on forKey:@"micyou_use_mirror_download"];
    }];
    [items addObject:mirrorItem];

    UIStackView *group = [self buildContinuousGroupWithItems:items];

    return [self buildSectionContainerWithTitle:NSLocalizedString(@"settings_section_general", nil)
                                    contentView:group
                             titleBottomSpacing:kSectionTitleBottomSpacing];
}

#pragma mark - Appearance Section

- (UIView *)buildAppearanceSection {
    UIView *section = [[UIView alloc] init];
    section.translatesAutoresizingMaskIntoConstraints = NO;
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16;
    stack.alignment = UIStackViewAlignmentFill;
    stack.distribution = UIStackViewDistributionFill;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [section addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:section.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:section.bottomAnchor],
    ]];

    // Section Title
    [stack addArrangedSubview:[self buildSectionTitle:NSLocalizedString(@"settings_section_appearance", nil)]];

    // 1. 主题模式 BoxItem: 3 FilterChip
    NSArray<NSString *> *darkModeOptions = @[
        NSLocalizedString(@"dark_mode_auto", nil),
        NSLocalizedString(@"dark_mode_dark", nil),
        NSLocalizedString(@"dark_mode_light", nil)
    ];
    // 注意：chip 顺序是 system/dark/light，但存储值是 0/2/1
    NSInteger selectedDarkModeChipIndex = 0;
    if (self.darkModeValue == 2) selectedDarkModeChipIndex = 1;
    else if (self.darkModeValue == 1) selectedDarkModeChipIndex = 2;

    UIView *darkModeRow = [self buildStaticChipRowWithTitles:darkModeOptions
                                                selectedIndex:selectedDarkModeChipIndex
                                                    onChange:^(NSInteger chipIndex) {
        // chipIndex 0=system, 1=dark, 2=light -> 存储 0/2/1
        NSInteger storedValue = 0;
        if (chipIndex == 1) storedValue = 2;
        else if (chipIndex == 2) storedValue = 1;
        self.darkModeValue = storedValue;
        [self persistInteger:storedValue forKey:@"micyou_dark_mode"];
    }];
    UIView *darkModeBox = [self buildBoxItemWithTitle:NSLocalizedString(@"appearance_dark_mode", nil)
                                              content:darkModeRow
                                             subtitle:nil];
    [stack addArrangedSubview:darkModeBox];

    // 2. 开启动态取色 + OLED 优化 (连续 Switch 组)
    NSMutableArray<UIView *> *schemeItems = [NSMutableArray array];

    MicYouSettingsItem *dynamicColorItem = [self buildSwitchItemWithTitle:NSLocalizedString(@"appearance_dynamic_color", nil)
                                                                  subtitle:NSLocalizedString(@"appearance_dynamic_color_subtitle", nil)
                                                                       isOn:self.useDynamicColorValue
                                                                    isFirst:YES
                                                                     isLast:NO
                                                                   onChange:^(BOOL on) {
        self.useDynamicColorValue = on;
        [self persistBool:on forKey:@"micyou_use_dynamic_color"];
    }];
    [schemeItems addObject:dynamicColorItem];

    MicYouSettingsItem *oledItem = [self buildSwitchItemWithTitle:NSLocalizedString(@"appearance_oled_black", nil)
                                                          subtitle:NSLocalizedString(@"appearance_oled_black_subtitle", nil)
                                                               isOn:self.oledBlackValue
                                                            isFirst:NO
                                                             isLast:YES
                                                           onChange:^(BOOL on) {
        self.oledBlackValue = on;
        [self persistBool:on forKey:@"micyou_oled_black"];
    }];
    [schemeItems addObject:oledItem];

    [stack addArrangedSubview:[self buildContinuousGroupWithItems:schemeItems]];

    // 3. 主题颜色 BoxItem: 9 色 3x3 选择器
    UIView *seedGrid = [self buildSeedColorGridWithSelectedIndex:self.seedColorIndex
                                                        onChange:^(NSInteger index) {
        self.seedColorIndex = index;
        [self persistInteger:index forKey:@"micyou_seed_color_index"];
        // 立即更新 MicYouColors 单例
        NSArray<UIColor *> *presets = [MicYouColors presetColors];
        if (index >= 0 && index < (NSInteger)presets.count) {
            [MicYouColors shared].seedColor = presets[index];
        }
    }];
    UIView *seedBox = [self buildBoxItemWithTitle:NSLocalizedString(@"appearance_seed_color", nil)
                                          content:seedGrid
                                         subtitle:nil];
    [stack addArrangedSubview:seedBox];

    // 4. 色彩风格 BoxItem: 横向滚动 7 种
    NSArray<NSString *> *paletteOptions = @[
        NSLocalizedString(@"palette_tonal_spot", nil),
        NSLocalizedString(@"palette_vibrant", nil),
        NSLocalizedString(@"palette_expressive", nil),
        NSLocalizedString(@"palette_content", nil),
        NSLocalizedString(@"palette_fidelity", nil),
        NSLocalizedString(@"palette_monochrome", nil),
        NSLocalizedString(@"palette_custom", nil)
    ];
    UIView *paletteScroll = [self buildHorizontalChipScrollWithTitles:paletteOptions
                                                         selectedIndex:self.paletteStyleValue
                                                               onChange:^(NSInteger index) {
        self.paletteStyleValue = index;
        [self persistInteger:index forKey:@"micyou_palette_style"];
    }];
    UIView *paletteBox = [self buildBoxItemWithTitle:NSLocalizedString(@"appearance_palette_style", nil)
                                            content:paletteScroll
                                           subtitle:NSLocalizedString(@"appearance_palette_style_subtitle", nil)];
    [stack addArrangedSubview:paletteBox];

    // 5. 表达性形状 (独立 Switch)
    MicYouSettingsItem *expressiveItem = [self buildSwitchItemWithTitle:NSLocalizedString(@"appearance_expressive_shapes", nil)
                                                               subtitle:NSLocalizedString(@"appearance_expressive_shapes_subtitle", nil)
                                                                    isOn:self.useExpressiveShapesValue
                                                                 isFirst:YES
                                                                  isLast:YES
                                                                onChange:^(BOOL on) {
        self.useExpressiveShapesValue = on;
        [self persistBool:on forKey:@"micyou_use_expressive_shapes"];
    }];
    [stack addArrangedSubview:[self buildContinuousGroupWithItems:@[expressiveItem]]];

    // 6. 可视化样式 BoxItem: 6 FilterChip
    NSArray<NSString *> *visualizerOptions = @[
        NSLocalizedString(@"visualizer_volume_ring", nil),
        NSLocalizedString(@"visualizer_ripple", nil),
        NSLocalizedString(@"visualizer_bars", nil),
        NSLocalizedString(@"visualizer_wave", nil),
        NSLocalizedString(@"visualizer_glow", nil),
        NSLocalizedString(@"visualizer_particles", nil)
    ];
    UIView *visScroll = [self buildHorizontalChipScrollWithTitles:visualizerOptions
                                                     selectedIndex:self.visualizerStyleValue
                                                           onChange:^(NSInteger index) {
        self.visualizerStyleValue = index;
        [self persistInteger:index forKey:@"micyou_visualizer_style"];
    }];
    UIView *visBox = [self buildBoxItemWithTitle:NSLocalizedString(@"appearance_visualizer_style", nil)
                                        content:visScroll
                                       subtitle:nil];
    [stack addArrangedSubview:visBox];

    // 7. 背景 BoxItem: "选择图片" primary 按钮
    UIButton *bgButton = [self buildPrimaryButtonWithTitle:NSLocalizedString(@"appearance_select_image", nil)
                                                    action:^{
        // 背景图片选择暂未实现 - 留作占位
    }];
    // 居左对齐
    UIView *bgButtonContainer = [[UIView alloc] init];
    bgButtonContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [bgButtonContainer addSubview:bgButton];
    [NSLayoutConstraint activateConstraints:@[
        [bgButton.leadingAnchor constraintEqualToAnchor:bgButtonContainer.leadingAnchor],
        [bgButton.topAnchor constraintEqualToAnchor:bgButtonContainer.topAnchor],
        [bgButton.bottomAnchor constraintEqualToAnchor:bgButtonContainer.bottomAnchor],
        [bgButtonContainer.trailingAnchor constraintGreaterThanOrEqualToAnchor:bgButton.trailingAnchor],
    ]];
    UIView *bgBox = [self buildBoxItemWithTitle:NSLocalizedString(@"appearance_background", nil)
                                        content:bgButtonContainer
                                       subtitle:nil];
    [stack addArrangedSubview:bgBox];

    return section;
}

#pragma mark - Audio Section

- (UIView *)buildAudioSection {
    NSMutableArray<UIView *> *items = [NSMutableArray array];

    // 1. 采样率 Dropdown
    NSArray<NSString *> *rateOptions = @[
        @"44100 Hz",
        @"48000 Hz",
        @"96000 Hz"
    ];
    NSInteger rateSelected = 0;
    if (self.sampleRateValue == 48000) rateSelected = 1;
    else if (self.sampleRateValue == 96000) rateSelected = 2;
    MicYouSettingsItem *rateItem = [self buildDropdownItemWithTitle:NSLocalizedString(@"audio_sample_rate", nil)
                                                            options:rateOptions
                                                      selectedIndex:rateSelected
                                                            enabled:YES
                                                            isFirst:YES
                                                             isLast:NO
                                                           onChange:^(NSInteger index) {
        NSInteger rates[] = {44100, 48000, 96000};
        self.sampleRateValue = rates[index];
        [self persistInteger:rates[index] forKey:@"micyou_sample_rate"];
    }];
    [items addObject:rateItem];

    // 2. 通道数 Dropdown
    NSArray<NSString *> *channelOptions = @[
        NSLocalizedString(@"audio_mono", nil),
        NSLocalizedString(@"audio_stereo", nil)
    ];
    NSInteger channelSelected = (self.channelCountValue == 2) ? 1 : 0;
    MicYouSettingsItem *channelItem = [self buildDropdownItemWithTitle:NSLocalizedString(@"audio_channel", nil)
                                                                options:channelOptions
                                                          selectedIndex:channelSelected
                                                                enabled:YES
                                                                isFirst:NO
                                                                 isLast:YES
                                                               onChange:^(NSInteger index) {
        NSInteger count = (index == 1) ? 2 : 1;
        self.channelCountValue = count;
        [self persistInteger:count forKey:@"micyou_channel_count"];
    }];
    [items addObject:channelItem];

    UIStackView *group = [self buildContinuousGroupWithItems:items];

    return [self buildSectionContainerWithTitle:NSLocalizedString(@"settings_section_audio", nil)
                                    contentView:group
                             titleBottomSpacing:kSectionTitleBottomSpacing];
}

#pragma mark - About Section

- (UIView *)buildAboutSection {
    NSMutableArray<UIView *> *items = [NSMutableArray array];

    // 1. 开发者
    MicYouSettingsItem *devItem = [self buildListItemWithIcon:@"person.fill"
                                                        title:NSLocalizedString(@"about_developer", nil)
                                                     subtitle:NSLocalizedString(@"about_developer_subtitle", nil)
                                                       action:nil
                                                      isFirst:YES
                                                       isLast:NO];
    [items addObject:devItem];

    // 2. GitHub 仓库
    MicYouSettingsItem *repoItem = [self buildListItemWithIcon:@"globe"
                                                         title:NSLocalizedString(@"about_github_repo", nil)
                                                      subtitle:@"LanRhyme/MicYou"
                                                        action:^{
        NSURL *url = [NSURL URLWithString:@"https://github.com/MicYou-Dev/MicYou-iOS"];
        [self openURL:url];
    }
                                                       isFirst:NO
                                                        isLast:NO];
    [items addObject:repoItem];

    // 3. 贡献者
    MicYouSettingsItem *contribItem = [self buildListItemWithIcon:@"person.2.fill"
                                                           title:NSLocalizedString(@"about_contributors", nil)
                                                        subtitle:NSLocalizedString(@"about_contributors_subtitle", nil)
                                                          action:nil
                                                         isFirst:NO
                                                          isLast:NO];
    [items addObject:contribItem];

    // 4. 赞助者
    MicYouSettingsItem *sponsorItem = [self buildListItemWithIcon:@"heart.fill"
                                                           title:NSLocalizedString(@"about_sponsors", nil)
                                                        subtitle:NSLocalizedString(@"about_sponsors_subtitle", nil)
                                                          action:nil
                                                         isFirst:NO
                                                          isLast:NO];
    [items addObject:sponsorItem];

    // 5. 版本 (自定义 view with 检查更新 button)
    NSString *appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0.0";
    NSString *versionText = [NSString stringWithFormat:@"v%@ (Framework v2.0.0-1)", appVersion];
    UIView *versionItem = [self buildVersionItemWithVersionText:versionText
                                                        isFirst:NO
                                                         isLast:NO
                                                     onCheckUpdate:^{
        // 检查更新 - 暂为占位
    }];
    [items addObject:versionItem];

    // 6. 开源许可
    MicYouSettingsItem *licenseItem = [self buildListItemWithIcon:@"doc.text.fill"
                                                            title:NSLocalizedString(@"about_open_source_licenses", nil)
                                                         subtitle:NSLocalizedString(@"about_open_source_licenses_subtitle", nil)
                                                           action:nil
                                                          isFirst:NO
                                                           isLast:NO];
    [items addObject:licenseItem];

    // 7. 导出日志
    MicYouSettingsItem *logItem = [self buildListItemWithIcon:@"doc.on.clipboard.fill"
                                                        title:NSLocalizedString(@"about_export_logs", nil)
                                                     subtitle:NSLocalizedString(@"about_export_logs_subtitle", nil)
                                                       action:nil
                                                      isFirst:NO
                                                       isLast:YES];
    [items addObject:logItem];

    UIStackView *group = [self buildContinuousGroupWithItems:items];

    UIView *section = [[UIView alloc] init];
    section.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16;
    stack.alignment = UIStackViewAlignmentFill;
    stack.distribution = UIStackViewDistributionFill;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [section addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:section.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:section.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:section.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:section.bottomAnchor],
    ]];

    [stack addArrangedSubview:[self buildSectionTitle:NSLocalizedString(@"settings_section_about", nil)]];
    [stack addArrangedSubview:group];

    // 底部信息卡
    [stack addArrangedSubview:[self buildAboutFooterCard]];

    return section;
}

- (UIView *)buildAboutFooterCard {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [[MicYouColors shared].secondaryContainer colorWithAlphaComponent:0.7];
    card.layer.cornerRadius = kCardCornerRadius;
    card.layer.masksToBounds = YES;

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.numberOfLines = 0;
    label.text = NSLocalizedString(@"about_footer_text", nil);
    label.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    label.textColor = [MicYouColors shared].onSecondaryContainer;
    label.adjustsFontForContentSizeCategory = YES;
    [card addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [label.topAnchor constraintEqualToAnchor:card.topAnchor constant:kBoxPadding],
        [label.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:kBoxPadding],
        [label.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-kBoxPadding],
        [label.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-kBoxPadding],
    ]];

    [self registerColorRefreshBlock:^{
        card.backgroundColor = [[MicYouColors shared].secondaryContainer colorWithAlphaComponent:0.7];
        label.textColor = [MicYouColors shared].onSecondaryContainer;
    }];

    return card;
}

#pragma mark - URL Opening

- (void)openURL:(NSURL *)url {
    if (url == nil) return;
    if (@available(iOS 10.0, *)) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    } else {
        [[UIApplication sharedApplication] openURL:url];
    }
}

#pragma mark - Color Refresh

- (void)registerColorRefreshBlock:(void (^)(void))block {
    if (block != nil) [self.registeredColorRefreshBlocks addObject:[block copy]];
}

- (void)refreshColors {
    // 重建导航栏视觉（毛玻璃在 dark/light 切换时需要更新）
    if (@available(iOS 13.0, *)) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
        self.navBarBlurView.effect = blur;
    }

    // 重建 seed color 圆形（颜色可能变化）
    NSArray<UIColor *> *presets = [MicYouColors presetColors];
    for (NSInteger i = 0; i < (NSInteger)self.seedCircleViews.count; i++) {
        if (i < (NSInteger)presets.count) {
            self.seedCircleViews[i].backgroundColor = presets[i];
        }
    }

    // 刷新所有 MicYouSettingsItem
    for (MicYouSettingsItem *item in self.registeredItems) {
        [item refreshColors];
    }

    // 刷新所有 MicYouFilterChip
    for (MicYouFilterChip *chip in self.registeredChips) {
        [chip refreshColors];
    }

    // 执行所有自定义刷新块
    for (void (^block)(void) in self.registeredColorRefreshBlocks) {
        block();
    }

    // 刷新 view 背景
    self.view.backgroundColor = [MicYouColors shared].background;
    self.scrollView.backgroundColor = [MicYouColors shared].background;
}

- (void)settingsDidChangeExternally:(NSNotification *)notification {
    // 推迟到下一个 runloop，让 MicYouViewController 先应用新色板
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshColors];
    });
}

@end
