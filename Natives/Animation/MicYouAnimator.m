#import "MicYouAnimator.h"
#import "MicYouEasing.h"

@implementation MicYouAnimator

#pragma mark - Spring Animation

+ (void)animateSpringWithDuration:(NSTimeInterval)duration
                            delay:(NSTimeInterval)delay
                          damping:(CGFloat)dampingRatio
                  initialVelocity:(CGFloat)velocity
                       animations:(void (^)(void))animations
                       completion:(void (^ _Nullable)(BOOL finished))completion {
    UISpringTimingParameters *springParams = [[UISpringTimingParameters alloc]
        initWithDampingRatio:dampingRatio
            initialVelocity:CGVectorMake(velocity, velocity)];

    UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc]
        initWithDuration:duration
        timingParameters:springParams];

    if (animations) {
        [animator addAnimations:animations];
    }

    if (completion) {
        [animator addCompletion:^(UIViewAnimatingPosition finalPosition) {
            completion(finalPosition == UIViewAnimatingPositionEnd);
        }];
    }

    if (delay > 0) {
        [animator startAnimationAfterDelay:delay];
    } else {
        [animator startAnimation];
    }
}

#pragma mark - Slide Animations

+ (void)animateSlideInFromRight:(UIView *)view duration:(NSTimeInterval)duration {
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;

    view.transform = CGAffineTransformMakeTranslation(screenWidth, 0);
    view.alpha = 0.0;

    UISpringTimingParameters *springParams = [[UISpringTimingParameters alloc]
        initWithDampingRatio:0.6
            initialVelocity:CGVectorMake(0, 0)];

    UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc]
        initWithDuration:duration
        timingParameters:springParams];

    [animator addAnimations:^{
        view.transform = CGAffineTransformIdentity;
        view.alpha = 1.0;
    }];

    [animator startAnimation];
}

+ (void)animateSlideOutToRight:(UIView *)view duration:(NSTimeInterval)duration completion:(void (^ _Nullable)(BOOL))completion {
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;

    [UIView animateWithDuration:duration
        delay:0
        options:UIViewAnimationOptionCurveEaseInOut
        animations:^{
            view.transform = CGAffineTransformMakeTranslation(screenWidth, 0);
            view.alpha = 0.0;
        }
        completion:^(BOOL finished) {
            if (completion) {
                completion(finished);
            }
        }];
}

#pragma mark - Button Press/Release

+ (void)animateButtonPress:(UIView *)view {
    UISpringTimingParameters *springParams = [[UISpringTimingParameters alloc]
        initWithDampingRatio:0.8
            initialVelocity:CGVectorMake(0, 0)];

    UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc]
        initWithDuration:0.15
        timingParameters:springParams];

    [animator addAnimations:^{
        view.transform = CGAffineTransformMakeScale(0.85, 0.85);
    }];

    [animator startAnimation];
}

+ (void)animateButtonRelease:(UIView *)view {
    UISpringTimingParameters *springParams = [[UISpringTimingParameters alloc]
        initWithDampingRatio:0.6
            initialVelocity:CGVectorMake(0, 0)];

    UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc]
        initWithDuration:0.5
        timingParameters:springParams];

    [animator addAnimations:^{
        view.transform = CGAffineTransformIdentity;
    }];

    [animator startAnimation];
}

#pragma mark - Staggered Entrance

+ (void)animateStaggeredEntrance:(NSArray<UIView *> *)views
                       baseDelay:(NSTimeInterval)baseDelay
                       direction:(NSInteger)direction {
    CGFloat offsetX = 0;
    CGFloat offsetY = 0;

    if (direction == 0) {
        offsetY = 30.0;
    } else {
        offsetX = [UIScreen mainScreen].bounds.size.width;
    }

    [views enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) {
        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(offsetX, offsetY);

        NSTimeInterval delay = baseDelay * idx;

        UISpringTimingParameters *springParams = [[UISpringTimingParameters alloc]
            initWithDampingRatio:0.6
                initialVelocity:CGVectorMake(0, 0)];

        UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc]
            initWithDuration:0.5
            timingParameters:springParams];

        [animator addAnimations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        }];

        if (delay > 0) {
            [animator startAnimationAfterDelay:delay];
        } else {
            [animator startAnimation];
        }
    }];
}

#pragma mark - Pulse Animation

