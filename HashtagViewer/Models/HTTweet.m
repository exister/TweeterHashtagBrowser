//
//  HTTweet.m
//  HashtagViewer
//
//  Created by Mikhail Kuznetsov on 01.02.14.
//  Copyright (c) 2014 mkuznetsov. All rights reserved.
//

#import "HTTweet.h"
#import "HTTwitterClient.h"

@interface HTTweet()
@property (nonatomic, copy) NSDictionary *data;
@end

@implementation HTTweet

+ (instancetype)tweetWithDictionary:(NSDictionary *)dictionary {
    id tweet = [[self alloc] init];
    ((HTTweet *)tweet).data = dictionary;
    return tweet;
}

+ (void)loadTweetsWithHashTag:(NSString *)hashTag maxId:(NSString *)maxId successCallback:(void (^)(id response))successCallback errorCallback:(void (^)(NSError *error))errorCallback {
    NSDictionary *params = @{
            @"q": [NSString stringWithFormat:@"#%@", hashTag],
            @"result_type": @"recent",
            @"count": @"20",
            @"max_id": maxId ? maxId : @"",
    };

    [[HTTwitterClient sharedInstance] searchTweetsWithParameters:params success:successCallback error:errorCallback];
}

- (NSString *)username {
    return self.data[@"user"][@"screen_name"];
}

- (NSString *)text {
    return self.data[@"text"];
}

@end
