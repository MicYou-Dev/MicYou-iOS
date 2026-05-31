#import "MicYouVisualizerView.h"
#import <QuartzCore/QuartzCore.h>

static const CGFloat kAlphaBackgroundRing = 0.15f;
static const CGFloat kAlphaEndDot = 0.9f;
static const CGFloat kAlphaTickActive = 0.4f;
static const CGFloat kAlphaTickInactive = 0.1f;
static const CGFloat kAlphaRingBase = 0.35f;
static const CGFloat kAlphaRingDecrement = 0.07f;
static const CGFloat kAlphaBarBase = 0.5f;
static const CGFloat kAlphaInnerGlow = 0.15f;
static const CGFloat kAlphaGlowMax = 0.35f;
static const CGFloat kAlphaCore = 0.6f;
static const CGFloat kAlphaRay = 0.3f;
static const CGFloat kAlphaParticleBase = 0.3f;

static const NSInteger kVolumeRingTickCount = 60;
static const NSInteger kVolumeRingMajorTickInterval = 5;
static const CGFloat kVolumeRingBaseRadiusFactor = 0.85f;
static const CGFloat kVolumeRingStrokeWidth = 8.0f;
static const CGFloat kVolumeRingMajorTickLength = 6.0f;
static const CGFloat kVolumeRingMinorTickLength = 3.0f;
static const CGFloat kVolumeRingInnerGlowRadiusFactor = 0.6f;

static const NSInteger kRippleRingCount = 4;
static const NSInteger kRippleBarCount = 48;
static const CGFloat kRippleBaseInnerRadius = 0.45f;
static const CGFloat kRippleBarHeightFactor = 0.18f;
static const CGFloat kRippleRingWidthBase = 4.0f;
static const NSInteger kRippleGlowSteps = 8;

static const NSInteger kBarsCount = 48;
static const CGFloat kBarsInnerRadiusFactor = 0.35f;
static const CGFloat kBarsHeightFactor = 0.35f;

static const NSInteger kWaveCount = 3;
static const NSInteger kWaveSegments = 72;
static const CGFloat kWaveBaseRadiusFactor = 0.4f;
static const CGFloat kWaveRadiusIncrement = 0.15f;
static const CGFloat kWaveAmplitudeFactor = 0.08f;
static const CGFloat kWaveCenterRadiusFactor = 0.25f;

static const NSInteger kGlowLayers = 12;
static const NSInteger kGlowRayCount = 8;
static const CGFloat kGlowCoreRadiusFactor = 0.15f;
static const CGFloat kGlowRayLengthFactor = 0.4f;

static const NSInteger kParticlesCount = 36;
static const CGFloat kParticlesBaseDistanceFactor = 0.35f;
static const CGFloat kParticlesCenterGlowRadiusFactor = 0.2f;
static const CGFloat kParticlesTrailLengthFactor = 0.1f;

static inline CGFloat DegreesToRadians(CGFloat degrees) {
    return degrees * M_PI / 180.0;
}

@interface MicYouVisualizerView ()
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) CGFloat phase;
@property (nonatomic, strong) NSMutableArray<CALayer *> *styleLayers;
@property (nonatomic, assign) CGFloat targetAudioLevel;
@property (nonatomic, assign) CGFloat currentAudioLevel;
@property (nonatomic, assign) CGFloat breathScale;
@property (nonatomic, assign) CGFloat glowAlpha;
@property (nonatomic, assign) NSTimeInterval lastTimestamp;
@end

@implementation MicYouVisualizerView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    _style = MicYouVisualizerStyleRipple;
    _audioLevel = 0.0f;
    _targetAudioLevel = 0.0f;
    _currentAudioLevel = 0.0f;
    _visualizerColor = [UIColor systemBlueColor];
    _phase = 0.0f;
    _breathScale = 1.0f;
    _glowAlpha = 0.35f;
    _styleLayers = [NSMutableArray array];
    _lastTimestamp = 0;

    [self setupDisplayLink];
    [self buildLayersForCurrentStyle];
}

