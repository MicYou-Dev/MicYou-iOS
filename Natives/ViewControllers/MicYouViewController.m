#import "MicYouViewController.h"
#import "MicYouAnimator.h"
#import "MicYouLogger.h"
#import "MicYouColors.h"
#import "SettingsViewController.h"

// Audio level update throttle interval
static const CFTimeInterval kAudioLevelUpdateInterval = 0.05;

// Layout constants
static const CGFloat kHeaderHeight = 120.0;
static const CGFloat kConfigCardHeight = 170.0;
static const CGFloat kControlCardHeight = 300.0;
static const CGFloat kBottomBarHeight = 64.0;
static const CGFloat kCardCornerRadius = 28.0;
static const CGFloat kIconSize = 56.0;
static const CGFloat kFabDiameter = 80.0;
static const CGFloat kMargin = 16.0;
static const CGFloat kSmallMargin = 8.0;
static const CGFloat kPillHeight = 44.0;

@interface MicYouViewController () <UITextFieldDelegate>

// Core services
@property (nonatomic, strong) MicYouAudioCapture *audioCapture;
@property (nonatomic, strong) TransportClient *transportClient;
@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, assign) BOOL isStreaming;
@property (nonatomic, assign) BOOL isMuted;

// Scroll
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;

// Header
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIImageView *appIconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *ipLabel;
@property (nonatomic, strong) UIButton *headerSettingsButton;

// Connection config card
@property (nonatomic, strong) UIView *configCard;
@property (nonatomic, strong) UIButton *wifiModeButton;
@property (nonatomic, strong) UIButton *usbModeButton;
@property (nonatomic, strong) UITextField *hostTextField;
@property (nonatomic, strong) UITextField *portTextField;
@property (nonatomic, assign) BOOL isWiFiMode;

// Main control card
@property (nonatomic, strong) UIView *controlCard;
@property (nonatomic, strong) UIImageView *statusIconView;
@property (nonatomic, strong) UILabel *statusTextLabel;
@property (nonatomic, strong) UIView *liveBadge;
@property (nonatomic, strong) UIView *visualizerView;
@property (nonatomic, strong) NSMutableArray<UIView *> *visualizerBars;
@property (nonatomic, strong) UIButton *mainActionButton;
@property (nonatomic, strong) UIView *mainActionGlowView;

// Bottom bar
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIButton *muteButton;
@property (nonatomic, strong) UIView *statusDot;
@property (nonatomic, strong) UILabel *versionLabel;

// State
@property (nonatomic, assign) CFTimeInterval lastLevelUpdateTime;
@property (nonatomic, strong) NSMutableArray<UIView *> *staggerViews;

// Tracking for color animations
@property (nonatomic, assign) BOOL hasAppeared;

@end

@implementation MicYouViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"MicYou";
    self.view.backgroundColor = [MicYouColors shared].background;
    self.isWiFiMode = YES;
    self.isMuted = NO;

    [self setupScrollView];
    [self setupHeaderView];
    [self setupConfigCard];
    [self setupControlCard];
    [self setupBottomBar];
    [self setupAudioAndNetwork];
    [self applyColors];
    [self loadSavedSettings];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (!self.hasAppeared) {
        self.hasAppeared = YES;
        [MicYouAnimator animateStaggeredEntrance:self.staggerViews
                                       baseDelay:0.08
                                       direction:0];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // Glow is positioned via Auto Layout; no manual adjustment needed
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];

    if (@available(iOS 13.0, *)) {
        if (self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle) {
            [self updateColorSchemeFromTrait];
        }
    }
}

#pragma mark - Scroll View

- (void)setupScrollView {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor],
    ]];
}

#pragma mark - Header View

