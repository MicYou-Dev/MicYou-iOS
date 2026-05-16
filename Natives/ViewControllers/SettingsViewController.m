#import "SettingsViewController.h"

@interface SettingsViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UITextField *hostTextField;
@property (nonatomic, strong) UITextField *portTextField;
@property (nonatomic, strong) UISegmentedControl *sampleRateControl;
@property (nonatomic, strong) UISegmentedControl *channelControl;

@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"设置";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneTapped:)];

    [self setupTableView];
    [self loadSettings];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)loadSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.hostTextField.text = [defaults objectForKey:@"micyou_host"] ?: @"";
    self.portTextField.text = [NSString stringWithFormat:@"%ld", (long)([defaults integerForKey:@"micyou_port"] ?: 8900)];
}

- (void)saveSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:self.hostTextField.text forKey:@"micyou_host"];
    [defaults setInteger:[self.portTextField.text integerValue] forKey:@"micyou_port"];
    [defaults synchronize];
}

- (void)doneTapped:(id)sender {
    [self saveSettings];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 2 : 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"网络" : @"音频";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"SettingsCell"];

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"主机地址";
            self.hostTextField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 200, 30)];
            self.hostTextField.placeholder = @"192.168.1.100";
            self.hostTextField.textAlignment = NSTextAlignmentRight;
            self.hostTextField.keyboardType = UIKeyboardTypeDecimalPad;
            self.hostTextField.returnKeyType = UIReturnKeyDone;
            self.hostTextField.delegate = self;
            cell.accessoryView = self.hostTextField;
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"端口";
            self.portTextField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 120, 30)];
            self.portTextField.placeholder = @"8900";
            self.portTextField.textAlignment = NSTextAlignmentRight;
            self.portTextField.keyboardType = UIKeyboardTypeNumberPad;
            self.portTextField.returnKeyType = UIReturnKeyDone;
            self.portTextField.delegate = self;
            cell.accessoryView = self.portTextField;
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"采样率";
            self.sampleRateControl = [[UISegmentedControl alloc] initWithItems:@[@"16000", @"44100", @"48000"]];
            self.sampleRateControl.selectedSegmentIndex = 1;
            cell.accessoryView = self.sampleRateControl;
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"声道";
            self.channelControl = [[UISegmentedControl alloc] initWithItems:@[@"单声道", @"立体声"]];
            self.channelControl.selectedSegmentIndex = 0;
            cell.accessoryView = self.channelControl;
        }
    }

    return cell;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end
