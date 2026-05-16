#import <UIKit/UIKit.h>

@class MicYouAudioCapture;
@class TransportClient;

@interface MainViewController : UIViewController

@property (nonatomic, strong, readonly) MicYouAudioCapture *audioCapture;
@property (nonatomic, strong, readonly) TransportClient *transportClient;

- (void)updateConnectionStatus:(NSString *)status;
- (void)updateAudioLevel:(float)level;

@end
