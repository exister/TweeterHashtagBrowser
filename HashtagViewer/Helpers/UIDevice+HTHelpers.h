//
//  UIDevice+HTHelpers.h
//  HashtagViewer
//
//  Created by Mikhail Kuznetsov on 01.02.14.
//  Copyright (c) 2014 mkuznetsov. All rights reserved.
//

#define IS_IOS7 ([UIDevice deviceSystemMajorVersion] >= 7)

@interface UIDevice (HTHelpers)

+ (NSInteger)deviceSystemMajorVersion;

@end
