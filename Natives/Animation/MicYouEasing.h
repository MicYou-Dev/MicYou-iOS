#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Custom easing functions matching Android's EasingFunctions.kt
@interface MicYouEasing : NSObject

/// Returns a CGFloat value representing position at time t (0.0 - 1.0)
+ (CGFloat)easeOutExpo:(CGFloat)t;
+ (CGFloat)easeInExpo:(CGFloat)t;
+ (CGFloat)easeInOutExpo:(CGFloat)t;
+ (CGFloat)easeInOutCubic:(CGFloat)t;
+ (CGFloat)easeOutBack:(CGFloat)t;
+ (CGFloat)easeInOutBack:(CGFloat)t;
+ (CGFloat)easeOutElastic:(CGFloat)t;
+ (CGFloat)easeOutBounce:(CGFloat)t;
+ (CGFloat)easeOutQuart:(CGFloat)t;
+ (CGFloat)easeOutCirc:(CGFloat)t;

/// Create a CAKeyframeAnimation with custom easing for a given keyPath
/// @param keyPath The layer property to animate (e.g., @"position.x", @"opacity")
/// @param fromValue Starting NSNumber value
/// @param toValue Ending NSNumber value
/// @param duration Animation duration in seconds
/// @param easingBlock Block that takes progress (0.0-1.0) and returns eased progress (0.0-1.0)
+ (CAKeyframeAnimation *)keyframeAnimationWithKeyPath:(NSString *)keyPath
                                            fromValue:(CGFloat)fromValue
                                              toValue:(CGFloat)toValue
                                             duration:(CFTimeInterval)duration
                                          easingBlock:(CGFloat (^)(CGFloat t))easingBlock;

@end

NS_ASSUME_NONNULL_END