- (void)setupHeaderView {
    self.headerView = [[UIView alloc] init];
    self.headerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.headerView];

    // App icon
    self.appIconView = [[UIImageView alloc] init];
    self.appIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.appIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.appIconView.layer.cornerRadius = kIconSize / 2.0;
    self.appIconView.clipsToBounds = YES;
    self.appIconView.image = [UIImage imageNamed:@"app_icon"];

    // Use a microphone emoji if no icon loaded
    if (!self.appIconView.image) {
        UILabel *iconLabel = [[UILabel alloc] init];
        iconLabel.text = @"🎤";
        iconLabel.font = [UIFont systemFontOfSize:kIconSize * 0.55];
        iconLabel.textAlignment = NSTextAlignmentCenter;
        iconLabel.frame = CGRectMake(0, 0, kIconSize, kIconSize);
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(kIconSize, kIconSize), NO, 0);
        [iconLabel.layer renderInContext:UIGraphicsGetCurrentContext()];
        self.appIconView.image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    [self.headerView addSubview:self.appIconView];

    // Title
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.text = @"MicYou";
    self.titleLabel.font = [UIFont systemFontOfSize:32 weight:UIFontWeightBold];
    self.titleLabel.textColor = [MicYouColors shared].primary;
    [self.headerView addSubview:self.titleLabel];

    // IP label
    self.ipLabel = [[UILabel alloc] init];
    self.ipLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.ipLabel.text = NSLocalizedString(@"host_not_configured", nil);
    self.ipLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    self.ipLabel.textColor = [MicYouColors shared].onSurfaceVariant;
    self.ipLabel.numberOfLines = 1;
    self.ipLabel.adjustsFontSizeToFitWidth = YES;
    [self.headerView addSubview:self.ipLabel];

    // Settings button (gear icon)
    self.headerSettingsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.headerSettingsButton.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        UIImage *gearImage = [UIImage systemImageNamed:@"gear"];
        [self.headerSettingsButton setImage:gearImage forState:UIControlStateNormal];
    } else {
        [self.headerSettingsButton setTitle:@"\u2699" forState:UIControlStateNormal];
        self.headerSettingsButton.titleLabel.font = [UIFont systemFontOfSize:22];
    }
    self.headerSettingsButton.tintColor = [MicYouColors shared].onSurfaceVariant;
    [self.headerSettingsButton addTarget:self
                                  action:@selector(headerSettingsTapped:)
                        forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:self.headerSettingsButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.headerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:kMargin],
        [self.headerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:kMargin],
        [self.headerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-kMargin],
        [self.headerView.heightAnchor constraintEqualToConstant:kHeaderHeight],

        [self.appIconView.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor constant:kSmallMargin],
        [self.appIconView.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],
        [self.appIconView.widthAnchor constraintEqualToConstant:kIconSize],
        [self.appIconView.heightAnchor constraintEqualToConstant:kIconSize],

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.appIconView.trailingAnchor constant:14],
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.appIconView.topAnchor constant:2],

        [self.ipLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.ipLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4],

        [self.headerSettingsButton.centerYAnchor constraintEqualToAnchor:self.appIconView.centerYAnchor],
        [self.headerSettingsButton.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor constant:-kSmallMargin],
        [self.headerSettingsButton.widthAnchor constraintEqualToConstant:44],
        [self.headerSettingsButton.heightAnchor constraintEqualToConstant:44],
    ]];
}

#pragma mark - Config Card

- (void)setupConfigCard {
    self.configCard = [[UIView alloc] init];
    self.configCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.configCard.layer.cornerRadius = kCardCornerRadius;
    [self.contentView addSubview:self.configCard];

    // Mode selector
    self.wifiModeButton = [self createModeButton:NSLocalizedString(@"mode_wifi", nil)];
    self.wifiModeButton.selected = YES;
    [self.wifiModeButton addTarget:self
                            action:@selector(modeButtonTapped:)
                  forControlEvents:UIControlEventTouchUpInside];

    self.usbModeButton = [self createModeButton:NSLocalizedString(@"mode_usb", nil)];
    [self.usbModeButton addTarget:self
                           action:@selector(modeButtonTapped:)
                 forControlEvents:UIControlEventTouchUpInside];

    UIStackView *modeStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.wifiModeButton, self.usbModeButton]];
    modeStack.translatesAutoresizingMaskIntoConstraints = NO;
    modeStack.axis = UILayoutConstraintAxisHorizontal;
    modeStack.spacing = kSmallMargin;
    modeStack.distribution = UIStackViewDistributionFillEqually;
    [self.configCard addSubview:modeStack];

    // Host text field
    self.hostTextField = [self createTextFieldWithPlaceholder:NSLocalizedString(@"network_host_label", nil)
                                                    keyboardType:UIKeyboardTypeURL];
    [self.configCard addSubview:self.hostTextField];

    // Port text field
    self.portTextField = [self createTextFieldWithPlaceholder:NSLocalizedString(@"network_port_label", nil)
                                                    keyboardType:UIKeyboardTypeNumberPad];
    [self.configCard addSubview:self.portTextField];

    [NSLayoutConstraint activateConstraints:@[
        [self.configCard.topAnchor constraintEqualToAnchor:self.headerView.bottomAnchor constant:kMargin],
        [self.configCard.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:kMargin],
        [self.configCard.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-kMargin],
        [self.configCard.heightAnchor constraintEqualToConstant:kConfigCardHeight],

        [modeStack.topAnchor constraintEqualToAnchor:self.configCard.topAnchor constant:kMargin],
        [modeStack.leadingAnchor constraintEqualToAnchor:self.configCard.leadingAnchor constant:kMargin],
        [modeStack.trailingAnchor constraintEqualToAnchor:self.configCard.trailingAnchor constant:-kMargin],
        [modeStack.heightAnchor constraintEqualToConstant:kPillHeight],

        [self.hostTextField.topAnchor constraintEqualToAnchor:modeStack.bottomAnchor constant:14],
        [self.hostTextField.leadingAnchor constraintEqualToAnchor:self.configCard.leadingAnchor constant:kMargin],
        [self.hostTextField.trailingAnchor constraintEqualToAnchor:self.configCard.trailingAnchor constant:-kMargin],
        [self.hostTextField.heightAnchor constraintEqualToConstant:kPillHeight],

        [self.portTextField.topAnchor constraintEqualToAnchor:self.hostTextField.bottomAnchor constant:kSmallMargin],
        [self.portTextField.leadingAnchor constraintEqualToAnchor:self.configCard.leadingAnchor constant:kMargin],
        [self.portTextField.trailingAnchor constraintEqualToAnchor:self.configCard.trailingAnchor constant:-kMargin],
        [self.portTextField.heightAnchor constraintEqualToConstant:kPillHeight],
    ]];
}

