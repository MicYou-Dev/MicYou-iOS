#import "MainViewController.h"
#import "SettingsViewController.h"
#import "MicYouAudioCapture.h"
#import "TransportClient.h"

@interface MainViewController () <MicYouAudioCaptureDelegate, TransportClientDelegate>

@property (nonatomic, strong) UIView *statusCard;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *audioLevelBar;
@property (nonatomic, strong) UIView *audioLevelContainer;
@property (nonatomic, strong) UIButton *connectButton;
@property (nonatomic, strong) UIButton *settingsButton;
@property (nonatomic, strong) UILabel *hostLabel;
@property (nonatomic, strong) UILabel *infoLabel;

@property (nonatomic, strong, readwrite) MicYouAudioCapture *audioCapture;
@property (nonatomic, strong, readwrite) TransportClient *transportClient;
@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, assign) CFTimeInterval lastLevelUpdateTime;

@property (nonatomic, assign) BOOL hasPerformedEntranceAnimation;

@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"MicYou";

    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor whiteColor];
    }

    [self setupUI];
    [self setupAudioAndNetwork];

    // Initial state for entrance animation
    NSArray<UIView *> *animatedViews = @[self.statusCard, self.connectButton, self.settingsButton, self.hostLabel, self.infoLabel];
    for (UIView *v in animatedViews) {
        v.alpha = 0.0;
        v.transform = CGAffineTransformMakeTranslation(0, 20);
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Refresh host label (may have changed in Settings)
    NSString *host = [[NSUserDefaults standardUserDefaults] objectForKey:@"micyou_host"];
    NSInteger port = [[NSUserDefaults standardUserDefaults] integerForKey:@"micyou_port"];
    if (port == 0) port = 8900;

    if (host && host.length > 0) {
        self.hostLabel.text = [NSString stringWithFormat:NSLocalizedString(@"host_format", nil), host, (long)port];
    } else {
        self.hostLabel.text = NSLocalizedString(@"host_not_configured", nil);
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (!self.hasPerformedEntranceAnimation) {
        self.hasPerformedEntranceAnimation = YES;
        [self performEntranceAnimation];
    }
}

- (void)performEntranceAnimation {
    NSArray<UIView *> *animViews = @[self.statusCard, self.connectButton, self.settingsButton, self.hostLabel, self.infoLabel];
    CGFloat delay = 0.0;
    for (UIView *view in animViews) {
        [UIView animateWithDuration:0.5
                              delay:delay
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:nil];
        delay += 0.08;
    }
}

- (void)setupUI {
    CGFloat margin = 20.0;
    UIColor *primaryColor = [UIColor systemBlueColor];

    // Status Card
    self.statusCard = [[UIView alloc] init];
    self.statusCard.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    self.statusCard.layer.cornerRadius = 16.0;
    self.statusCard.clipsToBounds = NO;
    self.statusCard.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusCard];

    // Card shadow (initial setup, will be updated in updateColorsForCurrentTheme)
    self.statusCard.layer.shadowOffset = CGSizeMake(0, 2);
    self.statusCard.layer.shadowRadius = 8;

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = NSLocalizedString(@"status_not_connected", nil);
    self.statusLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
    self.statusLabel.textColor = [UIColor blackColor];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.statusCard addSubview:self.statusLabel];

    self.audioLevelContainer = [[UIView alloc] init];
    self.audioLevelContainer.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    self.audioLevelContainer.layer.cornerRadius = 8.0;
    self.audioLevelContainer.clipsToBounds = YES;
    self.audioLevelContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.statusCard addSubview:self.audioLevelContainer];

    self.audioLevelBar = [[UIView alloc] init];
    self.audioLevelBar.backgroundColor = primaryColor;
    self.audioLevelBar.layer.cornerRadius = 8.0;
    self.audioLevelBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.audioLevelContainer addSubview:self.audioLevelBar];

    // Connect Button (pill shape)
    self.connectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.connectButton setTitle:NSLocalizedString(@"button_connect", nil) forState:UIControlStateNormal];
    [self.connectButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.connectButton.backgroundColor = primaryColor;
    self.connectButton.layer.cornerRadius = 28.0;
    self.connectButton.clipsToBounds = YES;
    self.connectButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    self.connectButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.connectButton addTarget:self action:@selector(toggleConnection:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.connectButton];

    self.settingsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.settingsButton setTitle:NSLocalizedString(@"button_settings", nil) forState:UIControlStateNormal];
    self.settingsButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.settingsButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.settingsButton addTarget:self action:@selector(openSettings:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.settingsButton];

    self.hostLabel = [[UILabel alloc] init];
    self.hostLabel.text = NSLocalizedString(@"host_not_configured", nil);
    self.hostLabel.font = [UIFont systemFontOfSize:14];
    self.hostLabel.textColor = [UIColor grayColor];
    self.hostLabel.textAlignment = NSTextAlignmentCenter;
    self.hostLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.hostLabel];

    self.infoLabel = [[UILabel alloc] init];
    self.infoLabel.text = NSLocalizedString(@"info_footer", nil);
    self.infoLabel.font = [UIFont systemFontOfSize:12];
    self.infoLabel.textColor = [UIColor lightGrayColor];
    self.infoLabel.textAlignment = NSTextAlignmentCenter;
    self.infoLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.infoLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.statusCard.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:margin * 2],
        [self.statusCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:margin],
        [self.statusCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-margin],
        [self.statusCard.heightAnchor constraintEqualToConstant:200],

        [self.statusLabel.topAnchor constraintEqualToAnchor:self.statusCard.topAnchor constant:24],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.statusCard.leadingAnchor constant:margin],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.statusCard.trailingAnchor constant:-margin],

        [self.audioLevelContainer.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:24],
        [self.audioLevelContainer.leadingAnchor constraintEqualToAnchor:self.statusCard.leadingAnchor constant:margin],
        [self.audioLevelContainer.trailingAnchor constraintEqualToAnchor:self.statusCard.trailingAnchor constant:-margin],
        [self.audioLevelContainer.heightAnchor constraintEqualToConstant:32],

        [self.audioLevelBar.leadingAnchor constraintEqualToAnchor:self.audioLevelContainer.leadingAnchor],
        [self.audioLevelBar.topAnchor constraintEqualToAnchor:self.audioLevelContainer.topAnchor],
        [self.audioLevelBar.bottomAnchor constraintEqualToAnchor:self.audioLevelContainer.bottomAnchor],
        [self.audioLevelBar.widthAnchor constraintEqualToAnchor:self.audioLevelContainer.widthAnchor multiplier:0.0],

        [self.connectButton.topAnchor constraintEqualToAnchor:self.statusCard.bottomAnchor constant:margin * 2],
        [self.connectButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.connectButton.widthAnchor constraintEqualToConstant:200],
        [self.connectButton.heightAnchor constraintEqualToConstant:56],

        [self.settingsButton.topAnchor constraintEqualToAnchor:self.connectButton.bottomAnchor constant:margin],
        [self.settingsButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],

        [self.hostLabel.topAnchor constraintEqualToAnchor:self.settingsButton.bottomAnchor constant:margin],
        [self.hostLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:margin],
        [self.hostLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-margin],

        [self.infoLabel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-margin],
        [self.infoLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:margin],
        [self.infoLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-margin]
    ]];

    // Apply initial theme colors
    [self updateColorsForCurrentTheme];
}