+ (void)animatePulse:(UIView *)view duration:(NSTimeInterval)duration {
    CAKeyframeAnimation *scaleAnimation = [MicYouEasing
        keyframeAnimationWithKeyPath:@"transform.scale"
                           fromValue:1.0
                             toValue:1.05
                            duration:duration / 2.0
                         easingBlock:^CGFloat(CGFloat t) {
                             return [MicYouEasing easeInOutCubic:t];
                         }];

    scaleAnimation.autoreverses = YES;
    scaleAnimation.repeatCount = HUGE_VALF;

    [view.layer addAnimation:scaleAnimation forKey:@"pulse"];
}

#pragma mark - Staggered Fade Up

+ (void)animateStaggeredFadeUp:(NSArray<UIView *> *)views
                        delays:(NSArray<NSNumber *> *)delays {
    NSUInteger count = MIN(views.count, delays.count);

    for (NSUInteger i = 0; i < count; i++) {
        UIView *view = views[i];
        NSTimeInterval delay = [delays[i] doubleValue];

        view.alpha = 0.0;
        view.transform = CGAffineTransformMakeTranslation(0, 30);

        // Alpha animation: 400ms easeOut
        [UIView animateWithDuration:0.4
                              delay:delay
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             view.alpha = 1.0;
                         }
                         completion:nil];

        // Translation animation: 500ms spring (matches Android spring damping 0.6)
        UISpringTimingParameters *springParams = [[UISpringTimingParameters alloc]
            initWithDampingRatio:0.6
                initialVelocity:CGVectorMake(0, 0)];

        UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc]
            initWithDuration:0.5
            timingParameters:springParams];

        [animator addAnimations:^{
            view.transform = CGAffineTransformIdentity;
        }];

        if (delay > 0) {
            [animator startAnimationAfterDelay:delay];
        } else {
            [animator startAnimation];
        }
    }
}

#pragma mark - Color Transition

+ (void)animateColorTransition:(UIView *)view
                       toColor:(UIColor *)color
                        keyPath:(NSString *)keyPath
                       duration:(NSTimeInterval)duration {
    id currentValue = [view.layer valueForKeyPath:keyPath];

    CABasicAnimation *colorAnimation = [CABasicAnimation animationWithKeyPath:keyPath];
    colorAnimation.fromValue = currentValue ?: (id)[UIColor clearColor].CGColor;
    colorAnimation.toValue = (id)color.CGColor;
    colorAnimation.duration = duration;
    colorAnimation.fillMode = kCAFillModeForwards;
    colorAnimation.removedOnCompletion = NO;
    colorAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

    [view.layer addAnimation:colorAnimation forKey:@"colorTransition"];

    // Set the final value on the layer so state is correct after animation
    [view.layer setValue:(id)color.CGColor forKeyPath:keyPath];
}

#pragma mark - Press Scale

+ (void)animatePressScale:(UIView *)view
                    scale:(CGFloat)scale {
    // Step 1: Scale down quickly with easeOut (~0.1s)
    [UIView animateWithDuration:0.1
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         view.transform = CGAffineTransformMakeScale(scale, scale);
                     }
                     completion:^(BOOL finished) {
                         // Step 2: Spring back to 1.0 (dampingRatio 0.75 ≈ Android DampingRatioHighBouncy)
                         UISpringTimingParameters *springParams = [[UISpringTimingParameters alloc]
                             initWithDampingRatio:0.75
                                 initialVelocity:CGVectorMake(0, 0)];

                         UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc]
                             initWithDuration:0.5
                             timingParameters:springParams];

                         [animator addAnimations:^{
                             view.transform = CGAffineTransformIdentity;
                         }];

                         [animator startAnimation];
                     }];
}

#pragma mark - Glow Pulse

+ (void)animateGlowPulse:(UIView *)view
               fromAlpha:(CGFloat)fromAlpha
                 toAlpha:(CGFloat)toAlpha
                duration:(NSTimeInterval)duration {
    CABasicAnimation *glowAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    glowAnimation.fromValue = @(fromAlpha);
    glowAnimation.toValue = @(toAlpha);
    glowAnimation.duration = duration;
    glowAnimation.autoreverses = YES;
    glowAnimation.repeatCount = HUGE_VALF;
    glowAnimation.removedOnCompletion = NO;
    glowAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

    [view.layer addAnimation:glowAnimation forKey:@"glowPulse"];
}

@end