#pragma mark - Control Card

- (void)setupControlCard {
    self.controlCard = [[UIView alloc] init];
    self.controlCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.controlCard.layer.cornerRadius = kCardCornerRadius;
    [self.contentView addSubview:self.controlCard];

    // Status icon
    self.statusIconView = [[UIImageView alloc] init];
    self.statusIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.statusIconView.tintColor = [MicYouColors shared].onSurfaceVariant;
    if (@available(iOS 13.0, *)) {
        self.statusIconView.image = [UIImage systemImageNamed:@"mic.slash.fill"];
    }
    // Fallback: no system image on iOS <13; we set a label-based fallback below
    if (!self.statusIconView.image) {
        self.statusIconView.image = [self textToImage:@"🎤❌" size:CGSizeMake(48, 48)];
    }
    [self.controlCard addSubview:self.statusIconView];

    // Status text
    self.statusTextLabel = [[UILabel alloc] init];
    self.statusTextLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusTextLabel.text = NSLocalizedString(@"status_not_connected", nil);
    self.statusTextLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightMedium];
    self.statusTextLabel.textColor = [MicYouColors shared].onSurface;
    self.statusTextLabel.textAlignment = NSTextAlignmentCenter;
    [self.controlCard addSubview:self.statusTextLabel];

    // LIVE badge
    self.liveBadge = [[UIView alloc] init];
    self.liveBadge.translatesAutoresizingMaskIntoConstraints = NO;
    self.liveBadge.backgroundColor = [MicYouColors shared].error;
    self.liveBadge.layer.cornerRadius = 11;
    self.liveBadge.clipsToBounds = YES;
    self.liveBadge.hidden = YES;

    UILabel *liveLabel = [[UILabel alloc] init];
    liveLabel.translatesAutoresizingMaskIntoConstraints = NO;
    liveLabel.text = NSLocalizedString(@"live_badge", nil);
    liveLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    liveLabel.textColor = [UIColor whiteColor];
    liveLabel.textAlignment = NSTextAlignmentCenter;
    [self.liveBadge addSubview:liveLabel];

    [NSLayoutConstraint activateConstraints:@[
        [liveLabel.centerXAnchor constraintEqualToAnchor:self.liveBadge.centerXAnchor],
        [liveLabel.centerYAnchor constraintEqualToAnchor:self.liveBadge.centerYAnchor],
        [self.liveBadge.widthAnchor constraintEqualToConstant:44],
        [self.liveBadge.heightAnchor constraintEqualToConstant:22],
    ]];
    [self.controlCard addSubview:self.liveBadge];

    // Audio visualizer
    self.visualizerView = [[UIView alloc] init];
    self.visualizerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.visualizerView.layer.cornerRadius = 14;
    self.visualizerView.layer.masksToBounds = YES;
    [self.controlCard addSubview:self.visualizerView];

    [self setupVisualizerBars];

    // Main action button (FAB)
    self.mainActionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.mainActionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.mainActionButton.layer.cornerRadius = kFabDiameter / 2.0;
    self.mainActionButton.clipsToBounds = YES;
    [self.mainActionButton setTitle:NSLocalizedString(@"button_connect", nil) forState:UIControlStateNormal];
    [self.mainActionButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.mainActionButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    [self.mainActionButton addTarget:self
                              action:@selector(mainActionButtonTapped:)
                    forControlEvents:UIControlEventTouchUpInside];
    [self.controlCard addSubview:self.mainActionButton];

    // Glow behind FAB
    self.mainActionGlowView = [[UIView alloc] init];
    self.mainActionGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.mainActionGlowView.layer.cornerRadius = (kFabDiameter + 20) / 2.0;
    self.mainActionGlowView.backgroundColor = [[MicYouColors shared].primary colorWithAlphaComponent:0.25];
    self.mainActionGlowView.userInteractionEnabled = NO;
    self.mainActionGlowView.hidden = YES;
    [self.controlCard insertSubview:self.mainActionGlowView belowSubview:self.mainActionButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.controlCard.topAnchor constraintEqualToAnchor:self.configCard.bottomAnchor constant:kMargin],
        [self.controlCard.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:kMargin],
        [self.controlCard.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-kMargin],
        [self.controlCard.heightAnchor constraintEqualToConstant:kControlCardHeight],

        [self.statusIconView.topAnchor constraintEqualToAnchor:self.controlCard.topAnchor constant:24],
        [self.statusIconView.centerXAnchor constraintEqualToAnchor:self.controlCard.centerXAnchor],
        [self.statusIconView.widthAnchor constraintEqualToConstant:48],
        [self.statusIconView.heightAnchor constraintEqualToConstant:48],

        [self.statusTextLabel.topAnchor constraintEqualToAnchor:self.statusIconView.bottomAnchor constant:10],
        [self.statusTextLabel.centerXAnchor constraintEqualToAnchor:self.controlCard.centerXAnchor],

        [self.liveBadge.topAnchor constraintEqualToAnchor:self.statusTextLabel.bottomAnchor constant:6],
        [self.liveBadge.centerXAnchor constraintEqualToAnchor:self.controlCard.centerXAnchor],

        [self.visualizerView.topAnchor constraintEqualToAnchor:self.liveBadge.bottomAnchor constant:12],
        [self.visualizerView.leadingAnchor constraintEqualToAnchor:self.controlCard.leadingAnchor constant:kMargin],
        [self.visualizerView.trailingAnchor constraintEqualToAnchor:self.controlCard.trailingAnchor constant:-kMargin],
        [self.visualizerView.heightAnchor constraintEqualToConstant:36],

        [self.mainActionButton.centerXAnchor constraintEqualToAnchor:self.controlCard.centerXAnchor],
        [self.mainActionButton.bottomAnchor constraintEqualToAnchor:self.controlCard.bottomAnchor constant:-16],
        [self.mainActionButton.widthAnchor constraintEqualToConstant:kFabDiameter],
        [self.mainActionButton.heightAnchor constraintEqualToConstant:kFabDiameter],

        [self.mainActionGlowView.centerXAnchor constraintEqualToAnchor:self.mainActionButton.centerXAnchor],
        [self.mainActionGlowView.centerYAnchor constraintEqualToAnchor:self.mainActionButton.centerYAnchor],
        [self.mainActionGlowView.widthAnchor constraintEqualToConstant:kFabDiameter + 20],
        [self.mainActionGlowView.heightAnchor constraintEqualToConstant:kFabDiameter + 20],
    ]];
}

