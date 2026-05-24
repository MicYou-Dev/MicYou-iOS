#import "SettingsViewController.h"
#import "MicYouLanguageManager.h"

typedef NS_ENUM(NSInteger, SettingsSectionType) {
    SettingsSectionNetwork = 0,
    SettingsSectionAudio,
    SettingsSectionAppearance,
    SettingsSectionGeneral,
    SettingsSectionCount
};

static NSString * const kCellTextField  = @"SettingsTextFieldCell";
static NSString * const kCellSegmented  = @"SettingsSegmentedCell";
static NSString * const kCellSwitch     = @"SettingsSwitchCell";
static NSString * const kCellSelection  = @"SettingsSelectionCell";
static NSString * const kCellInfo       = @"SettingsInfoCell";

static NSArray<NSString *> *seedColorKeys(void) {
    return @[
        @"seed_default_green", @"seed_red", @"seed_pink",
        @"seed_purple", @"seed_deep_purple", @"seed_indigo",
        @"seed_blue", @"seed_light_blue", @"seed_cyan",
        @"seed_deep_green", @"seed_green", @"seed_light_green",
        @"seed_lime", @"seed_yellow", @"seed_amber",
        @"seed_orange", @"seed_deep_orange", @"seed_brown", @"seed_gray"
    ];
}

@interface SettingsViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UITextField *hostTextField;
@property (nonatomic, strong) UITextField *portTextField;
@property (nonatomic, strong) UISegmentedControl *sampleRateControl;
@property (nonatomic, strong) UISegmentedControl *channelControl;
@property (nonatomic, strong) UISwitch *audioVisualizerSwitch;
@property (nonatomic, strong) UISwitch *oledBlackSwitch;
@property (nonatomic, strong) UISwitch *screenAwakeSwitch;

@property (nonatomic, assign) NSInteger themeValue;
@property (nonatomic, assign) NSInteger seedColorIndex;
@property (nonatomic, assign) NSInteger darkModeValue;
@property (nonatomic, assign) BOOL oledBlackValue;
@property (nonatomic, assign) BOOL audioVisualizerValue;
@property (nonatomic, assign) NSInteger languageValue;
@property (nonatomic, assign) BOOL screenAwakeValue;
@property (nonatomic, assign) NSInteger sampleRateValue;
@property (nonatomic, assign) NSInteger channelCountValue;

@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedString(@"button_settings", nil);
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
        target:self action:@selector(doneTapped:)];

    [self loadSettingsFromDefaults];
    [self setupTableView];
    [self loadCurrentValues];
}

#pragma mark - Setup

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kCellTextField];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kCellSegmented];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kCellSwitch];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kCellSelection];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kCellInfo];
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)loadSettingsFromDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    [defaults registerDefaults:@{
        @"micyou_theme": @1,
        @"micyou_seed_color_index": @0,
        @"micyou_dark_mode": @0,
        @"micyou_oled_black": @YES,
        @"micyou_audio_visualizer": @YES,
        @"micyou_language": @0,
        @"micyou_screen_awake": @YES,
        @"micyou_host": @"",
        @"micyou_port": @8900,
        @"micyou_sample_rate": @44100,
        @"micyou_channel_count": @1
    }];
}

- (void)loadCurrentValues {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    self.hostTextField.text = [defaults objectForKey:@"micyou_host"] ?: @"";
    self.portTextField.text = [NSString stringWithFormat:@"%ld", (long)[defaults integerForKey:@"micyou_port"]];
    if (self.portTextField.text.integerValue == 0) {
        self.portTextField.text = @"8900";
    }

    self.sampleRateValue = [defaults integerForKey:@"micyou_sample_rate"];
    self.channelCountValue = [defaults integerForKey:@"micyou_channel_count"];
    self.audioVisualizerValue = [defaults boolForKey:@"micyou_audio_visualizer"];
    self.themeValue = [defaults integerForKey:@"micyou_theme"];
    self.seedColorIndex = [defaults integerForKey:@"micyou_seed_color_index"];
    self.darkModeValue = [defaults integerForKey:@"micyou_dark_mode"];
    self.oledBlackValue = [defaults boolForKey:@"micyou_oled_black"];
    self.languageValue = [defaults integerForKey:@"micyou_language"];
    self.screenAwakeValue = [defaults boolForKey:@"micyou_screen_awake"];

    // segmented controls
    if (self.sampleRateValue == 16000) {
        self.sampleRateControl.selectedSegmentIndex = 0;
    } else if (self.sampleRateValue == 44100) {
        self.sampleRateControl.selectedSegmentIndex = 1;
    } else if (self.sampleRateValue == 48000) {
        self.sampleRateControl.selectedSegmentIndex = 2;
    }

    self.channelControl.selectedSegmentIndex = (self.channelCountValue == 2) ? 1 : 0;
    self.audioVisualizerSwitch.on = self.audioVisualizerValue;
    self.oledBlackSwitch.on = self.oledBlackValue;
    self.screenAwakeSwitch.on = self.screenAwakeValue;
}

