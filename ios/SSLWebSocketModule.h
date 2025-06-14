#import <React/RCTBridgeModule.h>
#import <React/RCTEventDispatcher.h>
#import "SSLWebSocketConnection.h"

@interface SSLWebSocketModule : NSObject <RCTBridgeModule, SSLWebSocketConnectionDelegate>

@property (nonatomic, weak) RCTBridge *bridge;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray *> *eventQueues;

@end
