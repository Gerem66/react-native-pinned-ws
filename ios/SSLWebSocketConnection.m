//
//  SSLWebSocketConnection.m
//  react-native-ssl-websocket
//
//  Created by GameLife Team on 2025-06-06.
//

#import "SSLWebSocketConnection.h"
#import <Network/Network.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>

@interface SSLWebSocketConnection () <NSURLSessionWebSocketDelegate>

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionWebSocketTask *webSocketTask;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSArray<NSString *> *protocols;
@property (nonatomic, strong) NSDictionary *sslConfig;
@property (nonatomic, strong) NSDictionary *options;
@property (nonatomic, strong) NSString *wsId;
@property (nonatomic, assign) SSLWebSocketReadyState readyState;
@property (nonatomic, strong) NSMutableDictionary *sslValidationInfo;
@property (nonatomic, copy) void (^connectionCompletion)(NSError * _Nullable);

@end

@implementation SSLWebSocketConnection

- (instancetype)initWithURL:(NSURL *)url
                  protocols:(NSArray<NSString *> *)protocols
                  sslConfig:(NSDictionary *)sslConfig
                    options:(NSDictionary *)options
                   delegate:(id<SSLWebSocketConnectionDelegate>)delegate
                       wsId:(NSString *)wsId {
    self = [super init];
    if (self) {
        _url = url;
        _protocols = protocols;
        _sslConfig = sslConfig;
        _options = options;
        _delegate = delegate;
        _wsId = wsId;
        _readyState = SSLWebSocketReadyStateClosed;
        _sslValidationInfo = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)connect:(void (^)(NSError * _Nullable))completion {
    if (self.readyState != SSLWebSocketReadyStateClosed) {
        completion([NSError errorWithDomain:@"SSLWebSocket" 
                                       code:1001 
                                   userInfo:@{NSLocalizedDescriptionKey: @"WebSocket is not in CLOSED state"}]);
        return;
    }
    
    self.connectionCompletion = completion;
    self.readyState = SSLWebSocketReadyStateConnecting;
    
    // Configure session with SSL Pinning
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    // Custom headers
    if (self.options[@"headers"]) {
        config.HTTPAdditionalHeaders = self.options[@"headers"];
    }
    
    // Timeout
    if (self.options[@"connectionTimeout"]) {
        config.timeoutIntervalForRequest = [self.options[@"connectionTimeout"] doubleValue] / 1000.0;
    }
    
    self.session = [NSURLSession sessionWithConfiguration:config
                                                 delegate:self
                                            delegateQueue:nil];
    
    // Create WebSocket request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url];
    
    // Add protocols
    if (self.protocols.count > 0) {
        [request setValue:[self.protocols componentsJoinedByString:@", "] 
       forHTTPHeaderField:@"Sec-WebSocket-Protocol"];
    }
    
    // Create WebSocket task
    self.webSocketTask = [self.session webSocketTaskWithRequest:request];
    
    // Start connection
    [self.webSocketTask resume];
    
    // Start listening for messages
    [self receiveMessage];
}

- (void)closeWithCode:(NSInteger)code reason:(NSString *)reason {
    if (self.readyState == SSLWebSocketReadyStateClosed) {
        return;
    }
    
    self.readyState = SSLWebSocketReadyStateClosing;
    
    NSData *reasonData = reason ? [reason dataUsingEncoding:NSUTF8StringEncoding] : nil;
    [self.webSocketTask cancelWithCloseCode:code reason:reasonData];
}

- (BOOL)sendData:(NSString *)data error:(NSError **)error {
    if (self.readyState != SSLWebSocketReadyStateOpen) {
        if (error) {
            *error = [NSError errorWithDomain:@"SSLWebSocket" 
                                         code:1002 
                                     userInfo:@{NSLocalizedDescriptionKey: @"WebSocket is not in OPEN state"}];
        }
        return NO;
    }
    
    NSURLSessionWebSocketMessage *message = [[NSURLSessionWebSocketMessage alloc] 
                                           initWithString:data];
    
    [self.webSocketTask sendMessage:message completionHandler:^(NSError * _Nullable sendError) {
        if (sendError) {
            [self.delegate webSocketConnection:self
                                          wsId:self.wsId
                               didReceiveEvent:@{
                @"type": @"error",
                @"error": sendError.localizedDescription
            }];
        }
    }];
    
    return YES;
}

- (void)receiveMessage {
    if (self.readyState == SSLWebSocketReadyStateClosed) {
        return;
    }
    
    [self.webSocketTask receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage * _Nullable message, NSError * _Nullable error) {
        if (error) {
            [self.delegate webSocketConnection:self
                                          wsId:self.wsId
                               didReceiveEvent:@{
                @"type": @"error",
                @"error": error.localizedDescription
            }];
            return;
        }
        
        if (message) {
            NSString *messageData;
            if (message.type == NSURLSessionWebSocketMessageTypeString) {
                messageData = message.string;
            } else {
                // Convert binary data to base64
                messageData = [message.data base64EncodedStringWithOptions:0];
            }
            
            [self.delegate webSocketConnection:self
                                          wsId:self.wsId
                               didReceiveEvent:@{
                @"type": @"message",
                @"data": messageData
            }];
        }
        
        // Continue listening for next messages
        [self receiveMessage];
    }];
}

