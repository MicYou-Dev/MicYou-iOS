#import "MicYouViewController.h"
#import "MicYouAnimator.h"
#import "MicYouLogger.h"
#import "MicYouColors.h"
#import "SettingsViewController.h"
#import "MicYouVisualizerView.h"
#import "MicYouNotificationManager.h"
#import "MicYouServiceDiscovery.h"
#import "MicYouUpdateChecker.h"
#import <arpa/inet.h>
#import <sys/socket.h>

#pragma mark - Settings Transition

@interface MicYouSettingsTransition : NSObject <UIViewControllerTransitioningDelegate, UIViewControllerAnimatedTransitioning>
@property (nonatomic, assign) BOOL presenting; // YES=present, NO=dismiss
@end

@implementation MicYouSettingsTransition

#pragma mark - UIViewControllerTransitioningDelegate

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented
                                                                   presentingController:(UIViewController *)presenting
                                                                       sourceController:(UIViewController *)source {
    self.presenting = YES;
    return self;
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed {
    self.presenting = NO;
    return self;
}

#pragma mark - UIViewControllerAnimatedTransitioning

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext {
    return self.presenting ? 0.36 : 0.30;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    UIViewController *toVC = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIViewController *fromVC = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIView *containerView = transitionContext.containerView;
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;

    if (self.presenting) {
        toVC.view.frame = CGRectMake(screenWidth, 0, screenWidth, toVC.view.bounds.size.height);
        toVC.view.alpha = 0.0;
        [containerView addSubview:toVC.view];

        [UIView animateWithDuration:0.36
                              delay:0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            toVC.view.frame = CGRectMake(0, 0, screenWidth, toVC.view.bounds.size.height);
            toVC.view.alpha = 1.0;
        } completion:^(BOOL finished) {
            [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
        }];
    } else {
        [UIView animateWithDuration:0.30
                              delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            fromVC.view.frame = CGRectMake(screenWidth, 0, screenWidth, fromVC.view.bounds.size.height);
            fromVC.view.alpha = 0.0;
        } completion:^(BOOL finished) {
            [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
        }];
    }
}

@end

// Audio level update throttle interval (PRESERVED)
static const CFTimeInterval kAudioLevelUpdateInterval = 0.05;

// Four-card layout constants (NEW)
static const CGFloat kMargin = 12.0;            // outer margin
static const CGFloat kCardSpacing = 10.0;       // between cards
static const CGFloat kCornerRadiusSmall = 20.0; // header / connection / bottomBar
static const CGFloat kCornerRadiusLarge = 28.0; // control card
static const CGFloat kFabDiameterIdle = 80.0;
static const CGFloat kFabDiameterStreaming = 100.0;
static const CGFloat kVisualizerSize = 240.0;
static const CGFloat kConnectingAnimationSize = 200.0;

@interface MicYouViewController () <UITextFieldDelegate, MicYouServiceDiscoveryDelegate>

// === Core services (PRESERVED — DO NOT MODIFY) ===
@property (nonatomic, strong) MicYouAudioCapture *audioCapture;
@property (nonatomic, strong) TransportClient *transportClient;
@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, assign) BOOL isStreaming;
@property (nonatomic, assign) BOOL isMuted;

// === Four-card layout (NEW) ===
@property (nonatomic, strong) UIView *headerCard;
@property (nonatomic, strong) UIView *connectionCard;
@property (nonatomic, strong) UIView *controlCard;
@property (nonatomic, strong) UIView *bottomBarCard;

// Header card content
@property (nonatomic, strong) UIView *appIconContainer;
@property (nonatomic, strong) UIImageView *appIconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *ipLabel;
@property (nonatomic, strong) UIButton *settingsButton;

// Connection card content
@property (nonatomic, strong) UILabel *availableServersLabel;
@property (nonatomic, strong) UIButton *refreshButton;
@property (nonatomic, strong) UIStackView *deviceListStack;
@property (nonatomic, strong) UITextField *hostTextField;
@property (nonatomic, strong) UITextField *portTextField;

// Control card content
@property (nonatomic, strong) UIView *statusIconContainer;
@property (nonatomic, strong) UIImageView *statusIconView;
@property (nonatomic, strong) UILabel *statusTextLabel;
@property (nonatomic, strong) UIView *liveBadge;
@property (nonatomic, strong) UILabel *liveBadgeLabel;
@property (nonatomic, strong) MicYouVisualizerView *visualizerView;
@property (nonatomic, strong) UIView *connectingAnimationView;
@property (nonatomic, strong) UIActivityIndicatorView *connectingSpinner;
@property (nonatomic, strong) UIView *errorMessageContainer;
@property (nonatomic, strong) UILabel *errorMessageLabel;
@property (nonatomic, strong) UIView *mainActionGlowView;
@property (nonatomic, strong) UIButton *mainActionButton;
@property (nonatomic, strong) NSLayoutConstraint *fabWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *fabHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *glowWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *glowHeightConstraint;

// Bottom bar content
@property (nonatomic, strong) UIButton *muteButton;
@property (nonatomic, strong) UIView *statusDot;

// State (PRESERVED + NEW)
@property (nonatomic, assign) MicYouStreamState streamState;
@property (nonatomic, assign) CFTimeInterval lastLevelUpdateTime;
@property (nonatomic, assign) BOOL hasAppeared;

// Settings custom transition (NEW)
@property (nonatomic, strong) MicYouSettingsTransition *settingsTransition;

// === Service discovery (NEW) ===
@property (nonatomic, strong) NSMutableArray<NSNetService *> *discoveredServices;
@property (nonatomic, assign) BOOL isScanningDiscovery;

// === Background image (NEW) ===
@property (nonatomic, strong) UIImageView *backgroundImageView;
@property (nonatomic, strong) UIView *backgroundOverlayView;

// === Update check (NEW) ===
@property (nonatomic, assign) BOOL hasCheckedForUpdate;

@end

@implementation MicYouViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"MicYou";
    self.isMuted = NO;
    self.streamState = MicYouStreamStateIdle;
    self.discoveredServices = [[NSMutableArray alloc] init];

    // Apply saved color scheme before building UI
    [self applySavedColorScheme];

    self.view.backgroundColor = [MicYouColors shared].surfaceContainer;

    // Four-card layout (bottomBarCard is allocated before controlCard
    // because controlCard's bottom anchors to bottomBarCard.topAnchor).
    [self setupHeaderCard];
    [self setupConnectionCard];
    [self setupBottomBarCard];
    [self setupControlCard];
    [self setupAudioAndNetwork];
    [self applyColors];
    [self loadSavedSettings];
    [self updateStreamState:MicYouStreamStateIdle];

    // Wire service discovery
    [MicYouServiceDiscovery shared].delegate = self;

    // Load background image (if configured)
    [self refreshBackgroundImage];

    // Listen for settings changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(settingsDidChange:)
                                                 name:@"MicYouSettingsDidChange"
                                               object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (!self.hasAppeared) {
        self.hasAppeared = YES;
        [MicYouAnimator animateStaggeredFadeUp:@[self.headerCard,
                                                  self.connectionCard,
                                                  self.controlCard,
                                                  self.bottomBarCard]
                                        delays:@[@0.05, @0.15, @0.25, @0.35]];

        // Request notification authorization when streaming notifications are enabled
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults boolForKey:@"micyou_enable_streaming_notification"]) {
            [[MicYouNotificationManager shared] requestAuthorizationWithCompletion:^(BOOL granted) {}];
        }

        // Auto-check for updates on first appear
        [self autoCheckUpdateIfNeeded];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];

    if (@available(iOS 13.0, *)) {
        if (self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle) {
            [self updateColorSchemeFromTrait];
        }
    }
}

#pragma mark - Header Card

