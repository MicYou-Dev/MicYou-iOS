#import "AudioBufferQueue.h"

@interface AudioBufferItem : NSObject
@property (nonatomic, strong) NSData *data;
@property (nonatomic, assign) uint64_t timestamp;
@end

@implementation AudioBufferItem
@end

@interface AudioBufferQueue ()

@property (nonatomic, strong) NSMutableArray<AudioBufferItem *> *items;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, assign, readwrite) NSUInteger capacity;
@property (nonatomic, assign, readwrite) NSUInteger count;

@end

@implementation AudioBufferQueue

- (instancetype)initWithCapacity:(NSUInteger)capacity {
    self = [super init];
    if (self) {
        _capacity = capacity;
        _items = [[NSMutableArray alloc] initWithCapacity:capacity];
        _queue = dispatch_queue_create("com.lanrhyme.micyou.bufferqueue", DISPATCH_QUEUE_SERIAL);
        _count = 0;
    }
    return self;
}

- (void)enqueue:(NSData *)data timestamp:(uint64_t)timestamp {
    if (!data || data.length == 0) return;

    dispatch_sync(self.queue, ^{
        AudioBufferItem *item = [[AudioBufferItem alloc] init];
        item.data = data;
        item.timestamp = timestamp;

        [self.items addObject:item];
        if (self.items.count > self.capacity) {
            [self.items removeObjectAtIndex:0];
        }
        self.count = self.items.count;
    });
}

- (NSData *)dequeue {
    __block NSData *data = nil;
    dispatch_sync(self.queue, ^{
        if (self.items.count > 0) {
            AudioBufferItem *item = [self.items objectAtIndex:0];
            data = item.data;
            [self.items removeObjectAtIndex:0];
            self.count = self.items.count;
        }
    });
    return data;
}

- (void)clear {
    dispatch_sync(self.queue, ^{
        [self.items removeAllObjects];
        self.count = 0;
    });
}

@end