#pragma mark - Settings Change

- (void)didChangeSetting:(NSString *)settingKey {
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MicYouSettingsDidChange"
                                                        object:nil
                                                      userInfo:settingKey ? @{@"key": settingKey} : nil];
}

#pragma mark - Save & Dismiss

- (void)saveSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:self.hostTextField.text forKey:@"micyou_host"];
    [defaults setInteger:[self.portTextField.text integerValue] forKey:@"micyou_port"];
    [defaults setInteger:self.sampleRateValue forKey:@"micyou_sample_rate"];
    [defaults setInteger:self.channelCountValue forKey:@"micyou_channel_count"];
    [defaults setBool:self.audioVisualizerValue forKey:@"micyou_audio_visualizer"];
    [defaults setInteger:self.themeValue forKey:@"micyou_theme"];
    [defaults setInteger:self.seedColorIndex forKey:@"micyou_seed_color_index"];
    [defaults setInteger:self.darkModeValue forKey:@"micyou_dark_mode"];
    [defaults setBool:self.oledBlackValue forKey:@"micyou_oled_black"];
    [defaults setInteger:self.languageValue forKey:@"micyou_language"];
    [defaults setBool:self.screenAwakeValue forKey:@"micyou_screen_awake"];

    [self didChangeSetting:nil];
}

