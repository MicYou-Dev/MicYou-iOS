#import "MicYouServiceDiscovery.h"
#import "MicYouLogger.h"

static NSString * const kMicYouServiceType = @"_micyou._tcp.";
// Bonjour scans should be performed on a single domain — the empty string
// denotes the default registration domain (local.).
static NSString * const kMicYouServiceDomain = @"";

@interface MicYouServiceDiscovery () <NSNetServiceBrowserDelegate, NSNetServiceDelegate>
@property (nonatomic, strong, nullable) NSNetServiceBrowser *browser;
// Services that have been fully resolved and are currently visible.
@property (nonatomic, strong) NSMutableArray<NSNetService *> *resolvedServices;
// Services whose address resolution is still in flight. We retain them here
// because NSNetServiceBrowser does not keep a strong reference after the
// didFindService callback returns.
@property (nonatomic, strong) NSMutableArray<NSNetService *> *pendingServices;
// Set of service names currently being resolved, used to avoid scheduling
// duplicate resolves for the same name.
@property (nonatomic, strong) NSMutableSet<NSString *> *pendingResolution;
@property (nonatomic, assign) BOOL scanning;
@end

@implementation MicYouServiceDiscovery

+ (instancetype)shared {
    static MicYouServiceDiscovery *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MicYouServiceDiscovery alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _resolvedServices = [[NSMutableArray alloc] init];
        _pendingServices = [[NSMutableArray alloc] init];
        _pendingResolution = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void)startScanning {
    if (self.scanning) {
        return;
    }
    [self.resolvedServices removeAllObjects];
    [self.pendingServices removeAllObjects];
    [self.pendingResolution removeAllObjects];

    self.browser = [[NSNetServiceBrowser alloc] init];
    self.browser.delegate = self;
    [self.browser searchForServicesOfType:kMicYouServiceType inDomain:kMicYouServiceDomain];
    self.scanning = YES;
    [[MicYouLogger sharedLogger] log:[NSString stringWithFormat:@"ServiceDiscovery: started scanning %@", kMicYouServiceType]];
}

- (void)stopScanning {
    if (!self.scanning) {
        return;
    }
    [self.browser stop];
    self.browser.delegate = nil;
    self.browser = nil;

    // Detach delegates for any in-flight resolves so we get no more callbacks
    // after the user explicitly stopped scanning.
    NSArray<NSNetService *> *pending = [self.pendingServices copy];
    for (NSNetService *service in pending) {
        service.delegate = nil;
    }
    [self.pendingServices removeAllObjects];
    [self.pendingResolution removeAllObjects];
    self.scanning = NO;
    [[MicYouLogger sharedLogger] log:@"ServiceDiscovery: stopped scanning"];

    if ([self.delegate respondsToSelector:@selector(serviceDiscoveryDidStopScanning:)]) {
        id<MicYouServiceDiscoveryDelegate> delegate = self.delegate;
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate serviceDiscoveryDidStopScanning:self];
        });
    }
}