- (void)setupAudioAndNetwork {
    self.audioCapture = [[MicYouAudioCapture alloc] init];
    self.audioCapture.delegate = self;
    [self applyNoiseSuppressionSettingsToCapture];

    self.transportClient = [[TransportClient alloc] init];
    self.transportClient.delegate = self;
}

/// Read noise suppression preferences from NSUserDefaults and apply them to
/// the audio capture. Settings are applied at startCapture time, so changes
/// take effect on the next connection.
- (void)applyNoiseSuppressionSettingsToCapture {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.audioCapture.noiseSuppressionEnabled  = [defaults boolForKey:@"micyou_noise_suppression_enabled"];
    self.audioCapture.noiseSuppressionType     = (MicYouNoiseSuppressionType)[defaults integerForKey:@"micyou_noise_suppression_type"];
    float storedIntensity = [defaults floatForKey:@"micyou_noise_suppression_intensity"];
    self.audioCapture.noiseSuppressionIntensity = (storedIntensity > 0.0f) ? storedIntensity : 70.0f;
}

#pragma mark - Theme / Dark Mode Support

- (void)updateColorsForCurrentTheme {
    UIColor *bgColor;
    UIColor *cardBgColor;
    UIColor *textColor;
    UIColor *secondaryTextColor;
    BOOL isDark = NO;

    if (@available(iOS 13.0, *)) {
        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            isDark = YES;
            bgColor = [UIColor colorWithWhite:0.05 alpha:1.0];
            cardBgColor = [UIColor colorWithWhite:0.12 alpha:1.0];
            textColor = [UIColor whiteColor];
            secondaryTextColor = [UIColor colorWithWhite:0.7 alpha:1.0];
        } else {
            bgColor = [UIColor whiteColor];
            cardBgColor = [UIColor colorWithWhite:0.95 alpha:1.0];
            textColor = [UIColor blackColor];
            secondaryTextColor = [UIColor grayColor];
        }
    } else {
        bgColor = [UIColor whiteColor];
        cardBgColor = [UIColor colorWithWhite:0.95 alpha:1.0];
        textColor = [UIColor blackColor];
        secondaryTextColor = [UIColor grayColor];
    }

    self.view.backgroundColor = bgColor;
    self.statusCard.backgroundColor = cardBgColor;
    self.statusLabel.textColor = textColor;
    self.hostLabel.textColor = secondaryTextColor;
    self.infoLabel.textColor = [UIColor lightGrayColor];

    if (isDark) {
        self.audioLevelContainer.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    } else {
        self.audioLevelContainer.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    }

    // Card shadow: only in light mode
    if (!isDark) {
        self.statusCard.layer.shadowColor = [UIColor blackColor].CGColor;
        self.statusCard.layer.shadowOpacity = 0.1;
    } else {
        self.statusCard.layer.shadowOpacity = 0.0;
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];

    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self updateColorsForCurrentTheme];
        }
    }
}

