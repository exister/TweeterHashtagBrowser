//
//  HTTweet.h
//  HashtagViewer
//
//  Created by Mikhail Kuznetsov on 01.02.14.
//  Copyright (c) 2014 mkuznetsov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HTTweet : NSObject

@property (nonatomic, readonly) NSString *text;
@property (nonatomic, readonly) NSString *username;

+ (instancetype)tweetWithDictionary:(NSDictionary *)dictionary;

+ (void)loadTweetsWithHashTag:(NSString *)hashTag maxId:(NSString *)maxId successCallback:(void (^)(id response))successCallback errorCallback:(void (^)(NSError *error))errorCallback;

@end