- (void)dealloc {
    [_displayLink invalidate];
}

- (void)setupDisplayLink {
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkTick:)];
    self.displayLink.preferredFramesPerSecond = 30;
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)displayLinkTick:(CADisplayLink *)displayLink {
    NSTimeInterval dt = displayLink.timestamp - self.lastTimestamp;
    self.lastTimestamp = displayLink.timestamp;
    if (dt <= 0 || dt > 1.0) dt = 1.0 / 30.0;

    self.phase += dt * 360.0;
    if (self.phase > 1000000.0) self.phase = fmod(self.phase, 1000000.0);

    CGFloat breathMin = 0.97f;
    CGFloat breathMax = 1.03f;
    CGFloat breathDuration = 1.8f;
    CGFloat breathPhase = fmod(displayLink.timestamp, breathDuration) / breathDuration;
    self.breathScale = breathMin + (breathMax - breathMin) * (0.5f + 0.5f * sin(breathPhase * 2.0 * M_PI));

    CGFloat glowMin = 0.2f;
    CGFloat glowMax = 0.5f;
    CGFloat glowDuration = 2.0f;
    CGFloat glowPhase = fmod(displayLink.timestamp, glowDuration) / glowDuration;
    self.glowAlpha = glowMin + (glowMax - glowMin) * (0.5f + 0.5f * sin(glowPhase * 2.0 * M_PI));

    CGFloat lerpSpeed = 10.0f * (CGFloat)dt;
    if (lerpSpeed > 1.0f) lerpSpeed = 1.0f;
    self.currentAudioLevel = self.currentAudioLevel + (self.targetAudioLevel - self.currentAudioLevel) * lerpSpeed;

    [self updateLayers];
}

- (void)updateWithLevel:(float)level {
    self.targetAudioLevel = fminf(fmaxf(level, 0.0f), 1.0f);
}

- (void)setStyle:(MicYouVisualizerStyle)style {
    [self setStyle:style animated:NO];
}

- (void)setStyle:(MicYouVisualizerStyle)style animated:(BOOL)animated {
    if (_style == style) return;
    _style = style;
    [self clearAllStyleLayers];
    [self buildLayersForCurrentStyle];
}

- (void)setVisualizerColor:(UIColor *)visualizerColor {
    _visualizerColor = visualizerColor;
    [self updateLayers];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self clearAllStyleLayers];
    [self buildLayersForCurrentStyle];
}

- (void)clearAllStyleLayers {
    for (CALayer *layer in self.styleLayers) {
        [layer removeFromSuperlayer];
    }
    [self.styleLayers removeAllObjects];
}

- (void)buildLayersForCurrentStyle {
    switch (self.style) {
        case MicYouVisualizerStyleVolumeRing:
            [self buildVolumeRingLayers];
            break;
        case MicYouVisualizerStyleRipple:
            [self buildRippleLayers];
            break;
        case MicYouVisualizerStyleBars:
            [self buildBarsLayers];
            break;
        case MicYouVisualizerStyleWave:
            [self buildWaveLayers];
            break;
        case MicYouVisualizerStyleGlow:
            [self buildGlowLayers];
            break;
        case MicYouVisualizerStyleParticles:
            [self buildParticlesLayers];
            break;
    }
    [self updateLayers];
}

- (void)updateLayers {
    switch (self.style) {
        case MicYouVisualizerStyleVolumeRing:
            [self updateVolumeRing];
            break;
        case MicYouVisualizerStyleRipple:
            [self updateRipple];
            break;
        case MicYouVisualizerStyleBars:
            [self updateBars];
            break;
        case MicYouVisualizerStyleWave:
            [self updateWave];
            break;
        case MicYouVisualizerStyleGlow:
            [self updateGlow];
            break;
        case MicYouVisualizerStyleParticles:
            [self updateParticles];
            break;
    }
}