- (void)setupVisualizerBars {
    self.visualizerBars = [NSMutableArray array];
    NSInteger barCount = 20;
    CGFloat barWidth = 3.0;

    UIStackView *barsStack = [[UIStackView alloc] init];
    barsStack.translatesAutoresizingMaskIntoConstraints = NO;
    barsStack.axis = UILayoutConstraintAxisHorizontal;
    barsStack.alignment = UIStackViewAlignmentBottom;
    barsStack.distribution = UIStackViewDistributionEqualSpacing;
    barsStack.spacing = 3;
    [self.visualizerView addSubview:barsStack];

    for (NSInteger i = 0; i < barCount; i++) {
        UIView *bar = [[UIView alloc] init];
        bar.translatesAutoresizingMaskIntoConstraints = NO;
        bar.layer.cornerRadius = barWidth / 2.0;
        bar.backgroundColor = [MicYouColors shared].primary;
        [barsStack addArrangedSubview:bar];
        [self.visualizerBars addObject:bar];

        [NSLayoutConstraint activateConstraints:@[
            [bar.widthAnchor constraintEqualToConstant:barWidth],
            [bar.heightAnchor constraintEqualToConstant:4],
        ]];
    }

    [NSLayoutConstraint activateConstraints:@[
        [barsStack.centerXAnchor constraintEqualToAnchor:self.visualizerView.centerXAnchor],
        [barsStack.centerYAnchor constraintEqualToAnchor:self.visualizerView.centerYAnchor constant:2],
        [barsStack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.visualizerView.leadingAnchor constant:8],
        [barsStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.visualizerView.trailingAnchor constant:-8],
    ]];
}

#pragma mark - Bottom Bar

- (void)setupBottomBar {
    self.bottomBar = [[UIView alloc] init];
    self.bottomBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.bottomBar];

    // Mute button
    self.muteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.muteButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.muteButton setTitle:NSLocalizedString(@"button_mute", nil) forState:UIControlStateNormal];
    self.muteButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.muteButton.layer.cornerRadius = 18;
    self.muteButton.clipsToBounds = YES;
    [self.muteButton addTarget:self
                        action:@selector(muteButtonTapped:)
              forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.muteButton];

    // Status dot
    self.statusDot = [[UIView alloc] init];
    self.statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusDot.layer.cornerRadius = 5;
    self.statusDot.backgroundColor = [MicYouColors shared].outline;
    [self.bottomBar addSubview:self.statusDot];

    // Version label
    self.versionLabel = [[UILabel alloc] init];
    self.versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0";
    self.versionLabel.text = [NSString stringWithFormat:NSLocalizedString(@"app_version_format", nil), version];
    self.versionLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    self.versionLabel.textColor = [MicYouColors shared].outline;
    self.versionLabel.textAlignment = NSTextAlignmentRight;
    [self.bottomBar addSubview:self.versionLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.bottomBar.topAnchor constraintEqualToAnchor:self.controlCard.bottomAnchor constant:kMargin],
        [self.bottomBar.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:kMargin],
        [self.bottomBar.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-kMargin],
        [self.bottomBar.heightAnchor constraintEqualToConstant:kBottomBarHeight],
        [self.bottomBar.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-kMargin],

        [self.muteButton.leadingAnchor constraintEqualToAnchor:self.bottomBar.leadingAnchor constant:kSmallMargin],
        [self.muteButton.centerYAnchor constraintEqualToAnchor:self.bottomBar.centerYAnchor],
        [self.muteButton.widthAnchor constraintEqualToConstant:80],
        [self.muteButton.heightAnchor constraintEqualToConstant:36],

        [self.statusDot.centerXAnchor constraintEqualToAnchor:self.bottomBar.centerXAnchor],
        [self.statusDot.centerYAnchor constraintEqualToAnchor:self.bottomBar.centerYAnchor],
        [self.statusDot.widthAnchor constraintEqualToConstant:10],
        [self.statusDot.heightAnchor constraintEqualToConstant:10],

        [self.versionLabel.trailingAnchor constraintEqualToAnchor:self.bottomBar.trailingAnchor constant:-kSmallMargin],
        [self.versionLabel.centerYAnchor constraintEqualToAnchor:self.bottomBar.centerYAnchor],
    ]];

    // Stagger views array
    self.staggerViews = [NSMutableArray arrayWithObjects:
                         self.headerView, self.configCard, self.controlCard, self.bottomBar, nil];
}