- (void)setupHeaderCard {
    self.headerCard = [[UIView alloc] init];
    self.headerCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerCard.layer.cornerRadius = kCornerRadiusSmall;
    self.headerCard.layer.masksToBounds = YES;
    [self.view addSubview:self.headerCard];

    // 36x36 icon container, 12pt corner radius, primaryContainer bg, 20pt mic icon
    self.appIconContainer = [[UIView alloc] init];
    self.appIconContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.appIconContainer.layer.cornerRadius = 12.0;
    self.appIconContainer.layer.masksToBounds = YES;
    self.appIconContainer.backgroundColor = [MicYouColors shared].primaryContainer;
    [self.headerCard addSubview:self.appIconContainer];

    self.appIconView = [[UIImageView alloc] init];
    self.appIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.appIconView.contentMode = UIViewContentModeScaleAspectFit;
    self.appIconView.tintColor = [MicYouColors shared].onPrimaryContainer;
    if (@available(iOS 13.0, *)) {
        self.appIconView.image = [UIImage systemImageNamed:@"mic.fill"];
    }
    [self.appIconContainer addSubview:self.appIconView];

    // "MicYou" 14pt ExtraBold (Heavy) primary
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.text = @"MicYou";
    self.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
    self.titleLabel.textColor = [MicYouColors shared].primary;
    [self.headerCard addSubview:self.titleLabel];

    // "IP: xxx" 11pt onSurfaceVariant
    self.ipLabel = [[UILabel alloc] init];
    self.ipLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.ipLabel.text = NSLocalizedString(@"host_not_configured", nil);
    self.ipLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    self.ipLabel.textColor = [MicYouColors shared].onSurfaceVariant;
    self.ipLabel.numberOfLines = 1;
    self.ipLabel.adjustsFontSizeToFitWidth = YES;
    [self.headerCard addSubview:self.ipLabel];

    // 32x32 gear settings button
    self.settingsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.settingsButton.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        UIImage *gearImage = [UIImage systemImageNamed:@"gearshape"];
        [self.settingsButton setImage:gearImage forState:UIControlStateNormal];
    } else {
        [self.settingsButton setTitle:@"\u2699" forState:UIControlStateNormal];
        self.settingsButton.titleLabel.font = [UIFont systemFontOfSize:20];
    }
    self.settingsButton.tintColor = [MicYouColors shared].onSurfaceVariant;
    [self.settingsButton addTarget:self
                            action:@selector(headerSettingsTapped:)
                  forControlEvents:UIControlEventTouchUpInside];
    [self.headerCard addSubview:self.settingsButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.headerCard.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:kMargin],
        [self.headerCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kMargin],
        [self.headerCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kMargin],

        // icon container: leading 16, top 12
        [self.appIconContainer.leadingAnchor constraintEqualToAnchor:self.headerCard.leadingAnchor constant:16.0],
        [self.appIconContainer.topAnchor constraintEqualToAnchor:self.headerCard.topAnchor constant:12.0],
        [self.appIconContainer.widthAnchor constraintEqualToConstant:36.0],
        [self.appIconContainer.heightAnchor constraintEqualToConstant:36.0],

        [self.appIconView.centerXAnchor constraintEqualToAnchor:self.appIconContainer.centerXAnchor],
        [self.appIconView.centerYAnchor constraintEqualToAnchor:self.appIconContainer.centerYAnchor],
        [self.appIconView.widthAnchor constraintEqualToConstant:20.0],
        [self.appIconView.heightAnchor constraintEqualToConstant:20.0],

        // title: 12pt right of icon, top aligned with icon container
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.appIconContainer.trailingAnchor constant:12.0],
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.appIconContainer.topAnchor],

        // ipLabel: 4pt below title
        [self.ipLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.ipLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:4.0],
        // Bottom padding (12pt) sizes the card height
        [self.ipLabel.bottomAnchor constraintEqualToAnchor:self.headerCard.bottomAnchor constant:-12.0],

        // settings button: trailing 16, vertically centered
        [self.settingsButton.trailingAnchor constraintEqualToAnchor:self.headerCard.trailingAnchor constant:-16.0],
        [self.settingsButton.centerYAnchor constraintEqualToAnchor:self.headerCard.centerYAnchor],
        [self.settingsButton.widthAnchor constraintEqualToConstant:32.0],
        [self.settingsButton.heightAnchor constraintEqualToConstant:32.0],
    ]];

    // "MicYou" title color animation: primary → tertiary, 4s, autoreverses
    [self startTitleColorAnimation];
}

- (void)startTitleColorAnimation {
    [self cycleTitleColorForward:YES];
}

- (void)cycleTitleColorForward:(BOOL)forward {
    UIColor *target = forward ? [MicYouColors shared].tertiary : [MicYouColors shared].primary;
    [UIView animateWithDuration:4.0
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self.titleLabel.textColor = target;
    }
                     completion:^(BOOL finished) {
        if (finished) {
            [self cycleTitleColorForward:!forward];
        }
    }];
}

#pragma mark - Connection Card

- (void)setupConnectionCard {
    self.connectionCard = [[UIView alloc] init];
    self.connectionCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.connectionCard.layer.cornerRadius = kCornerRadiusSmall;
    self.connectionCard.layer.masksToBounds = YES;
    [self.view addSubview:self.connectionCard];

    // "Available servers" labelSmall + 32x32 refresh button
    self.availableServersLabel = [[UILabel alloc] init];
    self.availableServersLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.availableServersLabel.text = NSLocalizedString(@"available_servers_label", nil);
    self.availableServersLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    self.availableServersLabel.textColor = [MicYouColors shared].onSurfaceVariant;
    [self.connectionCard addSubview:self.availableServersLabel];

    self.refreshButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        UIImage *refreshImage = [UIImage systemImageNamed:@"arrow.clockwise"];
        [self.refreshButton setImage:refreshImage forState:UIControlStateNormal];
    } else {
        [self.refreshButton setTitle:@"\u27F3" forState:UIControlStateNormal];
        self.refreshButton.titleLabel.font = [UIFont systemFontOfSize:18];
    }
    self.refreshButton.tintColor = [MicYouColors shared].onSurfaceVariant;
    [self.refreshButton addTarget:self
                           action:@selector(refreshButtonTapped:)
                 forControlEvents:UIControlEventTouchUpInside];
    [self.connectionCard addSubview:self.refreshButton];

    // Device list (UIStackView vertical, spacing=4)
    self.deviceListStack = [[UIStackView alloc] init];
    self.deviceListStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.deviceListStack.axis = UILayoutConstraintAxisVertical;
    self.deviceListStack.spacing = 4.0;
    self.deviceListStack.alignment = UIStackViewAlignmentFill;
    [self.connectionCard addSubview:self.deviceListStack];

    [self rebuildDeviceList];

    // Host + Port text fields (preserved properties)
    self.hostTextField = [self createTextFieldWithPlaceholder:NSLocalizedString(@"network_host_label", nil)
                                                keyboardType:UIKeyboardTypeURL];
    self.portTextField = [self createTextFieldWithPlaceholder:NSLocalizedString(@"network_port_label", nil)
                                                keyboardType:UIKeyboardTypeNumberPad];
    [self.connectionCard addSubview:self.hostTextField];
    [self.connectionCard addSubview:self.portTextField];

    [NSLayoutConstraint activateConstraints:@[
        [self.connectionCard.topAnchor constraintEqualToAnchor:self.headerCard.bottomAnchor constant:kCardSpacing],
        [self.connectionCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kMargin],
        [self.connectionCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kMargin],

        // Section header row: label leading 12, refresh trailing 12
        [self.availableServersLabel.topAnchor constraintEqualToAnchor:self.connectionCard.topAnchor constant:12.0],
        [self.availableServersLabel.leadingAnchor constraintEqualToAnchor:self.connectionCard.leadingAnchor constant:12.0],

        [self.refreshButton.centerYAnchor constraintEqualToAnchor:self.availableServersLabel.centerYAnchor],
        [self.refreshButton.trailingAnchor constraintEqualToAnchor:self.connectionCard.trailingAnchor constant:-12.0],
        [self.refreshButton.widthAnchor constraintEqualToConstant:32.0],
        [self.refreshButton.heightAnchor constraintEqualToConstant:32.0],

        // Device list
        [self.deviceListStack.topAnchor constraintEqualToAnchor:self.availableServersLabel.bottomAnchor constant:8.0],
        [self.deviceListStack.leadingAnchor constraintEqualToAnchor:self.connectionCard.leadingAnchor constant:12.0],
        [self.deviceListStack.trailingAnchor constraintEqualToAnchor:self.connectionCard.trailingAnchor constant:-12.0],

        // Host + Port row (horizontal, spacing 10, port width 100)
        [self.hostTextField.topAnchor constraintEqualToAnchor:self.deviceListStack.bottomAnchor constant:12.0],
        [self.hostTextField.leadingAnchor constraintEqualToAnchor:self.connectionCard.leadingAnchor constant:12.0],
        [self.hostTextField.heightAnchor constraintEqualToConstant:40.0],

        [self.portTextField.leadingAnchor constraintEqualToAnchor:self.hostTextField.trailingAnchor constant:10.0],
        [self.portTextField.centerYAnchor constraintEqualToAnchor:self.hostTextField.centerYAnchor],
        [self.portTextField.widthAnchor constraintEqualToConstant:100.0],
        [self.portTextField.heightAnchor constraintEqualToConstant:40.0],
        [self.portTextField.trailingAnchor constraintEqualToAnchor:self.connectionCard.trailingAnchor constant:-12.0],

        // Bottom padding (12pt) sizes the card height
        [self.hostTextField.bottomAnchor constraintEqualToAnchor:self.connectionCard.bottomAnchor constant:-12.0],
    ]];
}

