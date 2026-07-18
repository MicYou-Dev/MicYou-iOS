#import "MicYouLogExporter.h"
#import "MicYouLogger.h"

@implementation MicYouLogExporter

+ (instancetype)shared {
    static MicYouLogExporter *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MicYouLogExporter alloc] init];
    });
    return instance;
}

- (void)exportLogFromViewController:(UIViewController *)viewController {
    if (!viewController) {
        return;
    }

    NSString *sourcePath = [[MicYouLogger sharedLogger] logFilePath];
    if (sourcePath.length == 0) {
        [[MicYouLogger sharedLogger] logError:@"LogExporter: log file path is empty"];
        return;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:sourcePath]) {
        [[MicYouLogger sharedLogger] logError:@"LogExporter: log file does not exist"];
        return;
    }

    // Copy into NSTemporaryDirectory() so the share sheet can read the file
    // without exposing the app's Documents directory.
    NSString *tempName = [NSString stringWithFormat:@"micyou-%@.log",
                          [[NSDate date] descriptionWithLocale:nil]];
    // Sanitize the filename — NSDate description contains characters that are
    // not filesystem-safe (spaces, colons).
    NSCharacterSet *invalid = [NSCharacterSet characterSetWithCharactersInString:@"/\\: "];
    tempName = [[tempName componentsSeparatedByCharactersInSet:invalid] componentsJoinedByString:@"-"];
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:tempName];

    // Remove any stale copy at the destination.
    if ([fm fileExistsAtPath:tempPath]) {
        [fm removeItemAtPath:tempPath error:nil];
    }

    NSError *copyError = nil;
    if (![fm copyItemAtPath:sourcePath toPath:tempPath error:&copyError]) {
        [[MicYouLogger sharedLogger] logError:
            [NSString stringWithFormat:@"LogExporter: copy failed %@",
                copyError.localizedDescription]];
        return;
    }

    NSURL *fileURL = [NSURL fileURLWithPath:tempPath];
    UIActivityViewController *activityVC =
        [[UIActivityViewController alloc] initWithActivityItems:@[fileURL]
                                          applicationActivities:nil];

    // iPad requires a popoverPresentationController anchor.
    if ([activityVC respondsToSelector:@selector(popoverPresentationController)]) {
        UIPopoverPresentationController *popover = activityVC.popoverPresentationController;
        if (popover) {
            popover.sourceView = viewController.view;
            popover.sourceRect = CGRectMake(viewController.view.bounds.size.width / 2.0,
                                            viewController.view.bounds.size.height / 2.0,
                                            1.0, 1.0);
            popover.permittedArrowDirections = 0;
        }
    }

    [viewController presentViewController:activityVC animated:YES completion:nil];
}

@end