#pragma mark - Audio & Network

- (void)setupAudioAndNetwork {
    self.audioCapture = [[MicYouAudioCapture alloc] init];
    self.audioCapture.delegate = self;

    self.transportClient = [[TransportClient alloc] init];
    self.transportClient.delegate = self;
}

- (void)loadSavedSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *savedHost = [defaults objectForKey:@"micyou_host"];
    NSInteger savedPort = [defaults integerForKey:@"micyou_port"];

    if (savedHost.length > 0) {
        self.hostTextField.text = savedHost;
    }
    if (savedPort > 0) {
        self.portTextField.text = [NSString stringWithFormat:@"%ld", (long)savedPort];
    } else {
        self.portTextField.text = @"8900";
    }
}

#pragma mark - Actions

- (void)headerSettingsTapped:(UIButton *)sender {
    [self openSettings];
}

- (void)modeButtonTapped:(UIButton *)sender {
    if (sender == self.wifiModeButton) {
        self.isWiFiMode = YES;
        self.wifiModeButton.selected = YES;
        self.usbModeButton.selected = NO;
    } else {
        self.isWiFiMode = NO;
        self.wifiModeButton.selected = NO;
        self.usbModeButton.selected = YES;
    }
    [self updateModeButtonStyles];
}

- (void)mainActionButtonTapped:(UIButton *)sender {
    [MicYouAnimator animateButtonPress:sender];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [MicYouAnimator animateButtonRelease:sender];
    });

    if (self.isConnected || self.isStreaming) {
        [self disconnect];
    } else {
        [self connect];
    }
}

- (void)muteButtonTapped:(UIButton *)sender {
    self.isMuted = !self.isMuted;

    if (self.isMuted) {
        [self.muteButton setTitle:NSLocalizedString(@"button_unmute", nil) forState:UIControlStateNormal];
        self.muteButton.backgroundColor = [MicYouColors shared].error;
    } else {
        [self.muteButton setTitle:NSLocalizedString(@"button_mute", nil) forState:UIControlStateNormal];
        [self applyMuteButtonStyle];
    }

    [MicYouAnimator animateButtonPress:sender];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [MicYouAnimator animateButtonRelease:sender];
    });
}