- (void)rebuildDeviceList {
    // Remove existing rows
    for (UIView *v in [self.deviceListStack.arrangedSubviews copy]) {
        [self.deviceListStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }

    // Add a row for each discovered service (tag = index + 1, used by deviceRowTapped:)
    NSArray<NSNetService *> *services = [self.discoveredServices copy];
    for (NSUInteger i = 0; i < services.count; i++) {
        NSNetService *service = services[i];
        NSString *host = [self hostStringFromService:service];
        NSString *displayName = service.name.length > 0 ? service.name : (host.length > 0 ? host : @"");
        NSString *rowTitle = displayName;
        if (host.length > 0) {
            rowTitle = [NSString stringWithFormat:@"%@  ·  %@:%ld", displayName, host, (long)service.port];
        }
        UIView *row = [self createDeviceRowWithName:rowTitle selected:NO];
        row.tag = (NSInteger)i + 1;
        [self.deviceListStack addArrangedSubview:row];
    }

    // Always show the "manual" row at the bottom (tag = 0)
    UIView *manualRow = [self createDeviceRowWithName:NSLocalizedString(@"manual_server_label", nil)
                                              selected:YES];
    manualRow.tag = 0;
    [self.deviceListStack addArrangedSubview:manualRow];
}

- (UIView *)createDeviceRowWithName:(NSString *)name selected:(BOOL)selected {
    MicYouColors *c = [MicYouColors shared];

    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    // 设计图 (main.html L262): 所有服务器行均使用 primaryContainer 背景，
    // 配合 onPrimaryContainer 文字色与 primary 图标色。无论是否选中。
    row.backgroundColor = c.primaryContainer;
    row.layer.cornerRadius = 12.0;
    row.layer.masksToBounds = YES;
    row.userInteractionEnabled = YES;

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    // 设计图 L263: 图标用 primary 色
    iconView.tintColor = c.primary;
    if (@available(iOS 13.0, *)) {
        iconView.image = [UIImage systemImageNamed:selected ? @"checkmark.circle.fill" : @"dns"];
    }
    [row addSubview:iconView];

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.text = name;
    nameLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    nameLabel.textColor = c.onPrimaryContainer;
    [row addSubview:nameLabel];

    [NSLayoutConstraint activateConstraints:@[
        [iconView.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:12.0],
        [iconView.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:18.0],
        [iconView.heightAnchor constraintEqualToConstant:18.0],

        [nameLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:8.0],
        [nameLabel.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [nameLabel.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12.0],

        [row.heightAnchor constraintEqualToConstant:36.0],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(deviceRowTapped:)];
    [row addGestureRecognizer:tap];

    return row;
}

- (void)deviceRowTapped:(UITapGestureRecognizer *)gesture {
    UIView *row = gesture.view;
    NSInteger tag = row.tag;

    // tag == 0 -> manual row, no-op (user types into the text fields)
    if (tag <= 0) {
        return;
    }

    NSUInteger index = (NSUInteger)tag - 1;
    if (index >= self.discoveredServices.count) {
        [[MicYouLogger sharedLogger] log:[NSString stringWithFormat:@"deviceRowTapped: index %lu out of range (count=%lu)",
            (unsigned long)index, (unsigned long)self.discoveredServices.count]];
        return;
    }

    NSNetService *service = self.discoveredServices[index];
    NSString *host = [self hostStringFromService:service];

    // host 为空时尝试用 service.name 作为 fallback（mDNS 解析可能延迟）
    if (host.length == 0 && service.name.length > 0) {
        host = service.name;
    }

    [[MicYouLogger sharedLogger] log:[NSString stringWithFormat:@"deviceRowTapped: service=%@ host=%@ port=%ld addresses=%lu",
        service.name, host, (long)service.port, (unsigned long)service.addresses.count]];

    if (host.length > 0) {
        self.hostTextField.text = host;
    }
    if (service.port > 0) {
        self.portTextField.text = [NSString stringWithFormat:@"%ld", (long)service.port];
    }

    [self saveCurrentSettings];
    [self rebuildDeviceList];
}

- (void)refreshButtonTapped:(UIButton *)sender {
    [MicYouAnimator animatePressScale:sender scale:0.85];

    // Trigger service discovery scan
    if (self.isScanningDiscovery) {
        return;
    }

    self.isScanningDiscovery = YES;
    [self.discoveredServices removeAllObjects];
    [self rebuildDeviceList];

    MicYouServiceDiscovery *discovery = [MicYouServiceDiscovery shared];
    discovery.delegate = self;
    [discovery startScanning];

    // Start refresh button rotation animation
    if (@available(iOS 13.0, *)) {
        CABasicAnimation *rotate = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
        rotate.fromValue = @(0);
        rotate.toValue = @(2 * M_PI);
        rotate.duration = 1.0;
        rotate.repeatCount = HUGE_VALF;
        [sender.imageView.layer addAnimation:rotate forKey:@"micyou_refresh_rotate"];
    }
}

#pragma mark - Control Card

- (void)setupControlCard {
    self.controlCard = [[UIView alloc] init];
    self.controlCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.controlCard.layer.cornerRadius = kCornerRadiusLarge;
    self.controlCard.layer.masksToBounds = YES;
    [self.view addSubview:self.controlCard];

    // Status icon container: 40x40, 20pt corner, top=24, centered
    self.statusIconContainer = [[UIView alloc] init];
    self.statusIconContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusIconContainer.layer.cornerRadius = 20.0;
    self.statusIconContainer.layer.masksToBounds = YES;
    [self.controlCard addSubview:self.statusIconContainer];

    self.statusIconView = [[UIImageView alloc] init];
    self.statusIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusIconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.statusIconContainer addSubview:self.statusIconView];

    // Status text label
    self.statusTextLabel = [[UILabel alloc] init];
    self.statusTextLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusTextLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.statusTextLabel.textColor = [MicYouColors shared].onSurface;
    self.statusTextLabel.textAlignment = NSTextAlignmentCenter;
    [self.controlCard addSubview:self.statusTextLabel];

    // LIVE badge: extraSmall corner radius (4pt), primary bg, white 11pt Bold
    self.liveBadge = [[UIView alloc] init];
    self.liveBadge.translatesAutoresizingMaskIntoConstraints = NO;
    self.liveBadge.backgroundColor = [MicYouColors shared].primary;
    self.liveBadge.layer.cornerRadius = 4.0;
    self.liveBadge.layer.masksToBounds = YES;
    self.liveBadge.hidden = YES;
    [self.controlCard addSubview:self.liveBadge];

    self.liveBadgeLabel = [[UILabel alloc] init];
    self.liveBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.liveBadgeLabel.text = NSLocalizedString(@"live_badge", nil);
    self.liveBadgeLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    self.liveBadgeLabel.textColor = [UIColor whiteColor];
    self.liveBadgeLabel.textAlignment = NSTextAlignmentCenter;
    [self.liveBadge addSubview:self.liveBadgeLabel];

    // Visualizer (240x240, behind FAB)
    self.visualizerView = [[MicYouVisualizerView alloc] init];
    self.visualizerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.visualizerView.backgroundColor = [UIColor clearColor];
    [self.controlCard addSubview:self.visualizerView];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger savedStyle = [defaults integerForKey:@"micyou_visualizer_style"];
    self.visualizerView.style = (MicYouVisualizerStyle)savedStyle;
    self.visualizerView.visualizerColor = [MicYouColors shared].primary;

    // Connecting animation (200x200, behind FAB)
    self.connectingAnimationView = [[UIView alloc] init];
    self.connectingAnimationView.translatesAutoresizingMaskIntoConstraints = NO;
    self.connectingAnimationView.hidden = YES;
    [self.controlCard addSubview:self.connectingAnimationView];

    if (@available(iOS 13.0, *)) {
        self.connectingSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    } else {
        self.connectingSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    }
    self.connectingSpinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.connectingSpinner.color = [MicYouColors shared].tertiary;
    [self.connectingAnimationView addSubview:self.connectingSpinner];

    // Error message container
    self.errorMessageContainer = [[UIView alloc] init];
    self.errorMessageContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.errorMessageContainer.backgroundColor = [[MicYouColors shared].error colorWithAlphaComponent:0.1];
    self.errorMessageContainer.layer.cornerRadius = 12.0;
    self.errorMessageContainer.layer.masksToBounds = YES;
    self.errorMessageContainer.hidden = YES;
    [self.controlCard addSubview:self.errorMessageContainer];

    self.errorMessageLabel = [[UILabel alloc] init];
    self.errorMessageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.errorMessageLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    self.errorMessageLabel.textColor = [MicYouColors shared].error;
    self.errorMessageLabel.textAlignment = NSTextAlignmentCenter;
    self.errorMessageLabel.numberOfLines = 0;
    [self.errorMessageContainer addSubview:self.errorMessageLabel];

    // Glow view (behind FAB)
    self.mainActionGlowView = [[UIView alloc] init];
    self.mainActionGlowView.translatesAutoresizingMaskIntoConstraints = NO;
    self.mainActionGlowView.layer.cornerRadius = (kFabDiameterIdle + 20.0) / 2.0;
    self.mainActionGlowView.backgroundColor = [[MicYouColors shared].primary colorWithAlphaComponent:0.25];
    self.mainActionGlowView.userInteractionEnabled = NO;
    self.mainActionGlowView.hidden = YES;
    [self.controlCard addSubview:self.mainActionGlowView];

    // FAB
    self.mainActionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.mainActionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.mainActionButton.layer.cornerRadius = kFabDiameterIdle / 2.0;
    self.mainActionButton.layer.masksToBounds = YES;
    [self.mainActionButton setTitle:NSLocalizedString(@"button_connect", nil) forState:UIControlStateNormal];
    [self.mainActionButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.mainActionButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [self.mainActionButton addTarget:self
                              action:@selector(mainActionButtonTapped:)
                    forControlEvents:UIControlEventTouchUpInside];
    [self.controlCard addSubview:self.mainActionButton];

    self.fabWidthConstraint  = [self.mainActionButton.widthAnchor  constraintEqualToConstant:kFabDiameterIdle];
    self.fabHeightConstraint = [self.mainActionButton.heightAnchor constraintEqualToConstant:kFabDiameterIdle];
    self.glowWidthConstraint  = [self.mainActionGlowView.widthAnchor  constraintEqualToConstant:kFabDiameterIdle + 20.0];
    self.glowHeightConstraint = [self.mainActionGlowView.heightAnchor constraintEqualToConstant:kFabDiameterIdle + 20.0];

    [NSLayoutConstraint activateConstraints:@[
        // controlCard: top=connection.bottom+10, bottom=bottomBar.top-10 (flexible fill)
        [self.controlCard.topAnchor constraintEqualToAnchor:self.connectionCard.bottomAnchor constant:kCardSpacing],
        [self.controlCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kMargin],
        [self.controlCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kMargin],
        [self.controlCard.bottomAnchor constraintEqualToAnchor:self.bottomBarCard.topAnchor constant:-kCardSpacing],

        // Status icon container: 40x40, top=24, centered
        [self.statusIconContainer.topAnchor constraintEqualToAnchor:self.controlCard.topAnchor constant:24.0],
        [self.statusIconContainer.centerXAnchor constraintEqualToAnchor:self.controlCard.centerXAnchor],
        [self.statusIconContainer.widthAnchor constraintEqualToConstant:40.0],
        [self.statusIconContainer.heightAnchor constraintEqualToConstant:40.0],

        [self.statusIconView.centerXAnchor constraintEqualToAnchor:self.statusIconContainer.centerXAnchor],
        [self.statusIconView.centerYAnchor constraintEqualToAnchor:self.statusIconContainer.centerYAnchor],
        [self.statusIconView.widthAnchor constraintEqualToConstant:22.0],
        [self.statusIconView.heightAnchor constraintEqualToConstant:22.0],

        // Status text below icon container
        [self.statusTextLabel.topAnchor constraintEqualToAnchor:self.statusIconContainer.bottomAnchor constant:8.0],
        [self.statusTextLabel.centerXAnchor constraintEqualToAnchor:self.controlCard.centerXAnchor],
        [self.statusTextLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.controlCard.leadingAnchor constant:16.0],
        [self.statusTextLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.controlCard.trailingAnchor constant:-16.0],

        // LIVE badge: right of status text
        [self.liveBadge.centerYAnchor constraintEqualToAnchor:self.statusTextLabel.centerYAnchor],
        [self.liveBadge.leadingAnchor constraintEqualToAnchor:self.statusTextLabel.trailingAnchor constant:8.0],

        [self.liveBadgeLabel.leadingAnchor constraintEqualToAnchor:self.liveBadge.leadingAnchor constant:8.0],
        [self.liveBadgeLabel.trailingAnchor constraintEqualToAnchor:self.liveBadge.trailingAnchor constant:-8.0],
        [self.liveBadgeLabel.topAnchor constraintEqualToAnchor:self.liveBadge.topAnchor constant:2.0],
        [self.liveBadgeLabel.bottomAnchor constraintEqualToAnchor:self.liveBadge.bottomAnchor constant:-2.0],

        // Visualizer centered on FAB
        [self.visualizerView.centerXAnchor constraintEqualToAnchor:self.controlCard.centerXAnchor],
        [self.visualizerView.centerYAnchor constraintEqualToAnchor:self.mainActionButton.centerYAnchor],
        [self.visualizerView.widthAnchor constraintEqualToConstant:kVisualizerSize],
        [self.visualizerView.heightAnchor constraintEqualToConstant:kVisualizerSize],

        // Connecting animation centered on FAB
        [self.connectingAnimationView.centerXAnchor constraintEqualToAnchor:self.controlCard.centerXAnchor],
        [self.connectingAnimationView.centerYAnchor constraintEqualToAnchor:self.mainActionButton.centerYAnchor],
        [self.connectingAnimationView.widthAnchor constraintEqualToConstant:kConnectingAnimationSize],
        [self.connectingAnimationView.heightAnchor constraintEqualToConstant:kConnectingAnimationSize],

        [self.connectingSpinner.centerXAnchor constraintEqualToAnchor:self.connectingAnimationView.centerXAnchor],
        [self.connectingSpinner.centerYAnchor constraintEqualToAnchor:self.connectingAnimationView.centerYAnchor],

        // Error message container above FAB
        [self.errorMessageContainer.leadingAnchor constraintEqualToAnchor:self.controlCard.leadingAnchor constant:16.0],
        [self.errorMessageContainer.trailingAnchor constraintEqualToAnchor:self.controlCard.trailingAnchor constant:-16.0],
        [self.errorMessageContainer.bottomAnchor constraintEqualToAnchor:self.mainActionButton.topAnchor constant:-16.0],

        [self.errorMessageLabel.leadingAnchor constraintEqualToAnchor:self.errorMessageContainer.leadingAnchor constant:12.0],
        [self.errorMessageLabel.trailingAnchor constraintEqualToAnchor:self.errorMessageContainer.trailingAnchor constant:-12.0],
        [self.errorMessageLabel.topAnchor constraintEqualToAnchor:self.errorMessageContainer.topAnchor constant:10.0],
        [self.errorMessageLabel.bottomAnchor constraintEqualToAnchor:self.errorMessageContainer.bottomAnchor constant:-10.0],

        // Glow centered on FAB
        [self.mainActionGlowView.centerXAnchor constraintEqualToAnchor:self.mainActionButton.centerXAnchor],
        [self.mainActionGlowView.centerYAnchor constraintEqualToAnchor:self.mainActionButton.centerYAnchor],
        self.glowWidthConstraint,
        self.glowHeightConstraint,

        // FAB horizontally + vertically centered in controlCard.
        // Visualizer (240x240) and Glow are centered on FAB.centerY, so they
        // stay centered too. controlCard is given enough vertical room by the
        // flexible top/bottom anchors (connection.bottom+10 -> bottomBar.top-10)
        // so the 240pt visualizer does not breach the card bounds.
        [self.mainActionButton.centerXAnchor constraintEqualToAnchor:self.controlCard.centerXAnchor],
        [self.mainActionButton.centerYAnchor constraintEqualToAnchor:self.controlCard.centerYAnchor],
        self.fabWidthConstraint,
        self.fabHeightConstraint,
    ]];
}

#pragma mark - Stream State Machine

- (void)updateStreamState:(MicYouStreamState)state {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStreamState:state];
        });
        return;
    }

    self.streamState = state;
    MicYouColors *c = [MicYouColors shared];

    NSString *iconName = nil;
    NSString *fallbackText = nil;
    UIColor *iconContainerBg = nil;
    UIColor *iconTintColor = nil;
    UIColor *fabColor = nil;
    CGFloat fabSize = kFabDiameterIdle;
    NSString *statusText = nil;
    NSString *fabTitle = nil;
    BOOL showLiveBadge = NO;
    BOOL showGlow = NO;
    BOOL showConnecting = NO;
    BOOL showError = NO;
    BOOL showVisualizer = NO;
    UIColor *statusDotColor = nil;
    BOOL pulseStatusDot = NO;

    switch (state) {
        case MicYouStreamStateIdle:
            iconName = @"info.circle.fill";
            fallbackText = @"i";
            iconContainerBg = [[c onSurfaceVariant] colorWithAlphaComponent:0.12];
            iconTintColor = c.onSurfaceVariant;
            fabColor = c.primary;
            fabSize = kFabDiameterIdle;
            statusText = NSLocalizedString(@"status_not_connected", nil);
            fabTitle = NSLocalizedString(@"button_connect", nil);
            statusDotColor = [[c onSurfaceVariant] colorWithAlphaComponent:0.3];
            break;
        case MicYouStreamStateConnecting:
            iconName = @"hourglass";
            fallbackText = @"\u23F3";
            iconContainerBg = [[c tertiary] colorWithAlphaComponent:0.12];
            iconTintColor = c.tertiary;
            fabColor = c.tertiary;
            fabSize = kFabDiameterIdle;
            statusText = NSLocalizedString(@"status_connecting", nil);
            fabTitle = @"";
            showConnecting = YES;
            statusDotColor = c.tertiary;
            break;
        case MicYouStreamStateStreaming:
            iconName = @"checkmark.circle.fill";
            fallbackText = @"\u2713";
            iconContainerBg = [[c primary] colorWithAlphaComponent:0.12];
            iconTintColor = c.primary;
            fabColor = c.error;
            fabSize = kFabDiameterStreaming;
            statusText = NSLocalizedString(@"status_connected", nil);
            fabTitle = NSLocalizedString(@"button_disconnect", nil);
            showLiveBadge = YES;
            showGlow = YES;
            showVisualizer = YES;
            statusDotColor = c.primary;
            pulseStatusDot = YES;
            break;
        case MicYouStreamStateError:
            iconName = @"xmark.circle.fill";
            fallbackText = @"\u2715";
            iconContainerBg = [[c error] colorWithAlphaComponent:0.12];
            iconTintColor = c.error;
            fabColor = c.primary;
            fabSize = kFabDiameterIdle;
            statusText = NSLocalizedString(@"status_connection_failed", nil);
            fabTitle = NSLocalizedString(@"button_connect", nil);
            showError = YES;
            statusDotColor = c.error;
            break;
    }

    // Status icon
    if (@available(iOS 13.0, *)) {
        self.statusIconView.image = [UIImage systemImageNamed:iconName];
    } else {
        self.statusIconView.image = [self textToImage:fallbackText size:CGSizeMake(24, 24)];
    }
    self.statusIconView.tintColor = iconTintColor;
    self.statusIconContainer.backgroundColor = iconContainerBg;

    // Status text
    self.statusTextLabel.text = statusText;

    // LIVE badge
    self.liveBadge.hidden = !showLiveBadge;

    // Connecting animation
    self.connectingAnimationView.hidden = !showConnecting;
    if (showConnecting) {
        [self.connectingSpinner startAnimating];
    } else {
        [self.connectingSpinner stopAnimating];
    }

    // Error container
    self.errorMessageContainer.hidden = !showError;

    // Visualizer visibility (hidden when not streaming)
    self.visualizerView.hidden = !showVisualizer;

    // Status dot
    [self.statusDot.layer removeAllAnimations];
    self.statusDot.backgroundColor = statusDotColor;
    if (pulseStatusDot) {
        [MicYouAnimator animatePulse:self.statusDot duration:1.2];
    }

    // Glow
    [self.mainActionGlowView.layer removeAllAnimations];
    if (showGlow) {
        self.mainActionGlowView.hidden = NO;
        self.mainActionGlowView.backgroundColor = [c.error colorWithAlphaComponent:0.5];
        [MicYouAnimator animateGlowPulse:self.mainActionGlowView
                              fromAlpha:0.3
                                toAlpha:0.7
                               duration:1.5];
    } else {
        self.mainActionGlowView.hidden = YES;
    }

    // FAB color transition (400ms)
    [UIView animateWithDuration:0.4 animations:^{
        self.mainActionButton.backgroundColor = fabColor;
    }];

    // FAB size transition (spring)
    self.fabWidthConstraint.constant = fabSize;
    self.fabHeightConstraint.constant = fabSize;
    CGFloat glowSize = fabSize + 20.0;
    self.glowWidthConstraint.constant = glowSize;
    self.glowHeightConstraint.constant = glowSize;

    [MicYouAnimator animateSpringWithDuration:0.5
                                         delay:0
                                       damping:0.6
                               initialVelocity:0.3
                                    animations:^{
        self.mainActionButton.layer.cornerRadius = fabSize / 2.0;
        self.mainActionGlowView.layer.cornerRadius = glowSize / 2.0;
        [self.controlCard layoutIfNeeded];
    }
                                    completion:nil];

    // FAB title
    [self.mainActionButton setTitle:fabTitle forState:UIControlStateNormal];
    [self.mainActionButton setImage:nil forState:UIControlStateNormal];
    self.mainActionButton.tintColor = [UIColor whiteColor];
}

