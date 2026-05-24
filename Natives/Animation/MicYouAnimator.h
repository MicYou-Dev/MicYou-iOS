#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Unified animation entry point matching Android's animation system
@interface MicYouAnimator : NSObject

/// Spring animation (matches Android's spring() with dampingRatio=0.6)
+ (void)animateSpringWithDuration:(NSTimeInterval)duration
                            delay:(NSTimeInterval)delay
                          damping:(CGFloat)dampingRatio
                  initialVelocity:(CGFloat)velocity
                       animations:(void (^)(void))animations
                       completion:(void (^ _Nullable)(BOOL finished))completion;

/// Animates a view sliding in from the right (for settings page)
+ (void)animateSlideInFromRight:(UIView *)view duration:(NSTimeInterval)duration;
+ (void)animateSlideOutToRight:(UIView *)view duration:(NSTimeInterval)duration completion:(void (^ _Nullable)(BOOL))completion;

/// Button press scale feedback (0.85x scale with spring back)
+ (void)animateButtonPress:(UIView *)view;
+ (void)animateButtonRelease:(UIView *)view;

/// Staggered entrance: animates views with increasing delay
/// @param views Array of UIView to animate
/// @param baseDelay Base delay in seconds (delta between each view)
/// @param direction 0=fromBottom, 1=fromRight
+ (void)animateStaggeredEntrance:(NSArray<UIView *> *)views
                       baseDelay:(NSTimeInterval)baseDelay
                       direction:(NSInteger)direction;

/// Pulse animation (continuous scale oscillation)
+ (void)animatePulse:(UIView *)view duration:(NSTimeInterval)duration;

@end

NS_ASSUME_NONNULL_END