- (void)connect {
    NSString *host = self.hostTextField.text;
    NSString *portStr = self.portTextField.text;
    NSInteger port = [portStr integerValue];
    if (port == 0) port = 8900;

    if (!host || host.length == 0) {
        self.statusTextLabel.text = NSLocalizedString(@"network_config_first", nil);
        [self shakeView:self.configCard];
        return;
    }

    // Update status
    self.statusTextLabel.text = NSLocalizedString(@"status_connecting", nil);
    [self updateStatusIconForState:@"connecting"];

    // Animate button to connecting state
    [UIView animateWithDuration:0.3 animations:^{
        self.mainActionButton.backgroundColor = [MicYouColors shared].tertiary;
        [self.mainActionButton setTitle:@"" forState:UIControlStateNormal];
    }];

    // Show activity indicator
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    if (@available(iOS 13.0, *)) {
        spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    }
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    spinner.tag = 999;
    [self.mainActionButton addSubview:spinner];
    [NSLayoutConstraint activateConstraints:@[
        [spinner.centerXAnchor constraintEqualToAnchor:self.mainActionButton.centerXAnchor],
        [spinner.centerYAnchor constraintEqualToAnchor:self.mainActionButton.centerYAnchor],
    ]];
    [spinner startAnimating];

    // Save settings
    [self saveCurrentSettings];

    __weak typeof(self) weakSelf = self;
    [self.transportClient connectToHost:host port:(int)port completion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Remove spinner
            UIView *spinnerView = [weakSelf.mainActionButton viewWithTag:999];
            [spinnerView removeFromSuperview];

            if (success) {
                weakSelf.isConnected = YES;
                weakSelf.isStreaming = YES;

                // Update UI
                weakSelf.statusTextLabel.text = NSLocalizedString(@"status_connected", nil);
                [weakSelf updateStatusIconForState:@"connected"];
                weakSelf.liveBadge.hidden = NO;
                weakSelf.ipLabel.text = [NSString stringWithFormat:NSLocalizedString(@"host_label_format", nil), host, (long)port];

                // Button to disconnect state
                weakSelf.mainActionButton.backgroundColor = [MicYouColors shared].error;
                [weakSelf.mainActionButton setTitle:NSLocalizedString(@"button_disconnect", nil) forState:UIControlStateNormal];

                // Glow on
                weakSelf.mainActionGlowView.hidden = NO;
                weakSelf.mainActionGlowView.backgroundColor = [[MicYouColors shared].error colorWithAlphaComponent:0.3];
                [MicYouAnimator animatePulse:weakSelf.mainActionGlowView duration:1.5];

                // Start capture
                [weakSelf.audioCapture startCapture];

                // Keep screen awake
                [UIApplication sharedApplication].idleTimerDisabled = YES;

                // Status dot
                weakSelf.statusDot.backgroundColor = [MicYouColors shared].error;
                [MicYouAnimator animatePulse:weakSelf.statusDot duration:0.8];

            } else {
                weakSelf.statusTextLabel.text = NSLocalizedString(@"status_connection_failed", nil);
                [weakSelf updateStatusIconForState:@"disconnected"];
                [UIView animateWithDuration:0.3 animations:^{
                    weakSelf.mainActionButton.backgroundColor = [MicYouColors shared].primary;
                    [weakSelf.mainActionButton setTitle:NSLocalizedString(@"button_connect", nil) forState:UIControlStateNormal];
                }];
            }
        });
    }];
}

- (void)disconnect {
    [self.audioCapture stopCapture];
    [self.transportClient disconnect];

    self.isConnected = NO;
    self.isStreaming = NO;

    self.statusTextLabel.text = NSLocalizedString(@"status_not_connected", nil);
    [self updateStatusIconForState:@"disconnected"];
    self.liveBadge.hidden = YES;
    self.ipLabel.text = NSLocalizedString(@"host_not_configured", nil);

    self.mainActionGlowView.hidden = YES;
    [self.mainActionGlowView.layer removeAllAnimations];

    [self.statusDot.layer removeAllAnimations];
    self.statusDot.backgroundColor = [MicYouColors shared].outline;

    [UIView animateWithDuration:0.3 animations:^{
        self.mainActionButton.backgroundColor = [MicYouColors shared].primary;
        [self.mainActionButton setTitle:NSLocalizedString(@"button_connect", nil) forState:UIControlStateNormal];
    }];

    [UIApplication sharedApplication].idleTimerDisabled = NO;

    [self updateAudioLevel:0.0];
}

- (void)openSettings {
    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)saveCurrentSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:self.hostTextField.text forKey:@"micyou_host"];
    [defaults setInteger:[self.portTextField.text integerValue] forKey:@"micyou_port"];
    [defaults synchronize];
}

#pragma mark - Audio Level Visualization

- (void)updateAudioLevel:(float)level {
    CFTimeInterval now = CACurrentMediaTime();
    if (now - self.lastLevelUpdateTime < kAudioLevelUpdateInterval) return;
    self.lastLevelUpdateTime = now;

    CGFloat clamped = MAX(0.0f, MIN(1.0f, level));

    for (NSInteger i = 0; i < self.visualizerBars.count; i++) {
        UIView *bar = self.visualizerBars[i];

        // Randomized multipliers for organic-looking visualizer
        CGFloat randomFactor = 0.3 + ((CGFloat)arc4random_uniform(71) / 100.0); // 0.3 - 1.0
        CGFloat barLevel = clamped * randomFactor;
        CGFloat height = MAX(3.0, barLevel * 28.0);

        CABasicAnimation *heightAnim = [CABasicAnimation animationWithKeyPath:@"bounds.size.height"];
        heightAnim.fromValue = @(bar.layer.bounds.size.height);
        heightAnim.toValue = @(height);
        heightAnim.duration = 0.08;
        heightAnim.fillMode = kCAFillModeForwards;
        heightAnim.removedOnCompletion = NO;
        [bar.layer addAnimation:heightAnim forKey:@"vizHeight"];

        CGRect bounds = bar.layer.bounds;
        bounds.size.height = height;
        bar.layer.bounds = bounds;
    }
}

#pragma mark - Status Icon Management

