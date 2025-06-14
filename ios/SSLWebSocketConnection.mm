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
    [self.webSocketTask cancelWithCloseCode:(NSURLSessionWebSocketCloseCode)code reason:reasonData];
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
    
    // Check if SSL Pinning is configured for WSS connections
    if (!self.sslConfig || (![self.url.scheme isEqualToString:@"wss"] && ![self.url.scheme isEqualToString:@"https"])) {
        // No SSL Pinning configured or not secure connection, use default validation
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        return;
    }
    
    // Ensure we have public key hashes to validate against
    NSArray *expectedHashes = self.sslConfig[@"publicKeyHashes"];
    if (!expectedHashes || expectedHashes.count == 0) {
        // No hashes configured, use default validation
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
        // SSL Pinning failed, forcefully reject connection
        completionHandler(NSURLSessionAuthChallengeRejectProtectionSpace, nil);
        
        // Update ready state to closed
        self.readyState = SSLWebSocketReadyStateClosed;
        
        // Notify delegate of SSL pinning error
        [self.delegate webSocketConnection:self
                                      wsId:self.wsId
                           didReceiveEvent:@{
            @"type": @"error",
            @"error": @"SSL Certificate pinning failed",
            @"errorType": @"ssl_pinning"
        }];
        
        // Also call completion handler with error if available
        if (self.connectionCompletion) {
            NSError *error = [NSError errorWithDomain:@"SSLWebSocket" 
                                                 code:1003 
                                             userInfo:@{
                NSLocalizedDescriptionKey: @"SSL Certificate pinning failed",
                @"errorType": @"ssl_pinning"
            }];
            self.connectionCompletion(error);
            self.connectionCompletion = nil;
        }
        
        // Force cleanup to ensure connection is terminated
        [self cleanup];
    }
}

