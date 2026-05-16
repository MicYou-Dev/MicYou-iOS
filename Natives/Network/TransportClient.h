#import <Foundation/Foundation.h>

@class TransportClient;

@protocol TransportClientDelegate <NSObject>

@optional
- (void)transportClientDidConnect:(TransportClient *)client;
- (void)transportClientDidDisconnect:(TransportClient *)client;
- (void)transportClient:(TransportClient *)client didReceiveData:(NSData *)data;
- (void)transportClient:(TransportClient *)client didReceiveError:(NSError *)error;

@end

@interface TransportClient : NSObject

@property (nonatomic, weak) id<TransportClientDelegate> delegate;
@property (nonatomic, readonly) BOOL isConnected;
@property (nonatomic, readonly) NSString *host;
@property (nonatomic, readonly) int port;

- (void)connectToHost:(NSString *)host port:(int)port completion:(void (^)(BOOL success))completion;
- (void)disconnect;
- (void)sendAudioData:(NSData *)data timestamp:(uint64_t)timestamp;
- (void)sendControlMessage:(NSData *)data;

@end
