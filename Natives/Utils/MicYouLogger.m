#import "MicYouLogger.h"

@interface MicYouLogger ()
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) dispatch_queue_t logQueue;
@end

@implementation MicYouLogger

+ (instancetype)sharedLogger {
    static MicYouLogger *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _logQueue = dispatch_queue_create("com.lanrhyme.micyou.logger", DISPATCH_QUEUE_SERIAL);
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
        
        NSString *logPath = [self logFilePath];
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:logPath]) {
            [fm createFileAtPath:logPath contents:nil attributes:nil];
        }
        _fileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
        [_fileHandle seekToEndOfFile];
    }
    return self;
}

- (NSString *)logFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documents = [paths firstObject];
    return [documents stringByAppendingPathComponent:@"micyou.log"];
}

- (void)log:(NSString *)message {
    dispatch_async(self.logQueue, ^{
        if (!self.fileHandle) {
            return;
        }
        NSString *timestamp = [self.dateFormatter stringFromDate:[NSDate date]];
        NSString *line = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];
        NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
        [self.fileHandle writeData:data];
    });
}

- (void)closeFile {
    dispatch_sync(self.logQueue, ^{
        [self.fileHandle closeFile];
        self.fileHandle = nil;
    });
}

- (void)reopenFile {
    dispatch_sync(self.logQueue, ^{
        if (self.fileHandle) {
            return;
        }
        NSString *logPath = [self logFilePath];
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:logPath]) {
            [fm createFileAtPath:logPath contents:nil attributes:nil];
        }
        self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
        [self.fileHandle seekToEndOfFile];
    });
}

- (void)logError:(NSString *)message {
    [self log:[NSString stringWithFormat:@"ERROR: %@", message]];
}

- (void)dealloc {
    [self.fileHandle closeFile];
}

@end