#pragma mark - Connection

- (void)toggleConnection:(UIButton *)sender {
    if (self.isConnected) {
        [self disconnect];
    } else {
        [self connect];
    }
}

- (void)connect {
    NSString *host = [[NSUserDefaults standardUserDefaults] objectForKey:@"micyou_host"];
    NSInteger port = [[NSUserDefaults standardUserDefaults] integerForKey:@"micyou_port"];
    if (port == 0) port = 8900;

    if (!host || host.length == 0) {
        [self updateConnectionStatus:NSLocalizedString(@"alert_configure_host_first", nil)];
        return;
    }

    self.hostLabel.text = [NSString stringWithFormat:NSLocalizedString(@"host_format", nil), host, (long)port];

    // Keep screen awake while connected
    [UIApplication sharedApplication].idleTimerDisabled = YES;

    __weak typeof(self) weakSelf = self;
    [self.transportClient connectToHost:host port:(int)port completion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                weakSelf.isConnected = YES;
                [weakSelf.connectButton setTitle:NSLocalizedString(@"button_disconnect", nil) forState:UIControlStateNormal];
                [weakSelf updateConnectionStatus:NSLocalizedString(@"status_connected", nil)];
                [weakSelf.audioCapture startCapture];
            } else {
                [weakSelf updateConnectionStatus:NSLocalizedString(@"status_connect_failed", nil)];
                [UIApplication sharedApplication].idleTimerDisabled = NO;
            }
        });
    }];
}

- (void)disconnect {
    [self.audioCapture stopCapture];
    self.audioCapture = nil;
    [self.transportClient disconnect];
    self.isConnected = NO;
    [self.connectButton setTitle:NSLocalizedString(@"button_connect", nil) forState:UIControlStateNormal];
    [self updateConnectionStatus:NSLocalizedString(@"status_not_connected", nil)];
    [self updateAudioLevel:0.0];

    // Allow screen to sleep again
    [UIApplication sharedApplication].idleTimerDisabled = NO;
}

- (void)openSettings:(UIButton *)sender {
    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)updateConnectionStatus:(NSString *)status {
    self.statusLabel.text = status;
}

- (void)updateAudioLevel:(float)level {
    CFTimeInterval now = CACurrentMediaTime();
    if (now - self.lastLevelUpdateTime < 0.033) return;
    self.lastLevelUpdateTime = now;

    CGFloat clamped = MAX(0.0f, MIN(1.0f, level));
    CGFloat targetWidth = clamped * self.audioLevelContainer.bounds.size.width;

    CABasicAnimation *widthAnim = [CABasicAnimation animationWithKeyPath:@"bounds.size.width"];
    widthAnim.fromValue = @(self.audioLevelBar.layer.bounds.size.width);
    widthAnim.toValue = @(targetWidth);
    widthAnim.duration = 0.1;
    widthAnim.fillMode = kCAFillModeForwards;
    widthAnim.removedOnCompletion = NO;
    [self.audioLevelBar.layer addAnimation:widthAnim forKey:@"audioLevelWidth"];

    CGRect bounds = self.audioLevelBar.layer.bounds;
    bounds.size.width = targetWidth;
    self.audioLevelBar.layer.bounds = bounds;
}

#pragma mark - MicYouAudioCaptureDelegate

- (void)audioCapture:(MicYouAudioCapture *)capture didCaptureBuffer:(NSData *)buffer timestamp:(uint64_t)timestamp {
    if (!self.isConnected) return;
    [self.transportClient sendAudioData:buffer timestamp:timestamp];
}

- (void)audioCapture:(MicYouAudioCapture *)capture didUpdateLevel:(float)level {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateAudioLevel:level];
    });
}

#pragma mark - TransportClientDelegate

- (void)transportClientDidDisconnect:(TransportClient *)client {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isConnected = NO;
        [self.connectButton setTitle:NSLocalizedString(@"button_connect", nil) forState:UIControlStateNormal];
        [self updateConnectionStatus:NSLocalizedString(@"status_disconnected", nil)];
        [self updateAudioLevel:0.0];
        [UIApplication sharedApplication].idleTimerDisabled = NO;
    });
}

- (void)transportClient:(TransportClient *)client didReceiveError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateConnectionStatus:[NSString stringWithFormat:NSLocalizedString(@"error_format", nil), error.localizedDescription]];
    });
}

- (void)dealloc {
    [self disconnect];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
}

@end