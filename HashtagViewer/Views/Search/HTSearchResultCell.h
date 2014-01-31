//
//  HTSearchResultCell.h
//  HashtagViewer
//
//  Created by Mikhail Kuznetsov on 01.02.14.
//  Copyright (c) 2014 mkuznetsov. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HTSearchResultCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *usernameLabel;
@property (weak, nonatomic) IBOutlet UILabel *tweetLabel;

@end