#pragma mark - Helpers

- (CGFloat)baseRadius {
    return fmin(self.bounds.size.width, self.bounds.size.height) / 2.0f;
}

- (CGPoint)centerPoint {
    return CGPointMake(self.bounds.size.width / 2.0f, self.bounds.size.height / 2.0f);
}

- (UIColor *)colorWithAlpha:(CGFloat)alpha {
    return [self.visualizerColor colorWithAlphaComponent:alpha];
}

#pragma mark - Volume Ring

- (void)buildVolumeRingLayers {
    CGFloat baseRadius = [self baseRadius] * kVolumeRingBaseRadiusFactor;
    CGPoint center = [self centerPoint];

    CAShapeLayer *bgRing = [CAShapeLayer layer];
    bgRing.frame = self.bounds;
    UIBezierPath *bgPath = [UIBezierPath bezierPathWithArcCenter:center radius:baseRadius startAngle:0 endAngle:2.0 * M_PI clockwise:YES];
    bgRing.path = bgPath.CGPath;
    bgRing.fillColor = [UIColor clearColor].CGColor;
    bgRing.strokeColor = [self colorWithAlpha:kAlphaBackgroundRing].CGColor;
    bgRing.lineWidth = kVolumeRingStrokeWidth;
    [self.layer addSublayer:bgRing];
    [self.styleLayers addObject:bgRing];

    CAShapeLayer *arcLayer = [CAShapeLayer layer];
    arcLayer.frame = self.bounds;
    arcLayer.fillColor = [UIColor clearColor].CGColor;
    arcLayer.strokeColor = self.visualizerColor.CGColor;
    arcLayer.lineWidth = kVolumeRingStrokeWidth;
    arcLayer.lineCap = kCALineCapRound;
    [self.layer addSublayer:arcLayer];
    [self.styleLayers addObject:arcLayer];

    CAShapeLayer *dotLayer = [CAShapeLayer layer];
    dotLayer.frame = self.bounds;
    [self.layer addSublayer:dotLayer];
    [self.styleLayers addObject:dotLayer];

    for (NSInteger i = 0; i < kVolumeRingTickCount; i++) {
        CAShapeLayer *tick = [CAShapeLayer layer];
        tick.frame = self.bounds;
        [self.layer addSublayer:tick];
        [self.styleLayers addObject:tick];
    }

    CAShapeLayer *glowLayer = [CAShapeLayer layer];
    glowLayer.frame = self.bounds;
    [self.layer addSublayer:glowLayer];
    [self.styleLayers addObject:glowLayer];
}

