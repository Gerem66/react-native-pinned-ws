//
//  SSLWebSocketConnection.h
//  react-native-pinned-ws
//
//  Created by GameLife Team on 2025-06-06.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SSLWebSocketReadyState) {
    SSLWebSocketReadyStateConnecting = 0,
    SSLWebSocketReadyStateOpen = 1,
    SSLWebSocketReadyStateClosing = 2,
    SSLWebSocketReadyStateClosed = 3,
};

@class SSLWebSocketConnection;

@protocol SSLWebSocketConnectionDelegate <NSObject>

- (void)webSocketConnection:(SSLWebSocketConnection *)connection
                       wsId:(NSString *)wsId
            didReceiveEvent:(NSDictionary *)event;

- (void)webSocketConnection:(SSLWebSocketConnection *)connection
                       wsId:(NSString *)wsId
                   didClose:(NSInteger)code
                     reason:(NSString * _Nullable)reason;

@end

@interface SSLWebSocketConnection : NSObject

@property (nonatomic, readonly) SSLWebSocketReadyState readyState;
@property (nonatomic, weak) id<SSLWebSocketConnectionDelegate> delegate;

- (instancetype)initWithURL:(NSURL *)url
                  protocols:(NSArray<NSString *> * _Nullable)protocols
                  sslConfig:(NSDictionary * _Nullable)sslConfig
                    options:(NSDictionary * _Nullable)options
                   delegate:(id<SSLWebSocketConnectionDelegate>)delegate
                       wsId:(NSString *)wsId;

- (void)connect:(void (^)(NSError * _Nullable error))completion;
- (void)closeWithCode:(NSInteger)code reason:(NSString * _Nullable)reason;
- (BOOL)sendData:(NSString *)data error:(NSError **)error;
- (NSDictionary * _Nullable)sslValidationResult;
- (void)cleanup;

@end

NS_ASSUME_NONNULL_END