- (NSDictionary *)sslValidationResult {
    return [self.sslValidationInfo copy];
}

- (void)cleanup {
    [self.webSocketTask cancel];
    [self.session invalidateAndCancel];
    self.webSocketTask = nil;
    self.session = nil;
    self.readyState = SSLWebSocketReadyStateClosed;
}

#pragma mark - NSURLSessionWebSocketDelegate

- (void)URLSession:(NSURLSession *)session 
      webSocketTask:(NSURLSessionWebSocketTask *)webSocketTask 
 didOpenWithProtocol:(NSString *)protocol {
    
    self.readyState = SSLWebSocketReadyStateOpen;
    
    [self.delegate webSocketConnection:self
                                  wsId:self.wsId
                       didReceiveEvent:@{
        @"type": @"open",
        @"protocol": protocol ?: @""
    }];
    
    if (self.connectionCompletion) {
        self.connectionCompletion(nil);
        self.connectionCompletion = nil;
    }
}

- (void)URLSession:(NSURLSession *)session 
      webSocketTask:(NSURLSessionWebSocketTask *)webSocketTask 
  didCloseWithCode:(NSURLSessionWebSocketCloseCode)closeCode 
            reason:(NSData *)reason {
    
    self.readyState = SSLWebSocketReadyStateClosed;
    
    NSString *reasonString = reason ? [[NSString alloc] initWithData:reason encoding:NSUTF8StringEncoding] : @"";
    
    [self.delegate webSocketConnection:self
                                  wsId:self.wsId
                              didClose:closeCode
                                reason:reasonString];
}

#pragma mark - NSURLSessionDelegate (SSL Pinning)

- (void)URLSession:(NSURLSession *)session 
              task:(NSURLSessionTask *)task 
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge 
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler {
    
    // Check if SSL Pinning is configured
    if (!self.sslConfig || ![self.url.scheme isEqualToString:@"wss"]) {
        // No SSL Pinning configured or not HTTPS, use default validation
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        return;
    }
    
    // Perform SSL Pinning validation
    BOOL validationResult = [self validateSSLPinning:challenge];
    
    if (validationResult) {
        // SSL Pinning successful, accept connection
        NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    } else {
        // SSL Pinning failed, reject connection
        completionHandler(NSURLSessionAuthChallengeRejectProtectionSpace, nil);
        
        if (self.connectionCompletion) {
            NSError *error = [NSError errorWithDomain:@"SSLWebSocket" 
                                                 code:1003 
                                             userInfo:@{NSLocalizedDescriptionKey: @"SSL Certificate pinning failed"}];
            self.connectionCompletion(error);
            self.connectionCompletion = nil;
        }
    }
}

- (BOOL)validateSSLPinning:(NSURLAuthenticationChallenge *)challenge {
    // Get server certificate
    SecTrustRef serverTrust = challenge.protectionSpace.serverTrust;
    if (!serverTrust) {
        return NO;
    }
    
    // Get leaf certificate (first certificate in chain)
    SecCertificateRef certificate = SecTrustGetCertificateAtIndex(serverTrust, 0);
    if (!certificate) {
        return NO;
    }
    
    // Extract public key
    SecKeyRef publicKey = SecTrustCopyPublicKey(serverTrust);
    if (!publicKey) {
        return NO;
    }
    
    // Get public key data
    CFDataRef publicKeyData = SecKeyCopyExternalRepresentation(publicKey, NULL);
    CFRelease(publicKey);
    
    if (!publicKeyData) {
        return NO;
    }
    
    // Calculate SHA256 hash of public key
    NSData *keyData = (__bridge NSData *)publicKeyData;
    NSMutableData *sha256 = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(keyData.bytes, (CC_LONG)keyData.length, sha256.mutableBytes);
    CFRelease(publicKeyData);
    
    // Convert to base64
    NSString *publicKeyHash = [sha256 base64EncodedStringWithOptions:0];
    
    // Store validation information
    NSString *hostname = challenge.protectionSpace.host;
    NSArray *expectedHashes = self.sslConfig[@"publicKeyHashes"];
    
    self.sslValidationInfo[@"hostname"] = hostname;
    self.sslValidationInfo[@"foundKeyHash"] = publicKeyHash;
    self.sslValidationInfo[@"expectedKeyHashes"] = expectedHashes;
    
    // Check if hash matches one of the expected hashes
    BOOL isValid = [expectedHashes containsObject:publicKeyHash];
    
    self.sslValidationInfo[@"success"] = @(isValid);
    
    if (!isValid) {
        self.sslValidationInfo[@"error"] = @"Public key hash does not match expected values";
    }
    
    return isValid;
}

@end