- (void)updateVolumeRing {
    CGFloat baseRadius = [self baseRadius] * kVolumeRingBaseRadiusFactor;
    CGPoint center = [self centerPoint];
    CGFloat animatedLevel = self.currentAudioLevel;
    CGFloat sweepAngle = 360.0f * animatedLevel;
    CGFloat startAngle = -90.0f;

    CAShapeLayer *arcLayer = self.styleLayers[1];
    UIBezierPath *arcPath = [UIBezierPath bezierPathWithArcCenter:center radius:baseRadius startAngle:DegreesToRadians(startAngle) endAngle:DegreesToRadians(startAngle + sweepAngle) clockwise:YES];
    arcLayer.path = arcPath.CGPath;
    arcLayer.strokeColor = self.visualizerColor.CGColor;

    CAShapeLayer *dotLayer = self.styleLayers[2];
    if (self.currentAudioLevel > 0.05f) {
        CGFloat endAngleRad = DegreesToRadians(startAngle + sweepAngle);
        CGFloat dotX = center.x + baseRadius * cos(endAngleRad);
        CGFloat dotY = center.y + baseRadius * sin(endAngleRad);
        UIBezierPath *dotPath = [UIBezierPath bezierPathWithArcCenter:CGPointMake(dotX, dotY) radius:kVolumeRingStrokeWidth * 0.8f startAngle:0 endAngle:2.0 * M_PI clockwise:YES];
        dotLayer.path = dotPath.CGPath;
        dotLayer.fillColor = [self colorWithAlpha:kAlphaEndDot].CGColor;
    } else {
        dotLayer.path = nil;
    }

    CGFloat innerRadius = baseRadius - kVolumeRingStrokeWidth * 0.5f;
    CGFloat outerRadius = baseRadius + kVolumeRingStrokeWidth * 0.5f;
    for (NSInteger i = 0; i < kVolumeRingTickCount; i++) {
        CAShapeLayer *tick = self.styleLayers[3 + i];
        CGFloat tickAngle = -90.0f + (i / (CGFloat)kVolumeRingTickCount) * 360.0f;
        CGFloat tickAngleRad = DegreesToRadians(tickAngle);
        CGFloat tickProgress = i / (CGFloat)kVolumeRingTickCount;
        CGFloat tickAlpha = tickProgress <= animatedLevel ? kAlphaTickActive : kAlphaTickInactive;
        CGFloat tickLength = (i % kVolumeRingMajorTickInterval == 0) ? kVolumeRingMajorTickLength : kVolumeRingMinorTickLength;
        CGFloat tickWidth = (i % kVolumeRingMajorTickInterval == 0) ? 2.0f : 1.0f;
        CGFloat startX = center.x + innerRadius * cos(tickAngleRad);
        CGFloat startY = center.y + innerRadius * sin(tickAngleRad);
        CGFloat endX = center.x + (outerRadius + tickLength) * cos(tickAngleRad);
        CGFloat endY = center.y + (outerRadius + tickLength) * sin(tickAngleRad);
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(startX, startY)];
        [path addLineToPoint:CGPointMake(endX, endY)];
        tick.path = path.CGPath;
        tick.strokeColor = [self colorWithAlpha:tickAlpha].CGColor;
        tick.lineWidth = tickWidth;
        tick.lineCap = kCALineCapRound;
    }

    CAShapeLayer *glowLayer = self.styleLayers.lastObject;
    CGFloat glowRadius = baseRadius * kVolumeRingInnerGlowRadiusFactor * animatedLevel;
    if (glowRadius > 0) {
        UIBezierPath *glowPath = [UIBezierPath bezierPathWithArcCenter:center radius:glowRadius startAngle:0 endAngle:2.0 * M_PI clockwise:YES];
        glowLayer.path = glowPath.CGPath;
        glowLayer.fillColor = [self colorWithAlpha:kAlphaInnerGlow * animatedLevel].CGColor;
    } else {
        glowLayer.path = nil;
    }
}

#pragma mark - Ripple

- (void)buildRippleLayers {
    for (NSInteger i = 0; i < kRippleRingCount; i++) {
        CAShapeLayer *ring = [CAShapeLayer layer];
        ring.frame = self.bounds;
        ring.fillColor = [UIColor clearColor].CGColor;
        [self.layer addSublayer:ring];
        [self.styleLayers addObject:ring];
    }
    for (NSInteger i = 0; i < kRippleBarCount; i++) {
        CAShapeLayer *bar = [CAShapeLayer layer];
        bar.frame = self.bounds;
        bar.lineCap = kCALineCapRound;
        [self.layer addSublayer:bar];
        [self.styleLayers addObject:bar];
    }
    for (NSInteger i = 0; i < kRippleGlowSteps; i++) {
        CAShapeLayer *glow = [CAShapeLayer layer];
        glow.frame = self.bounds;
        [self.layer addSublayer:glow];
        [self.styleLayers addObject:glow];
    }
}