- (void)updateStatusIconForState:(NSString *)state {
    if (@available(iOS 13.0, *)) {
        if ([state isEqualToString:@"connected"]) {
            self.statusIconView.image = [UIImage systemImageNamed:@"mic.fill"];
            self.statusIconView.tintColor = [MicYouColors shared].primary;
        } else if ([state isEqualToString:@"connecting"]) {
            self.statusIconView.image = [UIImage systemImageNamed:@"mic.badge.plus"];
            self.statusIconView.tintColor = [MicYouColors shared].tertiary;
        } else {
            self.statusIconView.image = [UIImage systemImageNamed:@"mic.slash.fill"];
            self.statusIconView.tintColor = [MicYouColors shared].onSurfaceVariant;
        }
    } else {
        // iOS <13 fallback
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(48, 48), NO, 0);
        if ([state isEqualToString:@"connected"]) {
            self.statusIconView.image = [self textToImage:@"🎤" size:CGSizeMake(48, 48)];
        } else if ([state isEqualToString:@"connecting"]) {
            self.statusIconView.image = [self textToImage:@"🎤🔗" size:CGSizeMake(48, 48)];
        } else {
            self.statusIconView.image = [self textToImage:@"🎤❌" size:CGSizeMake(48, 48)];
        }
        UIGraphicsEndImageContext();
        self.statusIconView.tintColor = [MicYouColors shared].onSurfaceVariant;
    }
}

#pragma mark - Color Scheme & Theme

- (void)updateColorSchemeFromTrait {
    if (@available(iOS 13.0, *)) {
        MicYouColors *colors = [MicYouColors shared];
        if (colors.colorScheme != MicYouColorSchemeOLED) {
            if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                colors.colorScheme = MicYouColorSchemeDark;
            } else {
                colors.colorScheme = MicYouColorSchemeLight;
            }
            [UIView animateWithDuration:0.3 animations:^{
                [self applyColors];
            }];
        }
    }
}

- (void)applyColors {
    MicYouColors *c = [MicYouColors shared];

    self.view.backgroundColor = c.background;

    // Header
    self.titleLabel.textColor = c.primary;
    self.ipLabel.textColor = c.onSurfaceVariant;
    self.headerSettingsButton.tintColor = c.onSurfaceVariant;

    // Config card
    self.configCard.backgroundColor = c.surfaceBright;
    self.configCard.layer.shadowColor = c.onSurface.CGColor;
    self.configCard.layer.shadowOpacity = (c.colorScheme == MicYouColorSchemeLight) ? 0.08 : 0;
    self.configCard.layer.shadowOffset = CGSizeMake(0, 2);
    self.configCard.layer.shadowRadius = 12;

    [self updateModeButtonStyles];

    // Text fields
    UIColor *textFieldBg = c.surfaceVariant;
    self.hostTextField.backgroundColor = textFieldBg;
    self.hostTextField.textColor = c.onSurface;
    self.hostTextField.layer.borderColor = c.outlineVariant.CGColor;
    self.portTextField.backgroundColor = textFieldBg;
    self.portTextField.textColor = c.onSurface;
    self.portTextField.layer.borderColor = c.outlineVariant.CGColor;

    // Control card
    self.controlCard.backgroundColor = c.surfaceBright;
    self.controlCard.layer.shadowColor = c.onSurface.CGColor;
    self.controlCard.layer.shadowOpacity = (c.colorScheme == MicYouColorSchemeLight) ? 0.08 : 0;
    self.controlCard.layer.shadowOffset = CGSizeMake(0, 2);
    self.controlCard.layer.shadowRadius = 12;

    self.statusTextLabel.textColor = c.onSurface;
    self.visualizerView.backgroundColor = c.surfaceVariant;

    // Visualizer bars
    for (UIView *bar in self.visualizerBars) {
        bar.backgroundColor = c.primary;
    }

    // Main action button (preserve state-dependent color)
    if (!self.isConnected && !self.isStreaming) {
        self.mainActionButton.backgroundColor = c.primary;
    }

    // Glow
    if (self.isStreaming) {
        self.mainActionGlowView.backgroundColor = [c.error colorWithAlphaComponent:0.3];
    }

    // Bottom bar
    self.bottomBar.backgroundColor = [UIColor clearColor];
    [self applyMuteButtonStyle];

    if (!self.isStreaming) {
        self.statusDot.backgroundColor = c.outline;
    }

    self.versionLabel.textColor = c.outline;

    // Cards shadow - only in light mode
    if (c.colorScheme == MicYouColorSchemeLight) {
        self.configCard.layer.shadowOpacity = 0.08;
        self.controlCard.layer.shadowOpacity = 0.08;
    } else {
        self.configCard.layer.shadowOpacity = 0;
        self.controlCard.layer.shadowOpacity = 0;
    }
}

- (void)applyMuteButtonStyle {
    if (self.isMuted) {
        self.muteButton.backgroundColor = [MicYouColors shared].error;
        [self.muteButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        self.muteButton.backgroundColor = [MicYouColors shared].surfaceVariant;
        [self.muteButton setTitleColor:[MicYouColors shared].onSurfaceVariant forState:UIControlStateNormal];
    }
}

#pragma mark - TransportClientDelegate

- (void)transportClientDidConnect:(TransportClient *)client {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isConnected = YES;
        self.isStreaming = YES;

        NSString *host = client.host;
        int port = client.port;
        self.hostTextField.text = host;
        self.portTextField.text = [NSString stringWithFormat:@"%d", port];
        self.ipLabel.text = [NSString stringWithFormat:NSLocalizedString(@"host_label_format", nil), host, (long)port];

        self.statusTextLabel.text = NSLocalizedString(@"status_connected", nil);
        [self updateStatusIconForState:@"connected"];
        self.liveBadge.hidden = NO;

        self.mainActionGlowView.hidden = NO;
        self.mainActionGlowView.backgroundColor = [[MicYouColors shared].error colorWithAlphaComponent:0.3];
        [MicYouAnimator animatePulse:self.mainActionGlowView duration:1.5];
    });
}

