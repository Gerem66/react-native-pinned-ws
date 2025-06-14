#import "SSLWebSocketModule.h"
#import "SSLWebSocketConnection.h"
#import <React/RCTLog.h>

@interface SSLWebSocketModule ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, SSLWebSocketConnection *> *connections;
@end

@implementation SSLWebSocketModule

RCT_EXPORT_MODULE(SSLWebSocket)

// Force module initialization to ensure event emitter is ready
+ (BOOL)requiresMainQueueSetup {
    return YES;
}

// Required for RCTBridgeModule protocol compliance
- (dispatch_queue_t)methodQueue {
    return dispatch_get_main_queue();
}

// Bridge property synthesis for RCTBridgeModule
@synthesize bridge = _bridge;

- (instancetype)init {
    self = [super init];
    if (self) {
        _connections = [[NSMutableDictionary alloc] init];
        _eventQueues = [[NSMutableDictionary alloc] init];
    }
    return self;
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
    
    // Initialize event queue for this WebSocket
    self.eventQueues[wsId] = [[NSMutableArray alloc] init];
    
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
            [self.eventQueues removeObjectForKey:wsId];
            
            // Check if this is an SSL pinning error
            NSString *errorCode = @"connection_failed";
            if ([error.userInfo[@"errorType"] isEqualToString:@"ssl_pinning"] || 
                [error.localizedDescription.lowercaseString containsString:@"ssl"] ||
                [error.localizedDescription.lowercaseString containsString:@"pinning"] ||
                [error.localizedDescription.lowercaseString containsString:@"certificate"]) {
                errorCode = @"ssl_pinning_failed";
            }
            
            reject(errorCode, error.localizedDescription, error);
        } else {
            resolve(nil);
        }
    }];
}

RCT_EXPORT_METHOD(pollEvents:(NSString *)wsId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    
    NSMutableArray *eventQueue = self.eventQueues[wsId];
    if (!eventQueue) {
        resolve(@[]);
        return;
    }
    
    // Return all events and clear the queue
    NSArray *events = [eventQueue copy];
    [eventQueue removeAllObjects];
    
    resolve(events);
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
        [self.eventQueues removeObjectForKey:wsId];
    }
    
    resolve(nil);
}

// Required for event emitter functionality (even if we don't use it directly)
- (NSArray<NSString *> *)supportedEvents {
    return @[];
}

// Required for listener management
RCT_EXPORT_METHOD(addListener:(NSString *)eventName) {
    // This is required for RCTEventEmitter compatibility
    // We don't use it but React Native expects it
}

RCT_EXPORT_METHOD(removeListeners:(NSInteger)count) {
    // This is required for RCTEventEmitter compatibility
    // We don't use it but React Native expects it
}

#pragma mark - SSLWebSocketConnectionDelegate

- (void)webSocketConnection:(SSLWebSocketConnection *)connection
                       wsId:(NSString *)wsId
                didReceiveEvent:(NSDictionary *)event {
    
    NSMutableArray *eventQueue = self.eventQueues[wsId];
    if (!eventQueue) {
        return;
    }
    
    NSMutableDictionary *eventData = [event mutableCopy];
    eventData[@"id"] = wsId;
    eventData[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);
    
    
    // Add event to queue (thread-safe)
    @synchronized(eventQueue) {
        [eventQueue addObject:eventData];
    }
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
        @"reason": reason ?: @"",
        @"timestamp": @([[NSDate date] timeIntervalSince1970])
    };
    
    NSMutableArray *eventQueue = self.eventQueues[wsId];
    if (eventQueue) {
        @synchronized(eventQueue) {
            [eventQueue addObject:event];
        }
    }
}

@end