- (void)updateRipple {
    CGFloat baseRadius = [self baseRadius];
    CGPoint center = [self centerPoint];
    CGFloat audioLevel = self.currentAudioLevel;
    CGFloat wavePhase = self.phase;

    for (NSInteger i = 0; i < kRippleRingCount; i++) {
        CAShapeLayer *ring = self.styleLayers[i];
        CGFloat waveRadius = baseRadius * (0.5f + i * 0.15f * audioLevel);
        CGFloat alpha = (kAlphaRingBase - i * kAlphaRingDecrement) * audioLevel;
        alpha = fmaxf(0.0f, fminf(alpha, 1.0f));
        CGFloat width = kRippleRingWidthBase - i * 0.7f;
        if (width < 1.0f) width = 1.0f;
        UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:center radius:waveRadius startAngle:0 endAngle:2.0 * M_PI clockwise:YES];
        ring.path = path.CGPath;
        ring.strokeColor = [self colorWithAlpha:alpha].CGColor;
        ring.lineWidth = width;
    }

    NSInteger barOffset = kRippleRingCount;
    CGFloat innerRadius = baseRadius * kRippleBaseInnerRadius;
    for (NSInteger i = 0; i < kRippleBarCount; i++) {
        CAShapeLayer *bar = self.styleLayers[barOffset + i];
        CGFloat angle = (i / (CGFloat)kRippleBarCount) * 360.0f + wavePhase;
        CGFloat radians = DegreesToRadians(angle);
        CGFloat dynamicLevel = audioLevel * (0.4f + 0.6f * sin(angle * 0.08f + wavePhase * 0.025f));
        CGFloat barHeight = baseRadius * kRippleBarHeightFactor * dynamicLevel;
        CGFloat startX = center.x + innerRadius * cos(radians);
        CGFloat startY = center.y + innerRadius * sin(radians);
        CGFloat endX = center.x + (innerRadius + barHeight) * cos(radians);
        CGFloat endY = center.y + (innerRadius + barHeight) * sin(radians);
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(startX, startY)];
        [path addLineToPoint:CGPointMake(endX, endY)];
        bar.path = path.CGPath;
        bar.strokeColor = [self colorWithAlpha:kAlphaBarBase * audioLevel].CGColor;
        bar.lineWidth = 3.0f;
    }

    NSInteger glowOffset = barOffset + kRippleBarCount;
    for (NSInteger i = 0; i < kRippleGlowSteps; i++) {
        CAShapeLayer *glow = self.styleLayers[glowOffset + i];
        CGFloat progress = i / (CGFloat)kRippleGlowSteps;
        CGFloat glowRadius = baseRadius * 0.3f * (1.0f + progress * 0.5f);
        CGFloat alpha = self.glowAlpha * (1.0f - progress) * audioLevel;
        alpha = fmaxf(0.0f, fminf(alpha, 0.3f));
        UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:center radius:glowRadius startAngle:0 endAngle:2.0 * M_PI clockwise:YES];
        glow.path = path.CGPath;
        glow.fillColor = [self colorWithAlpha:alpha].CGColor;
    }
}

#pragma mark - Bars

- (void)buildBarsLayers {
    for (NSInteger i = 0; i < kBarsCount; i++) {
        CAShapeLayer *bar = [CAShapeLayer layer];
        bar.frame = self.bounds;
        bar.lineCap = kCALineCapRound;
        [self.layer addSublayer:bar];
        [self.styleLayers addObject:bar];
    }
    CAShapeLayer *glow = [CAShapeLayer layer];
    glow.frame = self.bounds;
    [self.layer addSublayer:glow];
    [self.styleLayers addObject:glow];
}

