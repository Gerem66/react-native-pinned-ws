//
//  SSLWebSocketModule.m
//  react-native-ssl-websocket
//
//  Created by GameLife Team on 2025-06-06.
//

#import "SSLWebSocketModule.h"
#import "SSLWebSocketConnection.h"
#import <React/RCTLog.h>

@interface SSLWebSocketModule ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, SSLWebSocketConnection *> *connections;
@end

@implementation SSLWebSocketModule

RCT_EXPORT_MODULE(SSLWebSocket)

- (instancetype)init {
    self = [super init];
    if (self) {
        _connections = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (NSArray<NSString *> *)supportedEvents {
    return @[@"SSLWebSocket_Event"];
}

RCT_EXPORT_METHOD(createWebSocket:(NSString *)wsId
                  url:(NSString *)url
                  protocols:(NSArray<NSString *> * _Nullable)protocols
                  sslConfig:(NSDictionary * _Nullable)sslConfig
                  options:(NSDictionary * _Nullable)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    
    if (self.connections[wsId]) {
        reject(@"websocket_exists", @"WebSocket with this ID already exists", nil);
        return;
    }
    
    NSURL *wsURL = [NSURL URLWithString:url];
    if (!wsURL) {
        reject(@"invalid_url", @"Invalid WebSocket URL", nil);
        return;
    }
    
    SSLWebSocketConnection *connection = [[SSLWebSocketConnection alloc] initWithURL:wsURL
                                                                           protocols:protocols
                                                                           sslConfig:sslConfig
                                                                             options:options
                                                                            delegate:self
                                                                                wsId:wsId];
    
    self.connections[wsId] = connection;
    
    [connection connect:^(NSError * _Nullable error) {
        if (error) {
            [self.connections removeObjectForKey:wsId];
            reject(@"connection_failed", error.localizedDescription, error);
        } else {
            resolve(nil);
        }
    }];
}

RCT_EXPORT_METHOD(closeWebSocket:(NSString *)wsId
                  code:(NSNumber * _Nullable)code
                  reason:(NSString * _Nullable)reason
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    
    SSLWebSocketConnection *connection = self.connections[wsId];
    if (!connection) {
        reject(@"websocket_not_found", @"WebSocket not found", nil);
        return;
    }
    
    [connection closeWithCode:code.integerValue reason:reason];
    resolve(nil);
}

RCT_EXPORT_METHOD(sendData:(NSString *)wsId
                  data:(NSString *)data
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    
    SSLWebSocketConnection *connection = self.connections[wsId];
    if (!connection) {
        reject(@"websocket_not_found", @"WebSocket not found", nil);
        return;
    }
    
    NSError *error;
    BOOL success = [connection sendData:data error:&error];
    
    if (success) {
        resolve(nil);
    } else {
        reject(@"send_failed", error.localizedDescription, error);
    }
}

RCT_EXPORT_METHOD(getReadyState:(NSString *)wsId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    
    SSLWebSocketConnection *connection = self.connections[wsId];
    if (!connection) {
        reject(@"websocket_not_found", @"WebSocket not found", nil);
        return;
    }
    
    resolve(@([connection readyState]));
}

RCT_EXPORT_METHOD(getSSLValidationResult:(NSString *)wsId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    
    SSLWebSocketConnection *connection = self.connections[wsId];
    if (!connection) {
        reject(@"websocket_not_found", @"WebSocket not found", nil);
        return;
    }
    
    NSDictionary *result = [connection sslValidationResult];
    resolve(result);
}

RCT_EXPORT_METHOD(cleanup:(NSString *)wsId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    
    SSLWebSocketConnection *connection = self.connections[wsId];
    if (connection) {
        [connection cleanup];
        [self.connections removeObjectForKey:wsId];
    }
    
    resolve(nil);
}

#pragma mark - SSLWebSocketConnectionDelegate

- (void)webSocketConnection:(SSLWebSocketConnection *)connection
                       wsId:(NSString *)wsId
                didReceiveEvent:(NSDictionary *)event {
    
    NSMutableDictionary *eventData = [event mutableCopy];
    eventData[@"id"] = wsId;
    
    [self sendEventWithName:@"SSLWebSocket_Event" body:eventData];
}

- (void)webSocketConnection:(SSLWebSocketConnection *)connection
                       wsId:(NSString *)wsId
                  didClose:(NSInteger)code
                    reason:(NSString *)reason {
    
    [self.connections removeObjectForKey:wsId];
    
    NSDictionary *event = @{
        @"id": wsId,
        @"type": @"close",
        @"code": @(code),
        @"reason": reason ?: @""
    };
    
    [self sendEventWithName:@"SSLWebSocket_Event" body:event];
}

// Don't compile this code when we build for the old architecture.
#ifdef RCT_NEW_ARCH_ENABLED
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeSSLWebSocketSpecJSI>(params);
}
#endif

@end
