#import <UIKit/UIKit.h>
#import "TransportClient.h"
#import "MicYouAudioCapture.h"

NS_ASSUME_NONNULL_BEGIN

@interface MicYouViewController : UIViewController <TransportClientDelegate, MicYouAudioCaptureDelegate>

@end

NS_ASSUME_NONNULL_END