- (void)updateBars {
    CGFloat baseRadius = [self baseRadius];
    CGPoint center = [self centerPoint];
    CGFloat audioLevel = self.currentAudioLevel;
    CGFloat wavePhase = self.phase;

    CGFloat innerRadius = baseRadius * kBarsInnerRadiusFactor;
    for (NSInteger i = 0; i < kBarsCount; i++) {
        CAShapeLayer *bar = self.styleLayers[i];
        CGFloat angle = (i / (CGFloat)kBarsCount) * 360.0f;
        CGFloat radians = DegreesToRadians(angle);
        CGFloat normalizedAngle = fmod(angle + wavePhase, 360.0f);
        CGFloat dynamicLevel = audioLevel * (0.3f + 0.7f * fabs(sin(normalizedAngle * 0.03f + wavePhase * 0.015f)));
        CGFloat barHeight = baseRadius * kBarsHeightFactor * dynamicLevel;
        CGFloat barWidth = 2.5f * (1.0f + dynamicLevel * 0.5f);
        CGFloat startX = center.x + innerRadius * cos(radians);
        CGFloat startY = center.y + innerRadius * sin(radians);
        CGFloat endX = center.x + (innerRadius + barHeight) * cos(radians);
        CGFloat endY = center.y + (innerRadius + barHeight) * sin(radians);
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(startX, startY)];
        [path addLineToPoint:CGPointMake(endX, endY)];
        bar.path = path.CGPath;
        CGFloat alpha = fmaxf(0.0f, fminf(0.4f + dynamicLevel * 0.5f, 1.0f));
        bar.strokeColor = [self colorWithAlpha:alpha].CGColor;
        bar.lineWidth = barWidth;
    }

    CAShapeLayer *glow = self.styleLayers.lastObject;
    CGFloat innerGlowRadius = baseRadius * 0.3f;
    UIBezierPath *glowPath = [UIBezierPath bezierPathWithArcCenter:center radius:innerGlowRadius startAngle:0 endAngle:2.0 * M_PI clockwise:YES];
    glow.path = glowPath.CGPath;
    glow.fillColor = [self colorWithAlpha:audioLevel * kAlphaInnerGlow].CGColor;
}

#pragma mark - Wave

- (void)buildWaveLayers {
    for (NSInteger i = 0; i < kWaveCount; i++) {
        CAShapeLayer *wave = [CAShapeLayer layer];
        wave.frame = self.bounds;
        wave.fillColor = [UIColor clearColor].CGColor;
        [self.layer addSublayer:wave];
        [self.styleLayers addObject:wave];
    }
    CAShapeLayer *centerDot = [CAShapeLayer layer];
    centerDot.frame = self.bounds;
    [self.layer addSublayer:centerDot];
    [self.styleLayers addObject:centerDot];
}

- (void)updateWave {
    CGFloat baseRadius = [self baseRadius];
    CGPoint center = [self centerPoint];
    CGFloat audioLevel = self.currentAudioLevel;
    CGFloat wavePhase = self.phase;

    for (NSInteger waveIndex = 0; waveIndex < kWaveCount; waveIndex++) {
        CAShapeLayer *wave = self.styleLayers[waveIndex];
        CGFloat waveRadius = baseRadius * (kWaveBaseRadiusFactor + waveIndex * kWaveRadiusIncrement);
        CGFloat waveAmplitude = baseRadius * kWaveAmplitudeFactor * audioLevel * (1.0f - waveIndex * 0.25f);
        UIBezierPath *path = [UIBezierPath bezierPath];
        for (NSInteger i = 0; i <= kWaveSegments; i++) {
            CGFloat angle = (i / (CGFloat)kWaveSegments) * 360.0f;
            CGFloat radians = DegreesToRadians(angle);
            CGFloat waveOffset = waveAmplitude * sin(angle * 0.1f + wavePhase * 0.05f + waveIndex * 1.5f);
            CGFloat r = waveRadius + waveOffset;
            CGFloat x = center.x + r * cos(radians);
            CGFloat y = center.y + r * sin(radians);
            if (i == 0) {
                [path moveToPoint:CGPointMake(x, y)];
            } else {
                [path addLineToPoint:CGPointMake(x, y)];
            }
        }
        [path closePath];
        wave.path = path.CGPath;
        CGFloat alpha = (0.5f - waveIndex * 0.12f) * audioLevel;
        alpha = fmaxf(0.0f, fminf(alpha, 1.0f));
        wave.strokeColor = [self colorWithAlpha:alpha].CGColor;
        wave.lineWidth = 3.0f - waveIndex * 0.5f;
    }

    CAShapeLayer *centerDot = self.styleLayers.lastObject;
    CGFloat centerRadius = baseRadius * kWaveCenterRadiusFactor;
    UIBezierPath *dotPath = [UIBezierPath bezierPathWithArcCenter:center radius:centerRadius startAngle:0 endAngle:2.0 * M_PI clockwise:YES];
    centerDot.path = dotPath.CGPath;
    centerDot.fillColor = [self colorWithAlpha:audioLevel * kAlphaInnerGlow].CGColor;
}

