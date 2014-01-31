//
//  HTSearchViewController.m
//  HashtagViewer
//
//  Created by Mikhail Kuznetsov on 01.02.14.
//  Copyright (c) 2014 mkuznetsov. All rights reserved.
//

#import "HTSearchViewController.h"
#import "UIDevice+HTHelpers.h"
#import "HTSearchResultCell.h"

static NSString * const cellId = @"cellId";
static NSString * const loadingCellId = @"loadingCellId";

@interface HTSearchViewController ()
@end

@implementation HTSearchViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.

    if (IS_IOS7) {
        self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    }
    self.searchBar.searchTextPositionAdjustment = UIOffsetMake(20, 0);
    self.searchBar.delegate = self;

    self.hashTagLabel.hidden = YES;

    [self.tableView registerNib:[UINib nibWithNibName:@"HTSearchResultCell" bundle:nil] forCellReuseIdentifier:cellId];
    [self.tableView registerNib:[UINib nibWithNibName:@"HTLoadingCell" bundle:nil] forCellReuseIdentifier:loadingCellId];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITableViewDataSource

- (BOOL)isLoadingCell:(NSIndexPath *)indexPath {
    //TODO
    return indexPath.row == [self.tableView numberOfRowsInSection:indexPath.section] - 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2 + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isLoadingCell:indexPath]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:loadingCellId];

        return cell;
    }
    else {
        HTSearchResultCell *cell = (HTSearchResultCell *)[tableView dequeueReusableCellWithIdentifier:cellId];

        [self setupCell:cell];

        return cell;
    }
}

- (void)setupCell:(HTSearchResultCell *)cell {
    cell.usernameLabel.text = @"@ololo";
    cell.tweetLabel.text = @" Class AXEmojiUtilities is implemented in both /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator7.0.sdk/System/Library/PrivateFrameworks/AccessibilityUtilities.framework/AccessibilityUtilities and /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator7.0.sdk/usr/lib/libAXSpeechManager.dylib. One of the two will be used. Which one is undefined.\n"
            "2014-02-01 02:24:54.084 HashtagViewer[39477:70b] Cannot find executable for CFBundle 0x8a62b70 </Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator7.0.sdk/System/Library/AccessibilityBundles/CertUIFramework.axbundle> (not loaded)";
}

#pragma mark -

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    static HTSearchResultCell *stubCell;
    if ([self isLoadingCell:indexPath]) {
        if (stubCell == nil) {
            stubCell = (HTSearchResultCell *)[tableView dequeueReusableCellWithIdentifier:cellId];
        }
        [self setupCell:stubCell];
        [stubCell layoutIfNeeded];
        CGFloat height = [stubCell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
        return height + 1;
    }
    else {
        return 44;
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {

}

#pragma mark - UISearchBarDelegate

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    self.hashTagLabel.hidden = NO;
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    self.hashTagLabel.hidden = YES;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {

}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {

}


@end
