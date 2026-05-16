#import <Foundation/Foundation.h>

@interface AudioBufferQueue : NSObject

@property (nonatomic, readonly) NSUInteger count;
@property (nonatomic, readonly) NSUInteger capacity;

- (instancetype)initWithCapacity:(NSUInteger)capacity;
- (void)enqueue:(NSData *)data timestamp:(uint64_t)timestamp;
- (NSData *)dequeue;
- (void)clear;

@end