- (void)doneTapped:(id)sender {
    [self.view endEditing:YES];
    [self saveSettings];

    // Apply language change
    [[MicYouLanguageManager shared] applyLanguage];

    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Event Handlers

- (void)sampleRateChanged:(UISegmentedControl *)sender {
    switch (sender.selectedSegmentIndex) {
        case 0: self.sampleRateValue = 16000; break;
        case 1: self.sampleRateValue = 44100; break;
        case 2: self.sampleRateValue = 48000; break;
    }
    [self didChangeSetting:@"micyou_sample_rate"];
}

- (void)channelChanged:(UISegmentedControl *)sender {
    self.channelCountValue = (sender.selectedSegmentIndex == 1) ? 2 : 1;
    [self didChangeSetting:@"micyou_channel_count"];
}

- (void)audioVisualizerToggled:(UISwitch *)sender {
    self.audioVisualizerValue = sender.on;
    [self didChangeSetting:@"micyou_audio_visualizer"];
}

- (void)oledBlackToggled:(UISwitch *)sender {
    self.oledBlackValue = sender.on;
    [self didChangeSetting:@"micyou_oled_black"];
}

- (void)screenAwakeToggled:(UISwitch *)sender {
    self.screenAwakeValue = sender.on;
    [[UIApplication sharedApplication] setIdleTimerDisabled:self.screenAwakeValue];
    [self didChangeSetting:@"micyou_screen_awake"];
}

#pragma mark - Selection Helpers

- (void)showThemePicker {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"appearance_theme", nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction *traditionalAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"theme_traditional", nil)
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *action) {
        self.themeValue = 0;
        [self didChangeSetting:@"micyou_theme"];
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:SettingsSectionAppearance]]
                              withRowAnimation:UITableViewRowAnimationNone];
    }];
    UIAlertAction *micyouAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"theme_micyou", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
        self.themeValue = 1;
        [self didChangeSetting:@"micyou_theme"];
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:SettingsSectionAppearance]]
                              withRowAnimation:UITableViewRowAnimationNone];
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"button_cancel", nil)
                                                           style:UIAlertActionStyleCancel handler:nil];

    [alert addAction:traditionalAction];
    [alert addAction:micyouAction];
    [alert addAction:cancelAction];

    // iPad popover support
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:SettingsSectionAppearance]];
    alert.popoverPresentationController.sourceView = cell;
    alert.popoverPresentationController.sourceRect = cell.bounds;

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showSeedColorPicker {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"appearance_seed_color", nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray<NSString *> *keys = seedColorKeys();
    for (NSInteger i = 0; i < (NSInteger)keys.count; i++) {
        NSString *colorName = NSLocalizedString(keys[i], nil);
        UIAlertAction *action = [UIAlertAction actionWithTitle:colorName
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *act) {
            self.seedColorIndex = i;
            [self didChangeSetting:@"micyou_seed_color_index"];
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:SettingsSectionAppearance]]
                                  withRowAnimation:UITableViewRowAnimationNone];
        }];
        [alert addAction:action];
    }
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"button_cancel", nil)
                                                           style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:cancelAction];

    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:SettingsSectionAppearance]];
    alert.popoverPresentationController.sourceView = cell;
    alert.popoverPresentationController.sourceRect = cell.bounds;

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showDarkModePicker {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"appearance_dark_mode", nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction *autoAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"dark_mode_auto", nil)
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *action) {
        self.darkModeValue = 0;
        [self didChangeSetting:@"micyou_dark_mode"];
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:2 inSection:SettingsSectionAppearance]]
                              withRowAnimation:UITableViewRowAnimationNone];
    }];
    UIAlertAction *onAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"dark_mode_on", nil)
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
        self.darkModeValue = 1;
        [self didChangeSetting:@"micyou_dark_mode"];
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:2 inSection:SettingsSectionAppearance]]
                              withRowAnimation:UITableViewRowAnimationNone];
    }];
    UIAlertAction *offAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"dark_mode_off", nil)
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action) {
        self.darkModeValue = 2;
        [self didChangeSetting:@"micyou_dark_mode"];
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:2 inSection:SettingsSectionAppearance]]
                              withRowAnimation:UITableViewRowAnimationNone];
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"button_cancel", nil)
                                                           style:UIAlertActionStyleCancel handler:nil];

    [alert addAction:autoAction];
    [alert addAction:onAction];
    [alert addAction:offAction];
    [alert addAction:cancelAction];

    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:SettingsSectionAppearance]];
    alert.popoverPresentationController.sourceView = cell;
    alert.popoverPresentationController.sourceRect = cell.bounds;

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showLanguagePicker {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"general_language", nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction *systemAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"language_follow_system", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
        self.languageValue = 0;
        [self didChangeSetting:@"micyou_language"];
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:SettingsSectionGeneral]]
                              withRowAnimation:UITableViewRowAnimationNone];
    }];
    UIAlertAction *zhHansAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"language_chinese", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
        self.languageValue = 1;
        [self didChangeSetting:@"micyou_language"];
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:SettingsSectionGeneral]]
                              withRowAnimation:UITableViewRowAnimationNone];
    }];
    UIAlertAction *enAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"language_english", nil)
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
        self.languageValue = 2;
        [self didChangeSetting:@"micyou_language"];
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:SettingsSectionGeneral]]
                              withRowAnimation:UITableViewRowAnimationNone];
    }];
    UIAlertAction *zhHantAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"language_traditional_chinese", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
        self.languageValue = 3;
        [self didChangeSetting:@"micyou_language"];
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:SettingsSectionGeneral]]
                              withRowAnimation:UITableViewRowAnimationNone];
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"button_cancel", nil)
                                                           style:UIAlertActionStyleCancel handler:nil];

    [alert addAction:systemAction];
    [alert addAction:zhHansAction];
    [alert addAction:enAction];
    [alert addAction:zhHantAction];
    [alert addAction:cancelAction];

    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:SettingsSectionGeneral]];
    alert.popoverPresentationController.sourceView = cell;
    alert.popoverPresentationController.sourceRect = cell.bounds;

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Value Display Helpers

- (NSString *)displayTextForTheme {
    if (self.themeValue == 1) return NSLocalizedString(@"theme_micyou", nil);
    return NSLocalizedString(@"theme_traditional", nil);
}

- (NSString *)displayTextForSeedColor {
    NSArray<NSString *> *keys = seedColorKeys();
    if (self.seedColorIndex >= 0 && self.seedColorIndex < (NSInteger)keys.count) {
        return NSLocalizedString(keys[self.seedColorIndex], nil);
    }
    return NSLocalizedString(seedColorKeys()[0], nil);
}

- (NSString *)displayTextForDarkMode {
    switch (self.darkModeValue) {
        case 1: return NSLocalizedString(@"dark_mode_on", nil);
        case 2: return NSLocalizedString(@"dark_mode_off", nil);
        default: return NSLocalizedString(@"dark_mode_auto", nil);
    }
}

