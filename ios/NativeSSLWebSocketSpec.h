#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>

NS_ASSUME_NONNULL_BEGIN

@protocol NativeSSLWebSocketSpec <NSObject>

- (void)createWebSocket:(NSString *)wsId
                    url:(NSString *)url
              protocols:(NSArray<NSString *> * _Nullable)protocols
              sslConfig:(NSDictionary * _Nullable)sslConfig
                options:(NSDictionary * _Nullable)options
               resolver:(RCTPromiseResolveBlock)resolve
               rejecter:(RCTPromiseRejectBlock)reject;

- (void)closeWebSocket:(NSString *)wsId
              resolver:(RCTPromiseResolveBlock)resolve
              rejecter:(RCTPromiseRejectBlock)reject;

- (void)sendData:(NSString *)wsId
            data:(NSString *)data
        resolver:(RCTPromiseResolveBlock)resolve
        rejecter:(RCTPromiseRejectBlock)reject;

- (void)getReadyState:(NSString *)wsId
             resolver:(RCTPromiseResolveBlock)resolve
             rejecter:(RCTPromiseRejectBlock)reject;

- (void)getSSLValidationResult:(NSString *)wsId
                      resolver:(RCTPromiseResolveBlock)resolve
                      rejecter:(RCTPromiseRejectBlock)reject;

- (void)cleanup:(RCTPromiseResolveBlock)resolve
       rejecter:(RCTPromiseRejectBlock)reject;

- (void)addListener:(NSString *)eventName;

- (void)removeListeners:(double)count;

@end

NS_ASSUME_NONNULL_END