#pragma mark - Audio & Network (PRESERVED)

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

- (void)saveCurrentSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:self.hostTextField.text forKey:@"micyou_host"];
    [defaults setInteger:[self.portTextField.text integerValue] forKey:@"micyou_port"];
    [defaults synchronize];
}

#pragma mark - Actions

- (void)headerSettingsTapped:(UIButton *)sender {
    [MicYouAnimator animatePressScale:sender scale:0.85];
    [self openSettings];
}

- (void)mainActionButtonTapped:(UIButton *)sender {
    [MicYouAnimator animatePressScale:sender scale:0.88];

    if (self.isConnected || self.isStreaming) {
        [self disconnect];
    } else {
        [self connect];
    }
}

- (void)muteButtonTapped:(UIButton *)sender {
    self.isMuted = !self.isMuted;
    [self applyMuteButtonStyle];
    [MicYouAnimator animatePressScale:sender scale:0.9];
}

- (void)connect {
    NSString *host = self.hostTextField.text;
    NSString *portStr = self.portTextField.text;
    NSInteger port = [portStr integerValue];
    if (port == 0) port = 8900;

    if (!host || host.length == 0) {
        self.statusTextLabel.text = NSLocalizedString(@"network_config_first", nil);
        [self shakeView:self.connectionCard];
        return;
    }

    // Switch UI to Connecting state
    [self updateStreamState:MicYouStreamStateConnecting];

    // Save settings
    [self saveCurrentSettings];

    __weak typeof(self) weakSelf = self;
    [self.transportClient connectToHost:host port:(int)port completion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            if (success) {
                strongSelf.isConnected = YES;
                strongSelf.isStreaming = YES;
                strongSelf.ipLabel.text = [NSString stringWithFormat:NSLocalizedString(@"host_label_format", nil),
                                           host, (long)port];
                [strongSelf updateStreamState:MicYouStreamStateStreaming];

                // Start capture
                [strongSelf.audioCapture startCapture];

                // Keep screen awake
                [UIApplication sharedApplication].idleTimerDisabled = YES;
            } else {
                strongSelf.isConnected = NO;
                strongSelf.isStreaming = NO;
                strongSelf.errorMessageLabel.text = NSLocalizedString(@"status_connection_failed", nil);
                [strongSelf updateStreamState:MicYouStreamStateError];
            }
        });
    }];
}