- (BOOL)validateSSLPinning:(NSURLAuthenticationChallenge *)challenge {
    // Get expected hashes from configuration
    NSArray *expectedHashes = self.sslConfig[@"publicKeyHashes"];
    if (!expectedHashes || expectedHashes.count == 0) {
        self.sslValidationInfo[@"error"] = @"No expected public key hashes configured";
        self.sslValidationInfo[@"success"] = @NO;
        return NO;
    }
    
    // Get server certificate
    SecTrustRef serverTrust = challenge.protectionSpace.serverTrust;
    if (!serverTrust) {
        self.sslValidationInfo[@"error"] = @"No server trust available";
        self.sslValidationInfo[@"success"] = @NO;
        return NO;
    }
    
    // Get leaf certificate (first certificate in chain)
    SecCertificateRef certificate = SecTrustGetCertificateAtIndex(serverTrust, 0);
    if (!certificate) {
        self.sslValidationInfo[@"error"] = @"No certificate available at index 0";
        self.sslValidationInfo[@"success"] = @NO;
        return NO;
    }
    
    // Extract public key using the same format as Android (SubjectPublicKeyInfo DER)
    SecKeyRef publicKey = SecTrustCopyPublicKey(serverTrust);
    if (!publicKey) {
        self.sslValidationInfo[@"error"] = @"Failed to extract public key from certificate";
        self.sslValidationInfo[@"success"] = @NO;
        return NO;
    }
    
    // Get public key data in raw format
    CFDataRef rawKeyData = SecKeyCopyExternalRepresentation(publicKey, NULL);
    CFRelease(publicKey);
    
    if (!rawKeyData) {
        self.sslValidationInfo[@"error"] = @"Failed to get public key data";
        self.sslValidationInfo[@"success"] = @NO;
        return NO;
    }
    
    NSData *rawKey = (__bridge NSData *)rawKeyData;
    
    // Get public key attributes to determine the key type
    NSDictionary *attributes = (__bridge NSDictionary *)SecKeyCopyAttributes(publicKey);
    NSString *keyType = attributes[(__bridge NSString *)kSecAttrKeyType];
    
    // Construct SubjectPublicKeyInfo DER structure based on key type
    NSMutableData *subjectPublicKeyInfo = [NSMutableData data];
    
    unsigned char *algorithmIdentifier = NULL;
    size_t algorithmIdentifierLength = 0;
    
    if ([keyType isEqualToString:(__bridge NSString *)kSecAttrKeyTypeECSECPrimeRandom]) {
        // ECC key - secp256r1 (P-256) algorithm identifier
        static unsigned char eccAlgorithmIdentifier[] = {
            0x30, 0x13,                                                 // SEQUENCE (19 bytes)
            0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01,     // ECC OID
            0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07 // secp256r1 OID
        };
        algorithmIdentifier = eccAlgorithmIdentifier;
        algorithmIdentifierLength = sizeof(eccAlgorithmIdentifier);
    } else {
        // RSA key algorithm identifier
        static unsigned char rsaAlgorithmIdentifier[] = {
            0x30, 0x0d,                                                 // SEQUENCE (13 bytes)
            0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, // RSA OID
            0x05, 0x00                                                  // NULL
        };
        algorithmIdentifier = rsaAlgorithmIdentifier;
        algorithmIdentifierLength = sizeof(rsaAlgorithmIdentifier);
    }
    
    // Calculate the total length for the outer SEQUENCE
    NSUInteger bitStringLength = rawKey.length + 1; // +1 for the unused bits byte
    NSUInteger contentLength = algorithmIdentifierLength + 1 + (bitStringLength >= 0x80 ? 3 : 1) + bitStringLength;
    
    // Outer SEQUENCE header
    unsigned char sequenceHeader = 0x30;
    [subjectPublicKeyInfo appendBytes:&sequenceHeader length:1];
    
    // Encode length
    if (contentLength >= 0x80) {
        unsigned char lengthBytes[] = {0x82, (unsigned char)((contentLength >> 8) & 0xFF), (unsigned char)(contentLength & 0xFF)};
        [subjectPublicKeyInfo appendBytes:lengthBytes length:3];
    } else {
        unsigned char lengthByte = (unsigned char)(contentLength & 0xFF);
        [subjectPublicKeyInfo appendBytes:&lengthByte length:1];
    }
    
    // Algorithm identifier
    [subjectPublicKeyInfo appendBytes:algorithmIdentifier length:algorithmIdentifierLength];
    
    // BIT STRING header
    unsigned char bitStringHeader = 0x03;
    [subjectPublicKeyInfo appendBytes:&bitStringHeader length:1];
    
    // BIT STRING length
    if (bitStringLength >= 0x80) {
        unsigned char bitStringLengthBytes[] = {0x82, (unsigned char)((bitStringLength >> 8) & 0xFF), (unsigned char)(bitStringLength & 0xFF)};
        [subjectPublicKeyInfo appendBytes:bitStringLengthBytes length:3];
    } else {
        unsigned char bitStringLengthByte = (unsigned char)(bitStringLength & 0xFF);
        [subjectPublicKeyInfo appendBytes:&bitStringLengthByte length:1];
    }
    
    // Unused bits (always 0 for RSA)
    unsigned char unusedBits = 0x00;
    [subjectPublicKeyInfo appendBytes:&unusedBits length:1];
    
    // The actual public key data
    [subjectPublicKeyInfo appendData:rawKey];
    
    CFRelease(rawKeyData);
    
    NSData *keyData = subjectPublicKeyInfo;
    
    // Calculate SHA256 hash of SubjectPublicKeyInfo (same as Android)
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(keyData.bytes, (CC_LONG)keyData.length, digest);
    NSData *sha256 = [NSData dataWithBytes:digest length:CC_SHA256_DIGEST_LENGTH];
    
    // Convert to base64
    NSString *publicKeyHash = [sha256 base64EncodedStringWithOptions:0];
    
    // Store validation information
    NSString *hostname = challenge.protectionSpace.host;
    
    self.sslValidationInfo[@"hostname"] = hostname;
    self.sslValidationInfo[@"foundKeyHash"] = publicKeyHash;
    self.sslValidationInfo[@"expectedKeyHashes"] = expectedHashes;
    
    // Check if hash matches one of the expected hashes
    BOOL isValid = [expectedHashes containsObject:publicKeyHash];
    
    self.sslValidationInfo[@"success"] = @(isValid);
    
    if (!isValid) {
        NSString *errorMessage = @"Public key hash does not match expected values";
        self.sslValidationInfo[@"error"] = errorMessage;
        NSLog(@"SSLWebSocket: SSL Pinning validation failed for hostname: %@", hostname);
    }
    
    return isValid;
}

@end
