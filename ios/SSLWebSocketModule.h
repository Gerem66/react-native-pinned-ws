//
//  SSLWebSocketModule.h
//  react-native-pinned-ws
//
//  Created by GameLife Team on 2025-06-06.
//

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

#ifdef RCT_NEW_ARCH_ENABLED
#import "SSLWebSocketSpec.h"
#import <ReactCommon/RCTTurboModule.h>

@interface SSLWebSocketModule : RCTEventEmitter <NativeSSLWebSocketSpecJSI, RCTBridgeModule, RCTTurboModule>
#else
@interface SSLWebSocketModule : RCTEventEmitter <RCTBridgeModule>
#endif

@end