- (void)disconnect {
    [self.audioCapture stopCapture];
    [self.transportClient disconnect];

    self.isConnected = NO;
    self.isStreaming = NO;

    self.ipLabel.text = NSLocalizedString(@"host_not_configured", nil);
    [self updateStreamState:MicYouStreamStateIdle];

    [UIApplication sharedApplication].idleTimerDisabled = NO;

    [self updateAudioLevel:0.0];
}

- (void)openSettings {
    if (!self.settingsTransition) {
        self.settingsTransition = [[MicYouSettingsTransition alloc] init];
    }
    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    nav.transitioningDelegate = self.settingsTransition;
    nav.modalPresentationStyle = UIModalPresentationCustom;
    [self presentViewController:nav animated:YES completion:nil];
}

#pragma mark - Audio Level Visualization (PRESERVED)

- (void)updateAudioLevel:(float)level {
    CFTimeInterval now = CACurrentMediaTime();
    if (now - self.lastLevelUpdateTime < kAudioLevelUpdateInterval) return;
    self.lastLevelUpdateTime = now;

    CGFloat clamped = MAX(0.0f, MIN(1.0f, level));
    [self.visualizerView updateWithLevel:clamped];
}

#pragma mark - Color Scheme & Theme (PRESERVED)

- (void)applySavedColorScheme {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger darkModeValue = [defaults integerForKey:@"micyou_dark_mode"];
    BOOL useOLED = [defaults boolForKey:@"micyou_oled_black"];
    NSInteger seedIndex = [defaults integerForKey:@"micyou_seed_color_index"];

    MicYouColors *colors = [MicYouColors shared];

    NSArray<UIColor *> *presetColors = [MicYouColors presetColors];
    if (seedIndex >= 0 && seedIndex < (NSInteger)presetColors.count) {
        colors.seedColor = presetColors[seedIndex];
    }

    if (@available(iOS 13.0, *)) {
        if (darkModeValue == 0) {
            // Auto
            if (useOLED && self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                colors.colorScheme = MicYouColorSchemeOLED;
            } else if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                colors.colorScheme = MicYouColorSchemeDark;
            } else {
                colors.colorScheme = MicYouColorSchemeLight;
            }
        } else if (darkModeValue == 1) {
            // Light (新语义: 1=亮)
            colors.colorScheme = MicYouColorSchemeLight;
        } else {
            // Dark (新语义: 2=暗)
            colors.colorScheme = useOLED ? MicYouColorSchemeOLED : MicYouColorSchemeDark;
        }
    } else {
        // iOS <13: no dark mode support
        colors.colorScheme = MicYouColorSchemeLight;
    }
}

