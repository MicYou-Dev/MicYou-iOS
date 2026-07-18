#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MicYouServiceDiscovery;
@class NSNetService;

@protocol MicYouServiceDiscoveryDelegate <NSObject>
- (void)serviceDiscovery:(MicYouServiceDiscovery *)discovery didFindService:(NSNetService *)service;
- (void)serviceDiscovery:(MicYouServiceDiscovery *)discovery didLoseService:(NSNetService *)service;
- (void)serviceDiscoveryDidStopScanning:(MicYouServiceDiscovery *)discovery;
@end

/**
 * MicYouServiceDiscovery scans the local network for MicYou desktop hosts
 * published via Bonjour / mDNS under the service type "_micyou._tcp.".
 *
 * The found/lost callbacks are delivered on the main thread. Each found
 * service is resolved before being forwarded so that the delegate can read
 * hostName / port directly from the NSNetService object.
 */
@interface MicYouServiceDiscovery : NSObject

@property (nonatomic, weak, nullable) id<MicYouServiceDiscoveryDelegate> delegate;

+ (instancetype)shared;

- (void)startScanning;
- (void)stopScanning;

@end

NS_ASSUME_NONNULL_END
