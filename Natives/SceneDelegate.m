#import "SceneDelegate.h"
#import "MainViewController.h"
#import "MicYouViewController.h"
#import "MicYouLanguageManager.h"
#import "MicYouColors.h"
#import "LaunchAnimationViewController.h"

@interface SceneDelegate () <LaunchAnimationDelegate>
@end

@implementation SceneDelegate

- (UIViewController *)createMainViewController {
    // Initialize language manager early
    [MicYouLanguageManager shared];

    // Setup default settings
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults objectForKey:@"micyou_theme"]) {
        [defaults registerDefaults:@{
            @"micyou_theme": @1,  // Default: MicYou style
            @"micyou_seed_color_index": @0,
            @"micyou_dark_mode": @0,
            @"micyou_oled_black": @YES,
            @"micyou_audio_visualizer": @YES,
            @"micyou_language": @0,
            @"micyou_screen_awake": @YES,
            @"micyou_launch_animation": @YES,  // Default: launch animation ON
            @"micyou_host": @"",
            @"micyou_port": @8900,
            @"micyou_sample_rate": @44100,
            @"micyou_channel_count": @1
        }];
    }

    // Select theme based on user preference (default: MicYou = 1)
    NSInteger theme = [defaults integerForKey:@"micyou_theme"];
    UIViewController *rootVC;

    if (theme == 1) {
        // MicYou style theme
        rootVC = [[MicYouViewController alloc] init];
    } else {
        // Traditional style theme
        rootVC = [[MainViewController alloc] init];
    }

    return rootVC;
}

- (BOOL)shouldShowLaunchAnimation {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"micyou_launch_animation"];
}

- (BOOL)isDarkModeActive {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger darkModeValue = [defaults integerForKey:@"micyou_dark_mode"];
    BOOL useOLED = [defaults boolForKey:@"micyou_oled_black"];

    if (@available(iOS 13.0, *)) {
        if (darkModeValue == 0) {
            // Auto: follow system
            return [UITraitCollection currentTraitCollection].userInterfaceStyle == UIUserInterfaceStyleDark;
        } else if (darkModeValue == 1) {
            // On
            return YES;
        }
    }
    return NO;
}

- (void)showMainInterface {
    UIViewController *mainVC = [self createMainViewController];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:mainVC];
    self.window.rootViewController = nav;
}

- (void)setupWindow {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];

    if ([self shouldShowLaunchAnimation]) {
        // Show launch animation first
        BOOL isDark = [self isDarkModeActive];
        LaunchAnimationViewController *launchVC = [[LaunchAnimationViewController alloc] initWithDarkMode:isDark];
        launchVC.delegate = self;
        self.window.rootViewController = launchVC;
    } else {
        // Skip animation, show main interface directly
        [self showMainInterface];
    }

    [self.window makeKeyAndVisible];
}

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions API_AVAILABLE(ios(13.0)) {
    if (![scene isKindOfClass:[UIWindowScene class]]) {
        return;
    }

    UIWindowScene *windowScene = (UIWindowScene *)scene;
    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
    self.window.backgroundColor = [UIColor whiteColor];

    if ([self shouldShowLaunchAnimation]) {
        // Show launch animation first
        BOOL isDark = [self isDarkModeActive];
        LaunchAnimationViewController *launchVC = [[LaunchAnimationViewController alloc] initWithDarkMode:isDark];
        launchVC.delegate = self;
        self.window.rootViewController = launchVC;
    } else {
        // Skip animation, show main interface directly
        [self showMainInterface];
    }

    [self.window makeKeyAndVisible];

    // Listen for theme changes to swap root view controller
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(settingsDidChange:)
                                                 name:@"MicYouSettingsDidChange"
                                               object:nil];
}

#pragma mark - LaunchAnimationDelegate

- (void)launchAnimationDidFinish:(LaunchAnimationViewController *)controller {
    [self showMainInterface];
}

- (void)sceneDidDisconnect:(UIScene *)scene API_AVAILABLE(ios(13.0)) {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)sceneDidBecomeActive:(UIScene *)scene API_AVAILABLE(ios(13.0)) {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MicYouAppDidBecomeActive" object:nil];
}

- (void)sceneWillResignActive:(UIScene *)scene API_AVAILABLE(ios(13.0)) {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MicYouAppWillResignActive" object:nil];
}

- (void)sceneWillEnterForeground:(UIScene *)scene API_AVAILABLE(ios(13.0)) {
}

- (void)sceneDidEnterBackground:(UIScene *)scene API_AVAILABLE(ios(13.0)) {
}

#pragma mark - Settings Change Handler

- (void)settingsDidChange:(NSNotification *)notification {
    NSInteger theme = [[NSUserDefaults standardUserDefaults] integerForKey:@"micyou_theme"];
    UIViewController *currentRoot = self.window.rootViewController;
    
    // Determine if we need to switch theme
    BOOL isCurrentlyMicYou = [currentRoot isKindOfClass:[UINavigationController class]] &&
                              [[(UINavigationController *)currentRoot topViewController] isKindOfClass:[MicYouViewController class]];
    BOOL shouldBeMicYou = (theme == 1);
    
    if (isCurrentlyMicYou != shouldBeMicYou) {
        // Need to swap root view controller
        UIViewController *newRootVC = shouldBeMicYou ? [[MicYouViewController alloc] init] : [[MainViewController alloc] init];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:newRootVC];
        
        // Cross-fade transition
        [UIView transitionWithView:self.window
                          duration:0.35
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            self.window.rootViewController = nav;
        } completion:nil];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end