- (void)settingsDidChange:(NSNotification *)notification {
    [self applySavedColorScheme];

    // Refresh background image when its path changes
    NSString *changedKey = notification.userInfo[@"key"];
    if ([changedKey isEqualToString:@"micyou_background_image_path"]) {
        [self refreshBackgroundImage];
    }

    // Update visualizer style if changed
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger savedStyle = [defaults integerForKey:@"micyou_visualizer_style"];
    if (self.visualizerView.style != savedStyle) {
        self.visualizerView.style = (MicYouVisualizerStyle)savedStyle;
    }

    [UIView animateWithDuration:0.3 animations:^{
        [self applyColors];
    }];

    // Refresh state-dependent colors
    [self updateStreamState:self.streamState];
}

- (void)updateColorSchemeFromTrait {
    if (@available(iOS 13.0, *)) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSInteger darkModeValue = [defaults integerForKey:@"micyou_dark_mode"];

        // Only auto-switch if user set "Auto" (0)
        if (darkModeValue != 0) return;

        MicYouColors *colors = [MicYouColors shared];
        BOOL useOLED = [defaults boolForKey:@"micyou_oled_black"];

        if (useOLED && self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            colors.colorScheme = MicYouColorSchemeOLED;
        } else if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            colors.colorScheme = MicYouColorSchemeDark;
        } else {
            colors.colorScheme = MicYouColorSchemeLight;
        }

        [UIView animateWithDuration:0.3 animations:^{
            [self applyColors];
        }];

        [self updateStreamState:self.streamState];
    }
}