#pragma mark - Glow

- (void)buildGlowLayers {
    for (NSInteger i = 0; i < kGlowLayers; i++) {
        CAShapeLayer *glow = [CAShapeLayer layer];
        glow.frame = self.bounds;
        [self.layer addSublayer:glow];
        [self.styleLayers addObject:glow];
    }
    CAShapeLayer *core = [CAShapeLayer layer];
    core.frame = self.bounds;
    [self.layer addSublayer:core];
    [self.styleLayers addObject:core];
    for (NSInteger i = 0; i < kGlowRayCount; i++) {
        CAShapeLayer *ray = [CAShapeLayer layer];
        ray.frame = self.bounds;
        ray.lineCap = kCALineCapRound;
        [self.layer addSublayer:ray];
        [self.styleLayers addObject:ray];
    }
}

- (void)updateGlow {
    CGFloat baseRadius = [self baseRadius];
    CGPoint center = [self centerPoint];
    CGFloat audioLevel = self.currentAudioLevel;
    CGFloat glowAlpha = self.glowAlpha;
    CGFloat breathScale = self.breathScale;

    for (NSInteger i = 0; i < kGlowLayers; i++) {
        CAShapeLayer *glow = self.styleLayers[i];
        CGFloat progress = i / (CGFloat)kGlowLayers;
        CGFloat glowRadius = baseRadius * (0.2f + progress * 0.6f) * (1.0f + audioLevel * 0.3f) * breathScale;
        CGFloat alpha = (glowAlpha * (1.0f - progress * 0.8f) * audioLevel);
        alpha = fmaxf(0.0f, fminf(alpha, kAlphaGlowMax));
        UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:center radius:glowRadius startAngle:0 endAngle:2.0 * M_PI clockwise:YES];
        glow.path = path.CGPath;
        glow.fillColor = [self colorWithAlpha:alpha].CGColor;
    }

    NSInteger coreIndex = kGlowLayers;
    CAShapeLayer *core = self.styleLayers[coreIndex];
    CGFloat coreRadius = baseRadius * kGlowCoreRadiusFactor * (1.0f + audioLevel * 0.5f);
    UIBezierPath *corePath = [UIBezierPath bezierPathWithArcCenter:center radius:coreRadius startAngle:0 endAngle:2.0 * M_PI clockwise:YES];
    core.path = corePath.CGPath;
    core.fillColor = [self colorWithAlpha:kAlphaCore * audioLevel].CGColor;

    for (NSInteger i = 0; i < kGlowRayCount; i++) {
        CAShapeLayer *ray = self.styleLayers[coreIndex + 1 + i];
        CGFloat angle = (i / (CGFloat)kGlowRayCount) * 360.0f;
        CGFloat radians = DegreesToRadians(angle);
        CGFloat rayLength = baseRadius * kGlowRayLengthFactor * audioLevel;
        CGFloat endX = center.x + rayLength * cos(radians);
        CGFloat endY = center.y + rayLength * sin(radians);
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:center];
        [path addLineToPoint:CGPointMake(endX, endY)];
        ray.path = path.CGPath;
        ray.strokeColor = [self colorWithAlpha:kAlphaRay * audioLevel].CGColor;
        ray.lineWidth = 2.0f;
    }
}

