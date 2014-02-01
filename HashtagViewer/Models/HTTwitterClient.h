//
//  HTTwitterClient.h
//  HashtagViewer
//
//  Created by Mikhail Kuznetsov on 01.02.14.
//  Copyright (c) 2014 mkuznetsov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HTTwitterClient : NSObject

+ (instancetype)sharedInstance;

- (void)cancelAll;

- (void)searchTweetsWithParameters:(NSDictionary *)parameters success:(void (^)(id response))successCallback error:(void (^)(NSError *error))errorCallback;

- (BOOL)isAuthenticated;

- (void)authenticate:(void (^)(id response))successCallback error:(void (^)(NSError *error))errorCallback;

@end