- (void)applyColors {
    MicYouColors *c = [MicYouColors shared];

    self.view.backgroundColor = c.surfaceContainer;

    // Header card
    self.headerCard.backgroundColor = c.surfaceBright;
    self.appIconContainer.backgroundColor = c.primaryContainer;
    self.appIconView.tintColor = c.onPrimaryContainer;
    self.titleLabel.textColor = c.primary;
    self.ipLabel.textColor = c.onSurfaceVariant;
    self.settingsButton.tintColor = c.onSurfaceVariant;

    // Connection card
    self.connectionCard.backgroundColor = c.surfaceBright;
    self.availableServersLabel.textColor = c.onSurfaceVariant;
    self.refreshButton.tintColor = c.onSurfaceVariant;

    // Rebuild device list rows so they pick up new colors
    [self rebuildDeviceList];

    // Text fields
    UIColor *textFieldBg = c.surfaceContainerHighest;
    self.hostTextField.backgroundColor = textFieldBg;
    self.hostTextField.textColor = c.onSurface;
    self.hostTextField.layer.borderColor = c.outlineVariant.CGColor;
    self.hostTextField.tintColor = c.primary;

    self.portTextField.backgroundColor = textFieldBg;
    self.portTextField.textColor = c.onSurface;
    self.portTextField.layer.borderColor = c.outlineVariant.CGColor;
    self.portTextField.tintColor = c.primary;

    // Control card
    self.controlCard.backgroundColor = c.surfaceBright;
    self.statusTextLabel.textColor = c.onSurface;
    self.visualizerView.backgroundColor = [UIColor clearColor];
    self.visualizerView.visualizerColor = c.primary;
    self.errorMessageLabel.textColor = c.error;
    self.errorMessageContainer.backgroundColor = [c.error colorWithAlphaComponent:0.1];
    self.connectingSpinner.color = c.tertiary;

    // LIVE badge
    self.liveBadge.backgroundColor = c.primary;
    self.liveBadgeLabel.textColor = [UIColor whiteColor];

    // Bottom bar
    self.bottomBarCard.backgroundColor = c.surfaceBright;
    [self applyMuteButtonStyle];
}

- (void)applyMuteButtonStyle {
    MicYouColors *c = [MicYouColors shared];
    if (self.isMuted) {
        self.muteButton.backgroundColor = c.errorContainer;
        [self.muteButton setTitleColor:c.onErrorContainer forState:UIControlStateNormal];
        self.muteButton.tintColor = c.onErrorContainer;
        [self.muteButton setTitle:NSLocalizedString(@"button_unmute", nil) forState:UIControlStateNormal];
        if (@available(iOS 13.0, *)) {
            UIImage *img = [UIImage systemImageNamed:@"mic.slash.fill"];
            [self.muteButton setImage:img forState:UIControlStateNormal];
        }
    } else {
        self.muteButton.backgroundColor = c.surfaceContainerHighest;
        [self.muteButton setTitleColor:c.onSurfaceVariant forState:UIControlStateNormal];
        self.muteButton.tintColor = c.onSurfaceVariant;
        [self.muteButton setTitle:NSLocalizedString(@"button_mute", nil) forState:UIControlStateNormal];
        if (@available(iOS 13.0, *)) {
            UIImage *img = [UIImage systemImageNamed:@"mic.fill"];
            [self.muteButton setImage:img forState:UIControlStateNormal];
        }
    }
    // 18pt icon + 12pt spacing + title
    CGFloat spacing = 6.0;
    self.muteButton.imageEdgeInsets = UIEdgeInsetsMake(0, -spacing / 2, 0, spacing / 2);
    self.muteButton.titleEdgeInsets = UIEdgeInsetsMake(0, spacing / 2, 0, -spacing / 2);
}

#pragma mark - Bottom Bar Card

- (void)setupBottomBarCard {
    self.bottomBarCard = [[UIView alloc] init];
    self.bottomBarCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomBarCard.layer.cornerRadius = kCornerRadiusSmall;
    self.bottomBarCard.layer.masksToBounds = YES;
    [self.view addSubview:self.bottomBarCard];

    // Mute button: 12pt corner, surfaceContainerHighest bg, 18pt mic icon + "静音" text
    // h-pad=14 v-pad=10, press 0.9
    self.muteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.muteButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.muteButton.contentEdgeInsets = UIEdgeInsetsMake(10, 14, 10, 14);
    self.muteButton.layer.cornerRadius = 12.0;
    self.muteButton.layer.masksToBounds = YES;
    self.muteButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [self.muteButton addTarget:self
                        action:@selector(muteButtonTapped:)
              forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBarCard addSubview:self.muteButton];

    [self applyMuteButtonStyle];

    // Status dot: 8pt circle
    self.statusDot = [[UIView alloc] init];
    self.statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusDot.layer.cornerRadius = 4.0;
    self.statusDot.backgroundColor = [[MicYouColors shared].onSurfaceVariant colorWithAlphaComponent:0.3];
    [self.bottomBarCard addSubview:self.statusDot];

    [NSLayoutConstraint activateConstraints:@[
        [self.bottomBarCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kMargin],
        [self.bottomBarCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kMargin],
        [self.bottomBarCard.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-kMargin],

        // Mute button: leading 8, top/bottom 8
        [self.muteButton.leadingAnchor constraintEqualToAnchor:self.bottomBarCard.leadingAnchor constant:8.0],
        [self.muteButton.topAnchor constraintEqualToAnchor:self.bottomBarCard.topAnchor constant:8.0],
        [self.muteButton.bottomAnchor constraintEqualToAnchor:self.bottomBarCard.bottomAnchor constant:-8.0],

        // Status dot: trailing 16, centered
        [self.statusDot.trailingAnchor constraintEqualToAnchor:self.bottomBarCard.trailingAnchor constant:-16.0],
        [self.statusDot.centerYAnchor constraintEqualToAnchor:self.bottomBarCard.centerYAnchor],
        [self.statusDot.widthAnchor constraintEqualToConstant:8.0],
        [self.statusDot.heightAnchor constraintEqualToConstant:8.0],
    ]];
}

#pragma mark - TransportClientDelegate (PRESERVED)

- (void)transportClientDidConnect:(TransportClient *)client {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isConnected = YES;
        self.isStreaming = YES;

        NSString *host = client.host;
        int port = client.port;
        self.hostTextField.text = host;
        self.portTextField.text = [NSString stringWithFormat:@"%d", port];
        self.ipLabel.text = [NSString stringWithFormat:NSLocalizedString(@"host_label_format", nil), host, (long)port];

        [self updateStreamState:MicYouStreamStateStreaming];

        if (!self.audioCapture.isCapturing) {
            [self.audioCapture startCapture];
        }

        [UIApplication sharedApplication].idleTimerDisabled = YES;

        // Streaming notification
        [self sendStreamingNotificationConnectedWithHost:host port:port];
    });
}

- (void)transportClientDidDisconnect:(TransportClient *)client {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.audioCapture stopCapture];
        self.isConnected = NO;
        self.isStreaming = NO;

        [self updateStreamState:MicYouStreamStateIdle];

        [UIApplication sharedApplication].idleTimerDisabled = NO;
        [self updateAudioLevel:0.0];

        // Streaming notification
        [self sendStreamingNotificationDisconnected];
    });
}

- (void)transportClient:(TransportClient *)client didReceiveData:(NSData *)data {
    // Handle incoming control/data messages if needed
}

- (void)transportClient:(TransportClient *)client didReceiveError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.errorMessageLabel.text = [NSString stringWithFormat:NSLocalizedString(@"error_connection_failed", nil),
                                       error.localizedDescription];
        [self updateStreamState:MicYouStreamStateError];
    });
}

#pragma mark - MicYouServiceDiscoveryDelegate

- (void)serviceDiscovery:(MicYouServiceDiscovery *)discovery didFindService:(NSNetService *)service {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![self.discoveredServices containsObject:service]) {
            [self.discoveredServices addObject:service];
        }
        [self rebuildDeviceList];
    });
}

- (void)serviceDiscovery:(MicYouServiceDiscovery *)discovery didLoseService:(NSNetService *)service {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.discoveredServices removeObject:service];
        [self rebuildDeviceList];
    });
}

- (void)serviceDiscoveryDidStopScanning:(MicYouServiceDiscovery *)discovery {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isScanningDiscovery = NO;
        [self.refreshButton.imageView.layer removeAnimationForKey:@"micyou_refresh_rotate"];
    });
}

#pragma mark - MicYouAudioCaptureDelegate (PRESERVED)

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