- (NSString *)displayTextForLanguage {
    switch (self.languageValue) {
        case 1: return NSLocalizedString(@"language_chinese", nil);
        case 2: return NSLocalizedString(@"language_english", nil);
        case 3: return NSLocalizedString(@"language_traditional_chinese", nil);
        default: return NSLocalizedString(@"language_follow_system", nil);
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return SettingsSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case SettingsSectionNetwork:     return 2;
        case SettingsSectionAudio:       return 3;
        case SettingsSectionAppearance:  return 4;
        case SettingsSectionGeneral:     return 3;
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case SettingsSectionNetwork:     return NSLocalizedString(@"settings_section_network", nil);
        case SettingsSectionAudio:       return NSLocalizedString(@"settings_section_audio", nil);
        case SettingsSectionAppearance:  return NSLocalizedString(@"settings_section_appearance", nil);
        case SettingsSectionGeneral:     return NSLocalizedString(@"settings_section_general", nil);
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
        case SettingsSectionNetwork:
            return NSLocalizedString(@"settings_footer_network", nil);
        case SettingsSectionAudio:
            return NSLocalizedString(@"settings_footer_audio", nil);
        case SettingsSectionAppearance:
            return NSLocalizedString(@"settings_footer_appearance", nil);
        case SettingsSectionGeneral:
            return NSLocalizedString(@"settings_footer_general", nil);
        default: return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case SettingsSectionNetwork:
            return [self networkCellForRow:indexPath.row tableView:tableView];
        case SettingsSectionAudio:
            return [self audioCellForRow:indexPath.row tableView:tableView];
        case SettingsSectionAppearance:
            return [self appearanceCellForRow:indexPath.row tableView:tableView];
        case SettingsSectionGeneral:
            return [self generalCellForRow:indexPath.row tableView:tableView];
    }
    return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
}

#pragma mark - Network Cells

- (UITableViewCell *)networkCellForRow:(NSInteger)row tableView:(UITableView *)tableView {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellTextField forIndexPath:[NSIndexPath indexPathForRow:row inSection:SettingsSectionNetwork]];

    // clear previous accessory
    cell.accessoryView = nil;
    cell.textLabel.text = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    if (row == 0) {
        cell.textLabel.text = NSLocalizedString(@"network_host_label", nil);
        self.hostTextField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 200, 30)];
        self.hostTextField.placeholder = NSLocalizedString(@"network_host_placeholder", nil);
        self.hostTextField.textAlignment = NSTextAlignmentRight;
        self.hostTextField.keyboardType = UIKeyboardTypeDecimalPad;
        self.hostTextField.returnKeyType = UIReturnKeyDone;
        self.hostTextField.delegate = self;
        self.hostTextField.text = [[NSUserDefaults standardUserDefaults] objectForKey:@"micyou_host"] ?: @"";
        cell.accessoryView = self.hostTextField;
    } else if (row == 1) {
        cell.textLabel.text = NSLocalizedString(@"network_port_label", nil);
        self.portTextField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 120, 30)];
        self.portTextField.placeholder = @"8900";
        self.portTextField.textAlignment = NSTextAlignmentRight;
        self.portTextField.keyboardType = UIKeyboardTypeNumberPad;
        self.portTextField.returnKeyType = UIReturnKeyDone;
        self.portTextField.delegate = self;
        NSInteger port = [[NSUserDefaults standardUserDefaults] integerForKey:@"micyou_port"];
        if (port == 0) port = 8900;
        self.portTextField.text = [NSString stringWithFormat:@"%ld", (long)port];
        cell.accessoryView = self.portTextField;
    }

    return cell;
}

#pragma mark - Audio Cells

