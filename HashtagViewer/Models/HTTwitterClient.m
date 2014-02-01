//
//  HTTwitterClient.m
//  HashtagViewer
//
//  Created by Mikhail Kuznetsov on 01.02.14.
//  Copyright (c) 2014 mkuznetsov. All rights reserved.
//

#import "HTTwitterClient.h"

static NSString * const HTConsumerKey = @"cF38h2B2Jg5N7NVK5lx5ZA";
static NSString * const HTConsumerSecret = @"N2iOoY7559me5fyEdD8u8Hbc0FLp3pOKObluQtulQ";
static NSString * const HTAuthTokenKey = @"HTAuthTokenKey";

static NSString * const charactersToBeEscapedInQueryString = @":/?&=;+!@#$()',*";

static NSString * base64EncodedStringFromString(NSString *string) {
    NSData *data = [NSData dataWithBytes:[string UTF8String] length:[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
    NSUInteger length = [data length];
    NSMutableData *mutableData = [NSMutableData dataWithLength:((length + 2) / 3) * 4];

    uint8_t *input = (uint8_t *)[data bytes];
    uint8_t *output = (uint8_t *)[mutableData mutableBytes];

    for (NSUInteger i = 0; i < length; i += 3) {
        NSUInteger value = 0;
        for (NSUInteger j = i; j < (i + 3); j++) {
            value <<= 8;
            if (j < length) {
                value |= (0xFF & input[j]);
            }
        }

        static uint8_t const kAFBase64EncodingTable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

        NSUInteger idx = (i / 3) * 4;
        output[idx + 0] = kAFBase64EncodingTable[(value >> 18) & 0x3F];
        output[idx + 1] = kAFBase64EncodingTable[(value >> 12) & 0x3F];
        output[idx + 2] = (i + 1) < length ? kAFBase64EncodingTable[(value >> 6)  & 0x3F] : '=';
        output[idx + 3] = (i + 2) < length ? kAFBase64EncodingTable[(value >> 0)  & 0x3F] : '=';
    }

    return [[NSString alloc] initWithData:mutableData encoding:NSASCIIStringEncoding];
}

typedef NS_ENUM(NSInteger, HTOperationState) {
    HTOperationPausedState      = -1,
    HTOperationReadyState       = 1,
    HTOperationExecutingState   = 2,
    HTOperationFinishedState    = 3,
};

static inline NSString * HTKeyPathFromOperationState(HTOperationState state) {
    switch (state) {
        case HTOperationReadyState:
            return @"isReady";
        case HTOperationExecutingState:
            return @"isExecuting";
        case HTOperationFinishedState:
            return @"isFinished";
        case HTOperationPausedState:
            return @"isPaused";
        default:
            return @"state";
    }
}

@interface HTTwitterClientOperation : NSOperation <NSURLConnectionDelegate, NSURLConnectionDataDelegate>
@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic, strong) NSURLResponse *response;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSMutableData *data;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSRecursiveLock *lock;
@property (nonatomic, strong) id responseObject;
@property (nonatomic, assign) HTOperationState state;
@end

@implementation HTTwitterClientOperation

+ (dispatch_queue_t)processingQueue {
    static dispatch_queue_t processingQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        processingQueue = dispatch_queue_create("processing", DISPATCH_QUEUE_CONCURRENT);
    });

    return processingQueue;
}

+ (void)networkRequestThreadEntryPoint {
    @autoreleasepool {
        [[NSThread currentThread] setName:@"HTTwitter"];

        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        [runLoop run];
    }
}

+ (NSThread *)networkRequestThread {
    static NSThread *_networkRequestThread = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _networkRequestThread = [[NSThread alloc] initWithTarget:self selector:@selector(networkRequestThreadEntryPoint) object:nil];
        [_networkRequestThread start];
    });

    return _networkRequestThread;
}

- (id)init {
    self = [super init];
    if (self) {
        self.lock = [[NSRecursiveLock alloc] init];
        self.state = HTOperationReadyState;
    }

    return self;
}

- (void)setState:(HTOperationState)state {
    [self.lock lock];
    NSString *oldStateKey = HTKeyPathFromOperationState(self.state);
    NSString *newStateKey = HTKeyPathFromOperationState(state);

    [self willChangeValueForKey:newStateKey];
    [self willChangeValueForKey:oldStateKey];
    _state = state;
    [self didChangeValueForKey:oldStateKey];
    [self didChangeValueForKey:newStateKey];
    [self.lock unlock];
}

- (BOOL)isPaused {
    return self.state == HTOperationPausedState;
}

- (BOOL)isReady {
    return self.state == HTOperationReadyState && [super isReady];
}

- (BOOL)isExecuting {
    return self.state == HTOperationExecutingState;
}