- (UITextField *)createTextFieldWithPlaceholder:(NSString *)placeholder
                                    keyboardType:(UIKeyboardType)type {
    UITextField *field = [[UITextField alloc] init];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.placeholder = placeholder;
    field.keyboardType = type;
    field.returnKeyType = UIReturnKeyDone;
    field.delegate = self;
    field.borderStyle = UITextBorderStyleNone;
    field.layer.cornerRadius = 8.0;
    field.layer.borderWidth = 1.0;
    field.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];

    UIView *leftPad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 40)];
    field.leftView = leftPad;
    field.leftViewMode = UITextFieldViewModeAlways;

    UIView *rightPad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 40)];
    field.rightView = rightPad;
    field.rightViewMode = UITextFieldViewModeAlways;

    return field;
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

#pragma mark - Service Discovery Helpers

- (NSString *)hostStringFromService:(NSNetService *)service {
    if (!service) {
        return @"";
    }

    // Prefer IPv4 address from resolved addresses (matches Android hostAddress behavior)
    NSArray<NSData *> *addresses = service.addresses;
    if (addresses.count > 0) {
        for (NSData *data in addresses) {
            const struct sockaddr *sock = (const struct sockaddr *)data.bytes;
            if (sock && sock->sa_family == AF_INET) {
                const struct sockaddr_in *sockIn = (const struct sockaddr_in *)sock;
                char ipBuf[INET_ADDRSTRLEN];
                if (inet_ntop(AF_INET, &sockIn->sin_addr, ipBuf, sizeof(ipBuf))) {
                    return [NSString stringWithUTF8String:ipBuf];
                }
            }
        }
        // IPv6 fallback
        for (NSData *data in addresses) {
            const struct sockaddr *sock = (const struct sockaddr *)data.bytes;
            if (sock && sock->sa_family == AF_INET6) {
                const struct sockaddr_in6 *sockIn6 = (const struct sockaddr_in6 *)sock;
                char ipBuf[INET6_ADDRSTRLEN];
                if (inet_ntop(AF_INET6, &sockIn6->sin6_addr, ipBuf, sizeof(ipBuf))) {
                    return [NSString stringWithUTF8String:ipBuf];
                }
            }
        }
    }

    // Fall back to hostName (typically a .local mDNS hostname), trim trailing dot
    NSString *host = service.hostName;
    if (host.length > 0) {
        if ([host hasSuffix:@"."]) {
            host = [host substringToIndex:host.length - 1];
        }
        return host;
    }

    return @"";
}

#pragma mark - Streaming Notifications

- (void)sendStreamingNotificationConnectedWithHost:(NSString *)host port:(int)port {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:@"micyou_enable_streaming_notification"]) {
        return;
    }

    NSString *title = NSLocalizedStringWithDefaultValue(@"notification_connected_title",
                                                        nil, [NSBundle mainBundle],
                                                        @"已连接", @"Connected notification title");
    NSString *bodyFormat = NSLocalizedStringWithDefaultValue(@"notification_connected_body",
                                                             nil, [NSBundle mainBundle],
                                                             @"麦克风已就绪", @"Connected notification body");
    NSString *body = bodyFormat;
    if (host.length > 0) {
        body = [NSString stringWithFormat:@"%@  %@:%d", bodyFormat, host, port];
    }

    [[MicYouNotificationManager shared] sendNotificationWithTitle:title
                                                             body:body
                                                       identifier:@"micyou_connected"];
}

- (void)sendStreamingNotificationDisconnected {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:@"micyou_enable_streaming_notification"]) {
        return;
    }

    NSString *title = NSLocalizedStringWithDefaultValue(@"notification_disconnected_title",
                                                        nil, [NSBundle mainBundle],
                                                        @"已断开", @"Disconnected notification title");
    NSString *body = NSLocalizedStringWithDefaultValue(@"notification_disconnected_body",
                                                       nil, [NSBundle mainBundle],
                                                       @"麦克风已断开", @"Disconnected notification body");

    [[MicYouNotificationManager shared] sendNotificationWithTitle:title
                                                             body:body
                                                       identifier:@"micyou_disconnected"];
}

#pragma mark - Background Image

- (void)refreshBackgroundImage {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *path = [defaults stringForKey:@"micyou_background_image_path"];

    if (path.length == 0) {
        self.backgroundImageView.hidden = YES;
        self.backgroundOverlayView.hidden = YES;
        return;
    }

    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        self.backgroundImageView.hidden = YES;
        self.backgroundOverlayView.hidden = YES;
        return;
    }

    UIImage *image = [UIImage imageWithContentsOfFile:path];
    if (!image) {
        self.backgroundImageView.hidden = YES;
        self.backgroundOverlayView.hidden = YES;
        return;
    }

    // Lazily create background image view and overlay on first use
    if (!self.backgroundImageView) {
        self.backgroundImageView = [[UIImageView alloc] init];
        self.backgroundImageView.translatesAutoresizingMaskIntoConstraints = NO;
        self.backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.backgroundImageView.clipsToBounds = YES;
        [self.view insertSubview:self.backgroundImageView atIndex:0];

        self.backgroundOverlayView = [[UIView alloc] init];
        self.backgroundOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
        self.backgroundOverlayView.backgroundColor = [UIColor blackColor];
        self.backgroundOverlayView.alpha = 0.3;
        [self.view insertSubview:self.backgroundOverlayView aboveSubview:self.backgroundImageView];

        [NSLayoutConstraint activateConstraints:@[
            [self.backgroundImageView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
            [self.backgroundImageView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [self.backgroundImageView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [self.backgroundImageView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

            [self.backgroundOverlayView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
            [self.backgroundOverlayView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [self.backgroundOverlayView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [self.backgroundOverlayView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        ]];
    }

    self.backgroundImageView.image = image;
    self.backgroundImageView.hidden = NO;
    self.backgroundOverlayView.hidden = NO;
}

#pragma mark - Update Check

- (void)autoCheckUpdateIfNeeded {
    if (self.hasCheckedForUpdate) {
        return;
    }
    self.hasCheckedForUpdate = YES;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:@"micyou_auto_check_update"]) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    [[MicYouUpdateChecker shared] checkForUpdateWithCompletion:^(MicYouUpdateStatus status,
                                                                  NSString *latestVersion,
                                                                  NSURL *releaseURL) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        // Silent for up-to-date / error states — auto-check must not disturb the user
        if (status != MicYouUpdateStatusUpdateAvailable) {
            return;
        }

        NSString *title = NSLocalizedStringWithDefaultValue(@"update_available_title",
                                                            nil, [NSBundle mainBundle],
                                                            @"发现新版本", @"Update available alert title");
        NSString *messageFormat = NSLocalizedStringWithDefaultValue(@"update_available_message",
                                                                    nil, [NSBundle mainBundle],
                                                                    @"最新版本：%@", @"Update available alert message");
        NSString *message = [NSString stringWithFormat:messageFormat, latestVersion ?: @""];
        NSString *viewTitle = NSLocalizedStringWithDefaultValue(@"update_view_button",
                                                               nil, [NSBundle mainBundle],
                                                               @"查看", @"Update view button");
        NSString *laterTitle = NSLocalizedStringWithDefaultValue(@"update_later_button",
                                                                nil, [NSBundle mainBundle],
                                                                @"稍后", @"Update later button");

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:laterTitle style:UIAlertActionStyleCancel handler:nil]];
        __weak typeof(strongSelf) weakSelf2 = strongSelf;
        [alert addAction:[UIAlertAction actionWithTitle:viewTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            __strong typeof(weakSelf2) strongSelf2 = weakSelf2;
            if (strongSelf2 && releaseURL) {
                [[UIApplication sharedApplication] openURL:releaseURL options:@{} completionHandler:nil];
            }
        }]];

        [strongSelf presentViewController:alert animated:YES completion:nil];
    }];
}

#pragma mark - Dealloc

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.audioCapture stopCapture];
    [self.transportClient disconnect];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    // Clean up service discovery
    if ([MicYouServiceDiscovery shared].delegate == self) {
        [MicYouServiceDiscovery shared].delegate = nil;
    }
    [[MicYouServiceDiscovery shared] stopScanning];
}

@end
