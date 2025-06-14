//
//  SSLWebSocketModule.h
//  react-native-pinned-ws
//
//  Created by GameLife Team on 2025-06-06.
//

#import <React/RCTBridgeModule.h>
#import <React/RCTEventDispatcher.h>
#import "SSLWebSocketConnection.h"

@interface SSLWebSocketModule : NSObject <RCTBridgeModule, SSLWebSocketConnectionDelegate>

@property (nonatomic, weak) RCTBridge *bridge;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray *> *eventQueues;

@end