- (BOOL)isFinished {
    return self.state == HTOperationFinishedState;
}

- (BOOL)isConcurrent {
    return YES;
}

- (void)start {
    [self.lock lock];

    if ([self isCancelled]) {
        [self performSelector:@selector(cancelConnection) onThread:[[self class] networkRequestThread] withObject:nil waitUntilDone:NO modes:@[NSRunLoopCommonModes]];
    } else if ([self isReady]) {
        self.state = HTOperationExecutingState;

        [self performSelector:@selector(operationStart) onThread:[[self class] networkRequestThread] withObject:nil waitUntilDone:NO modes:@[NSRunLoopCommonModes]];
    }
    [self.lock unlock];
}

- (void)cancel {
    [self.lock lock];
    if (![self isFinished] && ![self isCancelled]) {
        [super cancel];

        if ([self isExecuting]) {
            [self performSelector:@selector(cancelConnection) onThread:[[self class] networkRequestThread] withObject:nil waitUntilDone:NO modes:@[NSRunLoopCommonModes]];
        }
    }
    [self.lock unlock];
}

- (void)cancelConnection {
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];

    if (![self isFinished]) {
        if (self.connection) {
            [self.connection cancel];
            [self performSelector:@selector(connection:didFailWithError:) withObject:self.connection withObject:error];
        } else {
            self.error = error;
            [self finish];
        }
    }
}

- (void)operationStart {
    [self.lock lock];

    if (![self isCancelled]) {
        self.connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self startImmediately:NO];

        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [self.connection scheduleInRunLoop:runLoop forMode:NSRunLoopCommonModes];

        [self.connection start];
    }

    [self.lock unlock];
}

- (void)finish {
    self.state = HTOperationFinishedState;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    self.error = error;
    [self finish];
    self.connection = nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.response = response;
    self.data = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.data appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self finish];
    self.connection = nil;
}

- (id)responseObject {
    if (!_responseObject && !self.error) {
        NSString *responseString = [[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding];
        if (responseString && ![responseString isEqualToString:@" "]) {
            self.data = [[responseString dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];

            NSError *serializationError = nil;
            if (self.data) {
                if ([self.data length] > 0) {
                    _responseObject = [NSJSONSerialization JSONObjectWithData:self.data options:0 error:&serializationError];
                }
            }
            else {
                serializationError = [NSError errorWithDomain:@"HTTwitter" code:NSURLErrorCannotDecodeContentData userInfo:nil];
            }

            if (serializationError) {
                self.error = serializationError;
            }
        }
    }

    return _responseObject;
}

- (void)setCompletionBlockWithSuccess:(void (^)(id response))successCallback error:(void (^)(NSError *error))errorCallback
{
    __typeof (&*self) __weak weakSelf = self;
    self.completionBlock = ^{
        __typeof (&*weakSelf) strongSelf = weakSelf;
        dispatch_async([strongSelf.class processingQueue], ^{
            if (strongSelf.error) {
                if (errorCallback) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        errorCallback(strongSelf.error);
                    });
                }
            } else {
                id responseObject = strongSelf.responseObject;
                if (strongSelf.error) {
                    if (errorCallback) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            errorCallback(strongSelf.error);
                        });
                    }
                } else {
                    if (successCallback) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            successCallback(responseObject);
                        });
                    }
                }
            }
        });
    };
}

@end



@interface HTTwitterClient ()
@property(nonatomic, strong) NSOperationQueue *operationQueue;

@property(nonatomic, copy) NSURL *baseURL;
@property(nonatomic, copy) NSString *authToken;
@end

@implementation HTTwitterClient

+ (instancetype)sharedInstance {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[[self class] alloc] init];
    });
    return sharedInstance;
}

- (id)init {
    self = [super init];
    if (self) {
        self.baseURL = [NSURL URLWithString:@"https://api.twitter.com"];
        self.operationQueue = [[NSOperationQueue alloc] init];
        self.authToken = [[NSUserDefaults standardUserDefaults] stringForKey:HTAuthTokenKey];
    }

    return self;
}

- (void)cancelAll {
    [self.operationQueue cancelAllOperations];
}

- (void)searchTweetsWithParameters:(NSDictionary *)parameters success:(void (^)(id response))successCallback error:(void (^)(NSError *error))errorCallback {
    [self GET:@"/1.1/search/tweets.json" parameters:parameters success:successCallback error:errorCallback requestSetup:nil];
}

- (BOOL)isAuthenticated {
    return self.authToken != nil;
}