- (UITableViewCell *)audioCellForRow:(NSInteger)row tableView:(UITableView *)tableView {
    if (row == 0) {
        // Sample Rate segmented control
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellSegmented forIndexPath:[NSIndexPath indexPathForRow:row inSection:SettingsSectionAudio]];
        cell.textLabel.text = NSLocalizedString(@"audio_sample_rate", nil);
        cell.accessoryView = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        self.sampleRateControl = [[UISegmentedControl alloc] initWithItems:@[@"16000", @"44100", @"48000"]];
        NSInteger currentRate = self.sampleRateValue;
        if (currentRate == 16000) self.sampleRateControl.selectedSegmentIndex = 0;
        else if (currentRate == 44100) self.sampleRateControl.selectedSegmentIndex = 1;
        else if (currentRate == 48000) self.sampleRateControl.selectedSegmentIndex = 2;
        else self.sampleRateControl.selectedSegmentIndex = 1;

        [self.sampleRateControl addTarget:self action:@selector(sampleRateChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = self.sampleRateControl;

        return cell;
    } else if (row == 1) {
        // Channel segmented control
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellSegmented forIndexPath:[NSIndexPath indexPathForRow:row inSection:SettingsSectionAudio]];
        cell.textLabel.text = NSLocalizedString(@"audio_channel", nil);
        cell.accessoryView = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        self.channelControl = [[UISegmentedControl alloc] initWithItems:@[
            NSLocalizedString(@"audio_mono", nil),
            NSLocalizedString(@"audio_stereo", nil)
        ]];
        self.channelControl.selectedSegmentIndex = (self.channelCountValue == 2) ? 1 : 0;
        [self.channelControl addTarget:self action:@selector(channelChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = self.channelControl;

        return cell;
    } else {
        // Audio Visualizer toggle
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellSwitch forIndexPath:[NSIndexPath indexPathForRow:row inSection:SettingsSectionAudio]];
        cell.textLabel.text = NSLocalizedString(@"audio_visualizer", nil);
        cell.accessoryView = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        self.audioVisualizerSwitch = [[UISwitch alloc] init];
        self.audioVisualizerSwitch.on = self.audioVisualizerValue;
        [self.audioVisualizerSwitch addTarget:self action:@selector(audioVisualizerToggled:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = self.audioVisualizerSwitch;

        return cell;
    }
}

#pragma mark - Appearance Cells

- (UITableViewCell *)appearanceCellForRow:(NSInteger)row tableView:(UITableView *)tableView {
    if (row == 0) {
        // Theme selection
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellSelection forIndexPath:[NSIndexPath indexPathForRow:row inSection:SettingsSectionAppearance]];
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kCellSelection];
        cell.textLabel.text = NSLocalizedString(@"appearance_theme", nil);
        cell.detailTextLabel.text = [self displayTextForTheme];
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    } else if (row == 1) {
        // Seed Color selection
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellSelection forIndexPath:[NSIndexPath indexPathForRow:row inSection:SettingsSectionAppearance]];
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kCellSelection];
        cell.textLabel.text = NSLocalizedString(@"appearance_seed_color", nil);
        cell.detailTextLabel.text = [self displayTextForSeedColor];
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    } else if (row == 2) {
        // Dark Mode selection
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellSelection forIndexPath:[NSIndexPath indexPathForRow:row inSection:SettingsSectionAppearance]];
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kCellSelection];
        cell.textLabel.text = NSLocalizedString(@"appearance_dark_mode", nil);
        cell.detailTextLabel.text = [self displayTextForDarkMode];
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    } else {
        // OLED Pure Black toggle
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellSwitch forIndexPath:[NSIndexPath indexPathForRow:row inSection:SettingsSectionAppearance]];
        cell.textLabel.text = NSLocalizedString(@"appearance_oled_black", nil);
        cell.accessoryView = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        self.oledBlackSwitch = [[UISwitch alloc] init];
        self.oledBlackSwitch.on = self.oledBlackValue;
        [self.oledBlackSwitch addTarget:self action:@selector(oledBlackToggled:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = self.oledBlackSwitch;

        return cell;
    }
}

#pragma mark - General Cells

- (UITableViewCell *)generalCellForRow:(NSInteger)row tableView:(UITableView *)tableView {
    if (row == 0) {
        // Language selection
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellSelection forIndexPath:[NSIndexPath indexPathForRow:row inSection:SettingsSectionGeneral]];
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kCellSelection];
        cell.textLabel.text = NSLocalizedString(@"general_language", nil);
        cell.detailTextLabel.text = [self displayTextForLanguage];
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    } else if (row == 1) {
        // Screen keep-awake toggle
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellSwitch forIndexPath:[NSIndexPath indexPathForRow:row inSection:SettingsSectionGeneral]];
        cell.textLabel.text = NSLocalizedString(@"general_screen_awake", nil);
        cell.accessoryView = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        self.screenAwakeSwitch = [[UISwitch alloc] init];
        self.screenAwakeSwitch.on = self.screenAwakeValue;
        [self.screenAwakeSwitch addTarget:self action:@selector(screenAwakeToggled:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = self.screenAwakeSwitch;

        return cell;
    } else {
        // About
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellInfo forIndexPath:[NSIndexPath indexPathForRow:row inSection:SettingsSectionGeneral]];
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kCellInfo];
        cell.textLabel.text = NSLocalizedString(@"general_about", nil);

        NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0";
        cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"app_version_format", nil), version];
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    switch (indexPath.section) {
        case SettingsSectionAppearance:
            switch (indexPath.row) {
                case 0: [self showThemePicker]; break;
                case 1: [self showSeedColorPicker]; break;
                case 2: [self showDarkModePicker]; break;
            }
            break;
        case SettingsSectionGeneral:
            if (indexPath.row == 0) {
                [self showLanguagePicker];
            }
            break;
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end