- (void)transportClientDidDisconnect:(TransportClient *)client {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.audioCapture stopCapture];
        self.isConnected = NO;
        self.isStreaming = NO;

        self.statusTextLabel.text = NSLocalizedString(@"status_disconnected", nil);
        [self updateStatusIconForState:@"disconnected"];
        self.liveBadge.hidden = YES;

        self.mainActionGlowView.hidden = YES;
        [self.mainActionGlowView.layer removeAllAnimations];

        [self.statusDot.layer removeAllAnimations];
        self.statusDot.backgroundColor = [MicYouColors shared].outline;

        [UIView animateWithDuration:0.3 animations:^{
            self.mainActionButton.backgroundColor = [MicYouColors shared].primary;
            [self.mainActionButton setTitle:NSLocalizedString(@"button_connect", nil) forState:UIControlStateNormal];
        }];

        [UIApplication sharedApplication].idleTimerDisabled = NO;
        [self updateAudioLevel:0.0];
    });
}

- (void)transportClient:(TransportClient *)client didReceiveData:(NSData *)data {
    // Handle incoming control/data messages if needed
}

- (void)transportClient:(TransportClient *)client didReceiveError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"error_connection_failed", nil), error.localizedDescription];
    });
}

#pragma mark - MicYouAudioCaptureDelegate

- (void)audioCapture:(MicYouAudioCapture *)capture didCaptureBuffer:(NSData *)buffer timestamp:(uint64_t)timestamp {
    if (!self.isConnected || self.isMuted) return;
    [self.transportClient sendAudioData:buffer timestamp:timestamp];
}

- (void)audioCapture:(MicYouAudioCapture *)capture didUpdateLevel:(float)level {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateAudioLevel:level];
    });
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    [self saveCurrentSettings];
}

#pragma mark - Helpers

- (UIButton *)createModeButton:(NSString *)title {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:title forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    btn.layer.cornerRadius = kPillHeight / 2.0;
    btn.clipsToBounds = YES;
    return btn;
}

- (UITextField *)createTextFieldWithPlaceholder:(NSString *)placeholder
                                    keyboardType:(UIKeyboardType)type {
    UITextField *field = [[UITextField alloc] init];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.placeholder = placeholder;
    field.keyboardType = type;
    field.returnKeyType = UIReturnKeyDone;
    field.delegate = self;
    field.borderStyle = UITextBorderStyleNone; // Use rounded rect mimic
    field.layer.cornerRadius = kPillHeight / 2.0;
    field.layer.borderWidth = 1.0;
    field.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];

    // Left padding view
    UIView *leftPad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, kPillHeight)];
    field.leftView = leftPad;
    field.leftViewMode = UITextFieldViewModeAlways;

    // Right padding
    UIView *rightPad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, kPillHeight)];
    field.rightView = rightPad;
    field.rightViewMode = UITextFieldViewModeAlways;

    return field;
}

- (void)updateModeButtonStyles {
    MicYouColors *c = [MicYouColors shared];

    if (self.isWiFiMode) {
        self.wifiModeButton.backgroundColor = c.primary;
        [self.wifiModeButton setTitleColor:c.onPrimary forState:UIControlStateNormal];
        self.usbModeButton.backgroundColor = c.surfaceVariant;
        [self.usbModeButton setTitleColor:c.onSurfaceVariant forState:UIControlStateNormal];
    } else {
        self.usbModeButton.backgroundColor = c.primary;
        [self.usbModeButton setTitleColor:c.onPrimary forState:UIControlStateNormal];
        self.wifiModeButton.backgroundColor = c.surfaceVariant;
        [self.wifiModeButton setTitleColor:c.onSurfaceVariant forState:UIControlStateNormal];
    }
}

- (void)shakeView:(UIView *)view {
    CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    shake.values = @[@(-8), @(8), @(-6), @(6), @(-3), @(3), @(0)];
    shake.duration = 0.4;
    [view.layer addAnimation:shake forKey:@"shake"];
}

- (UIImage *)textToImage:(NSString *)text size:(CGSize)size {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = [UIFont systemFontOfSize:size.height * 0.7];
    label.textAlignment = NSTextAlignmentCenter;
    label.frame = CGRectMake(0, 0, size.width * 2, size.height);
    label.textColor = [UIColor darkGrayColor];

    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    [label.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

#pragma mark - Dealloc

- (void)dealloc {
    [self.audioCapture stopCapture];
    [self.transportClient disconnect];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
}

@end