- (void)authenticate:(void (^)(id response))successCallback error:(void (^)(NSError *error))errorCallback {
    NSDictionary *params = @{
            @"grant_type" : @"client_credentials"
    };

    __typeof (&*self) __weak weakSelf = self;
    [self POST:@"/oauth2/token" parameters:params success:^(id response) {
        __typeof (&*weakSelf) strongSelf = weakSelf;
        strongSelf.authToken = response[@"access_token"];
        successCallback(response);
    } error:^(NSError *error) {
        __typeof (&*weakSelf) strongSelf = weakSelf;
        strongSelf.authToken = nil;
        errorCallback(error);
    } requestSetup:^NSMutableURLRequest *(NSMutableURLRequest *request) {
        NSString *key = base64EncodedStringFromString([NSString stringWithFormat:@"%@:%@", HTConsumerKey, HTConsumerSecret]);
        [request addValue:[NSString stringWithFormat:@"Basic %@", key] forHTTPHeaderField:@"Authorization"];
        return request;
    }];
}

- (void)GET:(NSString *)url parameters:(NSDictionary *)parameters success:(void (^)(id response))successCallback error:(void (^)(NSError *error))errorCallback requestSetup:(NSMutableURLRequest * (^)(NSMutableURLRequest *request))requestSetup {
    NSMutableURLRequest *request = [self requestWithMethod:@"GET" URLString:[[NSURL URLWithString:url relativeToURL:self.baseURL] absoluteString] parameters:parameters error:nil];

    if (requestSetup) {
        request = requestSetup(request);
    }

    if (self.isAuthenticated) {
        [request addValue:[NSString stringWithFormat:@"Bearer %@", self.authToken] forHTTPHeaderField:@"Authorization"];
    }

    HTTwitterClientOperation *operation = [[HTTwitterClientOperation alloc] init];
    operation.request = request;
    [operation setCompletionBlockWithSuccess:successCallback error:errorCallback];
    [self.operationQueue addOperation:operation];
}

- (void)POST:(NSString *)url parameters:(NSDictionary *)parameters success:(void (^)(id response))successCallback error:(void (^)(NSError *error))errorCallback requestSetup:(NSMutableURLRequest * (^)(NSMutableURLRequest *request))requestSetup {
    NSMutableURLRequest *request = [self requestWithMethod:@"POST" URLString:[[NSURL URLWithString:url relativeToURL:self.baseURL] absoluteString] parameters:parameters error:nil];

    if (requestSetup) {
        request = requestSetup(request);
    }

    HTTwitterClientOperation *operation = [[HTTwitterClientOperation alloc] init];
    operation.request = request;
    [operation setCompletionBlockWithSuccess:successCallback error:errorCallback];
    [self.operationQueue addOperation:operation];
}

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method
                                 URLString:(NSString *)URLString
                                parameters:(NSDictionary *)parameters
                                     error:(NSError *__autoreleasing *)error
{
    NSURL *url = [NSURL URLWithString:URLString];

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:method];

    if (!parameters) {
        return request;
    }

    NSString *query = nil;
    query = [self queryStringFromParameters:parameters];

    if ([[[request HTTPMethod] uppercaseString] isEqualToString:@"GET"]) {
        request.URL = [NSURL URLWithString:[[request.URL absoluteString] stringByAppendingFormat:request.URL.query ? @"&%@" : @"?%@", query]];
    } else {
        NSString *charset = (__bridge NSString *)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
        [request setValue:[NSString stringWithFormat:@"application/x-www-form-urlencoded; charset=%@", charset] forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:[query dataUsingEncoding:NSUTF8StringEncoding]];
    }

    return request;
}

- (NSString *)queryStringFromParameters:(NSDictionary *)parameters {
    NSMutableArray *mutablePairs = [NSMutableArray array];

    for (NSString *key in parameters) {
        [mutablePairs addObject:[NSString stringWithFormat:@"%@=%@", [self percentEscapedQueryStringKeyFromString:key], [self percentEscapedQueryStringValueFromString:parameters[key]]]];
    }

    return [mutablePairs componentsJoinedByString:@"&"];
}

- (NSString *)percentEscapedQueryStringKeyFromString:(NSString *)string {
    static NSString * const charactersToLeaveUnescapedInQueryStringPairKey = @"[].";

    return (__bridge_transfer  NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)string, (__bridge CFStringRef)charactersToLeaveUnescapedInQueryStringPairKey, (__bridge CFStringRef)charactersToBeEscapedInQueryString, CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
}

- (NSString * )percentEscapedQueryStringValueFromString:(NSString *)string {
    return (__bridge_transfer  NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)string, NULL, (__bridge CFStringRef)charactersToBeEscapedInQueryString, CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
}

- (void)setAuthToken:(NSString *)authToken {
    _authToken = [authToken copy];
    [[NSUserDefaults standardUserDefaults] setObject:_authToken forKey:HTAuthTokenKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