#pragma mark - Particles

- (void)buildParticlesLayers {
    for (NSInteger i = 0; i < kParticlesCount; i++) {
        CAShapeLayer *particle = [CAShapeLayer layer];
        particle.frame = self.bounds;
        [self.layer addSublayer:particle];
        [self.styleLayers addObject:particle];

        CAShapeLayer *trail = [CAShapeLayer layer];
        trail.frame = self.bounds;
        trail.lineCap = kCALineCapRound;
        [self.layer addSublayer:trail];
        [self.styleLayers addObject:trail];
    }
    CAShapeLayer *centerGlow = [CAShapeLayer layer];
    centerGlow.frame = self.bounds;
    [self.layer addSublayer:centerGlow];
    [self.styleLayers addObject:centerGlow];
}

- (void)updateParticles {
    CGFloat baseRadius = [self baseRadius];
    CGPoint center = [self centerPoint];
    CGFloat audioLevel = self.currentAudioLevel;
    CGFloat wavePhase = self.phase;

    for (NSInteger i = 0; i < kParticlesCount; i++) {
        CGFloat baseAngle = (i / (CGFloat)kParticlesCount) * 360.0f;
        CGFloat angleOffset = sin(wavePhase * 0.02f + i * 0.5f) * 15.0f;
        CGFloat angle = baseAngle + angleOffset;
        CGFloat radians = DegreesToRadians(angle);
        CGFloat distanceVariation = sin(wavePhase * 0.03f + i * 0.3f) * 0.3f;
        CGFloat baseDistance = baseRadius * (kParticlesBaseDistanceFactor + distanceVariation);
        CGFloat distance = baseDistance * (0.5f + audioLevel * 0.8f);
        CGFloat x = center.x + distance * cos(radians);
        CGFloat y = center.y + distance * sin(radians);
        CGFloat particleSize = 3.0f + audioLevel * 4.0f * fabs(sin(wavePhase * 0.02f + i));
        CGFloat alpha = fmaxf(0.0f, fminf(kAlphaParticleBase + audioLevel * 0.5f, 1.0f));

        CAShapeLayer *particle = self.styleLayers[i * 2];
        UIBezierPath *pPath = [UIBezierPath bezierPathWithArcCenter:CGPointMake(x, y) radius:particleSize / 2.0f startAngle:0 endAngle:2.0 * M_PI clockwise:YES];
        particle.path = pPath.CGPath;
        particle.fillColor = [self colorWithAlpha:alpha].CGColor;

        CAShapeLayer *trail = self.styleLayers[i * 2 + 1];
        CGFloat trailLength = baseRadius * kParticlesTrailLengthFactor * audioLevel;
        CGFloat tx = x - trailLength * cos(radians);
        CGFloat ty = y - trailLength * sin(radians);
        UIBezierPath *tPath = [UIBezierPath bezierPath];
        [tPath moveToPoint:CGPointMake(x, y)];
        [tPath addLineToPoint:CGPointMake(tx, ty)];
        trail.path = tPath.CGPath;
        trail.strokeColor = [self colorWithAlpha:alpha * 0.5f].CGColor;
        trail.lineWidth = 1.5f;
    }

    CAShapeLayer *centerGlow = self.styleLayers.lastObject;
    CGFloat glowRadius = baseRadius * kParticlesCenterGlowRadiusFactor;
    UIBezierPath *glowPath = [UIBezierPath bezierPathWithArcCenter:center radius:glowRadius startAngle:0 endAngle:2.0 * M_PI clockwise:YES];
    centerGlow.path = glowPath.CGPath;
    centerGlow.fillColor = [self colorWithAlpha:audioLevel * kAlphaInnerGlow].CGColor;
}

@end
