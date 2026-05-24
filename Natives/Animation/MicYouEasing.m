#import "MicYouEasing.h"

@implementation MicYouEasing

#pragma mark - Easing Functions

+ (CGFloat)easeOutExpo:(CGFloat)t {
    return t == 1.0 ? 1.0 : 1.0 - pow(2.0, -10.0 * t);
}

+ (CGFloat)easeInExpo:(CGFloat)t {
    return t == 0.0 ? 0.0 : pow(2.0, 10.0 * t - 10.0);
}

+ (CGFloat)easeInOutExpo:(CGFloat)t {
    if (t == 0.0) return 0.0;
    if (t == 1.0) return 1.0;
    if (t < 0.5) {
        return pow(2.0, 20.0 * t - 10.0) / 2.0;
    } else {
        return (2.0 - pow(2.0, -20.0 * t + 10.0)) / 2.0;
    }
}

+ (CGFloat)easeInOutCubic:(CGFloat)t {
    if (t < 0.5) {
        return 4.0 * t * t * t;
    } else {
        return 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0;
    }
}

+ (CGFloat)easeOutBack:(CGFloat)t {
    static CGFloat c1 = 1.70158;
    static CGFloat c3 = 2.70158; // c1 + 1
    return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0);
}

+ (CGFloat)easeInOutBack:(CGFloat)t {
    static CGFloat c1 = 1.70158;
    static CGFloat c2 = 2.5949095; // c1 * 1.525
    if (t < 0.5) {
        return (pow(2.0 * t, 2.0) * ((c2 + 1.0) * 2.0 * t - c2)) / 2.0;
    } else {
        return (pow(2.0 * t - 2.0, 2.0) * ((c2 + 1.0) * (t * 2.0 - 2.0) + c2) + 2.0) / 2.0;
    }
}

+ (CGFloat)easeOutElastic:(CGFloat)t {
    if (t == 0.0 || t == 1.0) return t;
    return pow(2.0, -10.0 * t) * sin((t * 10.0 - 0.75) * (2.0 * M_PI) / 3.0) + 1.0;
}

+ (CGFloat)easeOutBounce:(CGFloat)t {
    static CGFloat n1 = 7.5625;
    static CGFloat d1 = 2.75;

    if (t < 1.0 / d1) {
        return n1 * t * t;
    } else if (t < 2.0 / d1) {
        t -= 1.5 / d1;
        return n1 * t * t + 0.75;
    } else if (t < 2.5 / d1) {
        t -= 2.25 / d1;
        return n1 * t * t + 0.9375;
    } else {
        t -= 2.625 / d1;
        return n1 * t * t + 0.984375;
    }
}

+ (CGFloat)easeOutQuart:(CGFloat)t {
    return 1.0 - pow(1.0 - t, 4.0);
}

+ (CGFloat)easeOutCirc:(CGFloat)t {
    return sqrt(1.0 - pow(t - 1.0, 2.0));
}

#pragma mark - Keyframe Animation

+ (CAKeyframeAnimation *)keyframeAnimationWithKeyPath:(NSString *)keyPath
                                            fromValue:(CGFloat)fromValue
                                              toValue:(CGFloat)toValue
                                             duration:(CFTimeInterval)duration
                                          easingBlock:(CGFloat (^)(CGFloat t))easingBlock {
    NSInteger frameCount = 60;
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:frameCount];
    NSMutableArray *keyTimes = [NSMutableArray arrayWithCapacity:frameCount];

    CGFloat range = toValue - fromValue;

    for (NSInteger i = 0; i <= frameCount; i++) {
        CGFloat rawProgress = (CGFloat)i / (CGFloat)frameCount;
        CGFloat easedProgress = easingBlock(rawProgress);
        CGFloat value = fromValue + range * easedProgress;

        [values addObject:@(value)];
        [keyTimes addObject:@(rawProgress)];
    }

    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:keyPath];
    animation.values = values;
    animation.keyTimes = keyTimes;
    animation.duration = duration;
    animation.calculationMode = kCAAnimationLinear;

    return animation;
}

@end