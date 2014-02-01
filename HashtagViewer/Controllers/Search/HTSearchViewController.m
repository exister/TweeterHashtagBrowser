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
#import "HTTweet.h"
#import "HTTwitterClient.h"

static NSString * const cellId = @"cellId";
static NSString * const loadingCellId = @"loadingCellId";

@interface HTSearchViewController ()
@property(nonatomic, strong) NSMutableArray *data;
@property(nonatomic) BOOL loadNext;
@property(nonatomic, copy) NSString *maxId;
@property(nonatomic, strong) UIView *loader;
@end

@implementation HTSearchViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.

    self.data = [NSMutableArray array];
    self.loadNext = NO;

    if (IS_IOS7) {
        self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    }
    self.searchBar.searchTextPositionAdjustment = UIOffsetMake(20, 0);
    self.searchBar.delegate = self;

    self.hashTagLabel.hidden = YES;

    [self.tableView registerNib:[UINib nibWithNibName:@"HTSearchResultCell" bundle:nil] forCellReuseIdentifier:cellId];
    [self.tableView registerNib:[UINib nibWithNibName:@"HTLoadingCell" bundle:nil] forCellReuseIdentifier:loadingCellId];

    [self authenticate];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    [self.data removeAllObjects];
    [self.tableView reloadData];
}

- (void)authenticate {
    if (![HTTwitterClient sharedInstance].isAuthenticated) {
        self.loader.hidden = NO;
        __typeof (&*self) __weak weakSelf = self;
        [[HTTwitterClient sharedInstance] authenticate:^(id response) {
            __typeof (&*weakSelf) strongSelf = weakSelf;
            strongSelf.loader.hidden = YES;
        } error:^(NSError *error) {
            __typeof (&*weakSelf) strongSelf = weakSelf;
            strongSelf.loader.hidden = YES;
        }];
    }
}

- (UIView *)loader {
    if (!_loader) {
        _loader = [[UIView alloc] init];
        _loader.hidden = YES;
        _loader.translatesAutoresizingMaskIntoConstraints = NO;
        _loader.backgroundColor = [UIColor colorWithRed:38/255.0f green:49/255.0f blue:106/255.0f alpha:.6f];

        UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = NO;
        [activityIndicatorView startAnimating];

        [_loader addSubview:activityIndicatorView];

        [self.view addSubview:self.loader];

        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[_loader]-0-|" options:NSLayoutFormatDirectionLeadingToTrailing metrics:nil views:NSDictionaryOfVariableBindings(_loader)]];
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[_loader]-0-|" options:NSLayoutFormatDirectionLeadingToTrailing metrics:nil views:NSDictionaryOfVariableBindings(_loader)]];
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[_loader]-0-|" options:NSLayoutFormatDirectionLeadingToTrailing metrics:nil views:NSDictionaryOfVariableBindings(_loader)]];

        UIView *superview = self.view;
        NSDictionary *variables = NSDictionaryOfVariableBindings(activityIndicatorView, superview);
        NSArray *constraints =
                [NSLayoutConstraint constraintsWithVisualFormat:@"V:[superview]-(<=1)-[activityIndicatorView]"
                                                        options: NSLayoutFormatAlignAllCenterX
                                                        metrics:nil
                                                          views:variables];
        [self.view addConstraints:constraints];

        constraints =
                [NSLayoutConstraint constraintsWithVisualFormat:@"H:[superview]-(<=1)-[activityIndicatorView]"
                                                        options: NSLayoutFormatAlignAllCenterY
                                                        metrics:nil
                                                          views:variables];
        [self.view addConstraints:constraints];
    }

    return _loader;
}

#pragma mark - UITableViewDataSource

- (void)loadTweetsWithHashTag:(NSString *)hashTag {
    __typeof (&*self) __weak weakSelf = self;

    [[HTTwitterClient sharedInstance] cancelAll];

    [HTTweet loadTweetsWithHashTag:hashTag maxId:self.maxId successCallback:^(id response) {
        __typeof (&*weakSelf) strongSelf = weakSelf;

        if (strongSelf.maxId) {
            [strongSelf.data addObjectsFromArray:response[@"statuses"]];
        }
        else {
            strongSelf.data = [response[@"statuses"] mutableCopy];
        }

        strongSelf.loadNext = strongSelf.data.count > 0;
        strongSelf.maxId = [strongSelf.data lastObject][@"id_str"];
        [strongSelf.tableView reloadData];
    } errorCallback:^(NSError *error) {

    }];
}

- (BOOL)isLoadingCell:(NSIndexPath *)indexPath {
    return self.loadNext && indexPath.row == self.numberOfRows - 1;
}

- (NSInteger)numberOfRows {
    return self.data.count + (self.loadNext ? 1 : 0);
}

- (HTTweet *)tweetForIndexPath:(NSIndexPath *)indexPath {
    return [HTTweet tweetWithDictionary:self.data[indexPath.row]];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.numberOfRows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isLoadingCell:indexPath]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:loadingCellId];

        return cell;
    }
    else {
        HTSearchResultCell *cell = (HTSearchResultCell *)[tableView dequeueReusableCellWithIdentifier:cellId];

        HTTweet *tweet = [self tweetForIndexPath:indexPath];

        [self setupCell:cell withTweet:tweet];

        return cell;
    }
}

- (void)setupCell:(HTSearchResultCell *)cell withTweet:(HTTweet *)tweet {
    cell.usernameLabel.text = tweet.username;
    cell.tweetLabel.text = tweet.text;
}

#pragma mark -

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    static HTSearchResultCell *stubCell;
    if (![self isLoadingCell:indexPath]) {
        if (stubCell == nil) {
            stubCell = (HTSearchResultCell *)[tableView dequeueReusableCellWithIdentifier:cellId];
        }
        HTTweet *tweet = [self tweetForIndexPath:indexPath];
        [self setupCell:stubCell withTweet:tweet];
        [stubCell layoutIfNeeded];
        CGFloat height = [stubCell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
        return height + 1;
    }
    else {
        return 44;
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isLoadingCell:indexPath]) {
        [self loadTweetsWithHashTag:self.searchBar.text];
    }
}

#pragma mark - UISearchBarDelegate

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:YES animated:YES];
    self.hashTagLabel.hidden = NO;
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    self.hashTagLabel.hidden = YES;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {

}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:NO animated:YES];
    [searchBar resignFirstResponder];
}


- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (!searchText.length) {
        return;
    }

    self.maxId = nil;
    [self loadTweetsWithHashTag:searchText];
}

@end
