#import "MainViewController.h"
#import "SettingsViewController.h"
#import "MicYouAudioCapture.h"
#import "TransportClient.h"
#import "AudioBufferQueue.h"

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
@property (nonatomic, strong) AudioBufferQueue *bufferQueue;

@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"MicYou";
    self.view.backgroundColor = [UIColor whiteColor];

    [self setupUI];
    [self setupAudioAndNetwork];
}

- (void)setupUI {
    CGFloat margin = 20.0;
    CGFloat cardCornerRadius = 16.0;
    UIColor *primaryColor = [UIColor colorWithRed:0.13 green:0.59 blue:0.95 alpha:1.0];

    self.statusCard = [[UIView alloc] init];
    self.statusCard.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    self.statusCard.layer.cornerRadius = cardCornerRadius;
    self.statusCard.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusCard];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"未连接";
    self.statusLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
    self.statusLabel.textColor = [UIColor blackColor];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.statusCard addSubview:self.statusLabel];

    self.audioLevelContainer = [[UIView alloc] init];
    self.audioLevelContainer.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    self.audioLevelContainer.layer.cornerRadius = 8.0;
    self.audioLevelContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.statusCard addSubview:self.audioLevelContainer];

    self.audioLevelBar = [[UIView alloc] init];
    self.audioLevelBar.backgroundColor = primaryColor;
    self.audioLevelBar.layer.cornerRadius = 8.0;
    self.audioLevelBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.audioLevelContainer addSubview:self.audioLevelBar];

    self.connectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.connectButton setTitle:@"连接" forState:UIControlStateNormal];
    [self.connectButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.connectButton.backgroundColor = primaryColor;
    self.connectButton.layer.cornerRadius = 28.0;
    self.connectButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    self.connectButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.connectButton addTarget:self action:@selector(toggleConnection:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.connectButton];

    self.settingsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.settingsButton setTitle:@"设置" forState:UIControlStateNormal];
    self.settingsButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.settingsButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.settingsButton addTarget:self action:@selector(openSettings:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.settingsButton];

    self.hostLabel = [[UILabel alloc] init];
    self.hostLabel.text = @"主机: 未配置";
    self.hostLabel.font = [UIFont systemFontOfSize:14];
    self.hostLabel.textColor = [UIColor grayColor];
    self.hostLabel.textAlignment = NSTextAlignmentCenter;
    self.hostLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.hostLabel];

    self.infoLabel = [[UILabel alloc] init];
    self.infoLabel.text = @"MicYou v1.0 | 将 iPhone 变成无线麦克风";
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
}

- (void)setupAudioAndNetwork {
    self.bufferQueue = [[AudioBufferQueue alloc] initWithCapacity:64];
    self.audioCapture = [[MicYouAudioCapture alloc] init];
    self.audioCapture.delegate = self;

    self.transportClient = [[TransportClient alloc] init];
    self.transportClient.delegate = self;
}

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
        [self updateConnectionStatus:@"请先配置主机地址"];
        return;
    }

    self.hostLabel.text = [NSString stringWithFormat:@"主机: %@:%ld", host, (long)port];

    __weak typeof(self) weakSelf = self;
    [self.transportClient connectToHost:host port:(int)port completion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                weakSelf.isConnected = YES;
                [weakSelf.connectButton setTitle:@"断开" forState:UIControlStateNormal];
                [weakSelf updateConnectionStatus:@"已连接"];
                [weakSelf.audioCapture startCapture];
            } else {
                [weakSelf updateConnectionStatus:@"连接失败"];
            }
        });
    }];
}

- (void)disconnect {
    [self.audioCapture stopCapture];
    [self.transportClient disconnect];
    self.isConnected = NO;
    [self.connectButton setTitle:@"连接" forState:UIControlStateNormal];
    [self updateConnectionStatus:@"未连接"];
    [self updateAudioLevel:0.0];
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
    CGFloat clamped = MAX(0.0f, MIN(1.0f, level));
    for (NSLayoutConstraint *constraint in self.audioLevelBar.constraints) {
        if (constraint.firstAttribute == NSLayoutAttributeWidth) {
            [self.audioLevelBar removeConstraint:constraint];
            break;
        }
    }
    NSLayoutConstraint *widthConstraint = [self.audioLevelBar.widthAnchor constraintEqualToAnchor:self.audioLevelContainer.widthAnchor multiplier:clamped];
    widthConstraint.active = YES;
    [UIView animateWithDuration:0.05 animations:^{
        [self.audioLevelBar layoutIfNeeded];
    }];
}

#pragma mark - MicYouAudioCaptureDelegate

- (void)audioCapture:(MicYouAudioCapture *)capture didCaptureBuffer:(NSData *)buffer timestamp:(uint64_t)timestamp {
    if (!self.isConnected) return;
    [self.bufferQueue enqueue:buffer timestamp:timestamp];
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
        [self.connectButton setTitle:@"连接" forState:UIControlStateNormal];
        [self updateConnectionStatus:@"已断开"];
        [self updateAudioLevel:0.0];
    });
}

- (void)transportClient:(TransportClient *)client didReceiveError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateConnectionStatus:[NSString stringWithFormat:@"错误: %@", error.localizedDescription]];
    });
}

- (void)dealloc {
    [self disconnect];
}

@end
