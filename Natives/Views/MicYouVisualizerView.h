#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, MicYouVisualizerStyle) {
    MicYouVisualizerStyleVolumeRing,
    MicYouVisualizerStyleRipple,
    MicYouVisualizerStyleBars,
    MicYouVisualizerStyleWave,
    MicYouVisualizerStyleGlow,
    MicYouVisualizerStyleParticles
};

@interface MicYouVisualizerView : UIView
@property (nonatomic, assign) MicYouVisualizerStyle style;
@property (nonatomic, assign) float audioLevel;
@property (nonatomic, strong) UIColor *visualizerColor;
- (void)updateWithLevel:(float)level;
- (void)setStyle:(MicYouVisualizerStyle)style animated:(BOOL)animated;
@end
