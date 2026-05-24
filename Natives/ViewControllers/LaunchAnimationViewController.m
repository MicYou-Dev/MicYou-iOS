#import "LaunchAnimationViewController.h"

@interface LaunchAnimationViewController ()

@property (nonatomic, strong) UIImageView *animationImageView;
@property (nonatomic, strong) NSMutableArray<UIImage *> *frames;
@property (nonatomic, strong) NSTimer *animationTimer;
@property (nonatomic, assign) NSInteger currentFrameIndex;
@property (nonatomic, assign) BOOL isDarkMode;
@property (nonatomic, assign) BOOL isFinished;
@property (nonatomic, assign) NSTimeInterval frameInterval;

@end

@implementation LaunchAnimationViewController

- (instancetype)initWithDarkMode:(BOOL)darkMode {
    self = [super init];
    if (self) {
        _isDarkMode = darkMode;
        _frameInterval = 1.0 / 60.0; // 60fps
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Background color based on mode
    self.view.backgroundColor = self.isDarkMode ? [UIColor blackColor] : [UIColor whiteColor];

    // Setup image view for animation
    self.animationImageView = [[UIImageView alloc] init];
    self.animationImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.animationImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:self.animationImageView];

    // Center the animation view with safe margins (not full screen)
    CGFloat margin = 60.0; // Keep distance from edges
    [NSLayoutConstraint activateConstraints:@[
        [self.animationImageView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.animationImageView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.animationImageView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:margin],
        [self.animationImageView.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-margin],
        [self.animationImageView.topAnchor constraintGreaterThanOrEqualToAnchor:self.view.topAnchor constant:margin],
        [self.animationImageView.bottomAnchor constraintLessThanOrEqualToAnchor:self.view.bottomAnchor constant:-margin],
        // Max size constraints to keep it reasonable on all devices
        [self.animationImageView.widthAnchor constraintLessThanOrEqualToConstant:320],
        [self.animationImageView.heightAnchor constraintLessThanOrEqualToConstant:180],
    ]];

    // Load frames
    [self loadFrames];

    // Tap to skip
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [self.view addGestureRecognizer:tapGesture];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (self.frames.count > 0) {
        [self startAnimation];
    } else {
        // No frames loaded, finish immediately
        [self finishAnimation];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopAnimation];
}

#pragma mark - Frame Loading

- (void)loadFrames {
    self.frames = [NSMutableArray array];

    NSString *subDir = self.isDarkMode ? @"dark" : @"light";
    NSString *resourcePath = [[NSBundle mainBundle] pathForResource:subDir ofType:nil inDirectory:@"LaunchAnimation"];

    if (!resourcePath) {
        // Try alternative path structure
        resourcePath = [[NSBundle mainBundle] resourcePath];
        resourcePath = [resourcePath stringByAppendingPathComponent:@"LaunchAnimation"];
        resourcePath = [resourcePath stringByAppendingPathComponent:subDir];
    }

    if (!resourcePath) {
        NSLog(@"[LaunchAnimation] Resource path not found for %@", subDir);
        return;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *contents = [fm contentsOfDirectoryAtPath:resourcePath error:nil];

    // Sort filenames naturally (frame_001.png, frame_002.png, ...)
    NSArray *sortedContents = [contents sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return [a compare:b options:NSNumericSearch];
    }];

    NSInteger loadedCount = 0;
    for (NSString *filename in sortedContents) {
        if ([filename hasSuffix:@".png"]) {
            NSString *filePath = [resourcePath stringByAppendingPathComponent:filename];
            UIImage *image = [UIImage imageWithContentsOfFile:filePath];
            if (image) {
                [self.frames addObject:image];
                loadedCount++;
            }
        }
    }

    NSLog(@"[LaunchAnimation] Loaded %ld frames from %@", (long)loadedCount, subDir);
}

#pragma mark - Animation

- (void)startAnimation {
    self.currentFrameIndex = 0;
    self.isFinished = NO;

    // Use CADisplayLink for smooth 60fps animation (iOS 11+)
    if (@available(iOS 13.0, *)) {
        // iOS 13+: Use display link with preferred frames per second
        CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateFrame)];
        displayLink.preferredFramesPerSecond = 60;
        [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        self.animationTimer = (NSTimer *)displayLink; // Store as timer for cleanup
    } else {
        // iOS 11-12: Use NSTimer fallback
        self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:self.frameInterval
                                                                 target:self
                                                               selector:@selector(updateFrame)
                                                               userInfo:nil
                                                                repeats:YES];
    }
}

- (void)stopAnimation {
    if ([self.animationTimer isKindOfClass:[CADisplayLink class]]) {
        CADisplayLink *displayLink = (CADisplayLink *)self.animationTimer;
        [displayLink invalidate];
    } else if ([self.animationTimer isKindOfClass:[NSTimer class]]) {
        [self.animationTimer invalidate];
    }
    self.animationTimer = nil;
}

- (void)updateFrame {
    if (self.isFinished) return;

    if (self.currentFrameIndex < self.frames.count) {
        self.animationImageView.image = self.frames[self.currentFrameIndex];
        self.currentFrameIndex++;
    } else {
        // Animation complete
        [self stopAnimation];
        [self finishAnimation];
    }
}

#pragma mark - Finish

- (void)finishAnimation {
    if (self.isFinished) return;
    self.isFinished = YES;

    // Fade out animation
    [UIView animateWithDuration:0.4
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self.view.alpha = 0.0;
    } completion:^(BOOL finished) {
        if ([self.delegate respondsToSelector:@selector(launchAnimationDidFinish:)]) {
            [self.delegate launchAnimationDidFinish:self];
        }
    }];
}

#pragma mark - Tap to Skip

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    [self stopAnimation];
    [self finishAnimation];
}

@end
