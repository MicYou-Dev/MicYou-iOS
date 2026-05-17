#import <Foundation/Foundation.h>

@interface MicYouLogger : NSObject

+ (instancetype)sharedLogger;
- (void)log:(NSString *)message;
- (void)logError:(NSString *)message;
- (NSString *)logFilePath;
- (void)closeFile;
- (void)reopenFile;

@end
