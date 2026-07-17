#import <UIKit/UIKit.h>
#import "TransportClient.h"
#import "MicYouAudioCapture.h"

NS_ASSUME_NONNULL_BEGIN

/// Stream state machine driving the main control card's visual presentation.
typedef NS_ENUM(NSInteger, MicYouStreamState) {
    MicYouStreamStateIdle = 0,
    MicYouStreamStateConnecting,
    MicYouStreamStateStreaming,
    MicYouStreamStateError
};

@interface MicYouViewController : UIViewController <TransportClientDelegate, MicYouAudioCaptureDelegate>

/// Update the visual stream state. Thread-safe; dispatches to the main queue.
- (void)updateStreamState:(MicYouStreamState)state;

@end

NS_ASSUME_NONNULL_END