#pragma mark - NSNetServiceBrowserDelegate

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser
           didFindService:(NSNetService *)service
               moreComing:(BOOL)moreComing {
    NSString *name = service.name;
    @synchronized (self.pendingResolution) {
        if ([self.pendingResolution containsObject:name]) {
            return;
        }
        [self.pendingResolution addObject:name];
    }

    @synchronized (self.pendingServices) {
        [self.pendingServices addObject:service];
    }
    service.delegate = self;
    [service resolveWithTimeout:5.0];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser
         didRemoveService:(NSNetService *)service
               moreComing:(BOOL)moreComing {
    NSString *name = service.name;
    @synchronized (self.pendingResolution) {
        [self.pendingResolution removeObject:name];
    }

    NSNetService *removed = nil;
    @synchronized (self.resolvedServices) {
        NSUInteger idx = NSNotFound;
        for (NSUInteger i = 0; i < self.resolvedServices.count; i++) {
            if ([self.resolvedServices[i].name isEqualToString:name]) {
                idx = i;
                break;
            }
        }
        if (idx != NSNotFound) {
            removed = self.resolvedServices[idx];
            [self.resolvedServices removeObjectAtIndex:idx];
        }
    }

    // Drop any pending resolve for the same name as well.
    @synchronized (self.pendingServices) {
        NSUInteger idx = NSNotFound;
        for (NSUInteger i = 0; i < self.pendingServices.count; i++) {
            if ([self.pendingServices[i].name isEqualToString:name]) {
                idx = i;
                break;
            }
        }
        if (idx != NSNotFound) {
            self.pendingServices[idx].delegate = nil;
            [self.pendingServices removeObjectAtIndex:idx];
        }
    }

    if (removed && [self.delegate respondsToSelector:@selector(serviceDiscovery:didLoseService:)]) {
        NSNetService *callbackService = removed;
        id<MicYouServiceDiscoveryDelegate> delegate = self.delegate;
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate serviceDiscovery:self didLoseService:callbackService];
        });
    }
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)browser {
    self.scanning = NO;
    [self.pendingResolution removeAllObjects];
    [self.pendingServices removeAllObjects];
    if ([self.delegate respondsToSelector:@selector(serviceDiscoveryDidStopScanning:)]) {
        id<MicYouServiceDiscoveryDelegate> delegate = self.delegate;
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate serviceDiscoveryDidStopScanning:self];
        });
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser
 didNotSearch:(NSDictionary<NSString *, NSNumber *> *)errorDict {
    [[MicYouLogger sharedLogger] logError:
        [NSString stringWithFormat:@"ServiceDiscovery: search failed %@", errorDict]];
    self.scanning = NO;
}

#pragma mark - NSNetServiceDelegate

- (void)netServiceDidResolveAddress:(NSNetService *)sender {
    @synchronized (self.pendingResolution) {
        [self.pendingResolution removeObject:sender.name];
    }
    @synchronized (self.pendingServices) {
        NSUInteger idx = NSNotFound;
        for (NSUInteger i = 0; i < self.pendingServices.count; i++) {
            if (self.pendingServices[i] == sender) {
                idx = i;
                break;
            }
        }
        if (idx != NSNotFound) {
            [self.pendingServices removeObjectAtIndex:idx];
        }
    }

    @synchronized (self.resolvedServices) {
        // Replace any previously stored entry for the same name/port pair.
        for (NSNetService *existing in [self.resolvedServices copy]) {
            if ([existing.name isEqualToString:sender.name]
                && existing.port == sender.port) {
                [self.resolvedServices removeObject:existing];
                break;
            }
        }
        [self.resolvedServices addObject:sender];
    }

    [[MicYouLogger sharedLogger] log:
        [NSString stringWithFormat:@"ServiceDiscovery: resolved %@ @ %@:%ld",
            sender.name, sender.hostName, (long)sender.port]];

    if ([self.delegate respondsToSelector:@selector(serviceDiscovery:didFindService:)]) {
        NSNetService *callbackService = sender;
        id<MicYouServiceDiscoveryDelegate> delegate = self.delegate;
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate serviceDiscovery:self didFindService:callbackService];
        });
    }
}

- (void)netService:(NSNetService *)sender
 didNotResolve:(NSDictionary<NSString *, NSNumber *> *)errorDict {
    @synchronized (self.pendingResolution) {
        [self.pendingResolution removeObject:sender.name];
    }
    @synchronized (self.pendingServices) {
        NSUInteger idx = NSNotFound;
        for (NSUInteger i = 0; i < self.pendingServices.count; i++) {
            if (self.pendingServices[i] == sender) {
                idx = i;
                break;
            }
        }
        if (idx != NSNotFound) {
            [self.pendingServices removeObjectAtIndex:idx];
        }
    }
    [[MicYouLogger sharedLogger] logError:
        [NSString stringWithFormat:@"ServiceDiscovery: resolve failed for %@ %@", sender.name, errorDict]];
}

@end
