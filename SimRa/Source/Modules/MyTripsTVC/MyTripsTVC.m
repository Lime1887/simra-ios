//
//  MyTripsTVC.m
//  simra
//
//  Created by Christoph Krey on 28.03.19.
//  Copyright © 2019-2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "MyTripsTVC.h"
#import "TripEditVC.h"
#import "NSTimeInterval+hms.h"

//#warning DEBUG SIMULATE_UNKNOWN_FILEHASH
//#define SIMULATE_UNKNOWN_FILEHASH @"12345678"
//#warning DEBUG EXTRA_OUTPUT
//#define EXTRA_OUTPUT 1

@interface MyTripsTVC ()
@property (strong, nonatomic) UIAlertController *ac;
@property (strong, nonatomic) NSMutableDictionary <NSNumber *, TripInfo *> *localTripInfos;
@property (strong, nonatomic) NSMutableDictionary <NSNumber *, TripInfo *> *uploadedTripInfos;
@property (strong, nonatomic) NSArray<TripInfo *> *pendingUploadTripInfos;
@property (strong, nonatomic) TripInfo *activeUploadTripInfo;
@property (nonatomic) NSUInteger uploadBatchIndex;
@property (nonatomic) NSUInteger uploadBatchSuccessCount;
@property (nonatomic) NSUInteger uploadBatchFailureCount;
@property (strong, nonatomic) NSMutableArray<NSString *> *uploadBatchFailures;
@property (nonatomic) dispatch_queue_t uploadQueue;
@property (strong, nonatomic) Trip *activeUploadTrip;
@property (strong, nonatomic) TripInfo *currentUploadingTripInfo;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *uploadButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *deleteButton;
@property (strong, nonatomic) UIBarButtonItem *editButton;
@property (strong, nonatomic) UIBarButtonItem *doneButton;
@property (strong, nonatomic) UIBarButtonItem *allButton;
@property (strong, nonatomic) UIBarButtonItem *noneButton;
@end

@implementation MyTripsTVC

- (UIBarButtonItem *)iconBarButtonWithSystemName:(NSString *)systemName
                                    fallbackTitle:(NSString *)fallbackTitle
                                           action:(SEL)action {
    if (@available(iOS 13.0, *)) {
        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:systemName]
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:action];
        item.accessibilityLabel = fallbackTitle;
        return item;
    }
    return [[UIBarButtonItem alloc] initWithTitle:fallbackTitle
                                            style:UIBarButtonItemStylePlain
                                           target:self
                                           action:action];
}

- (void)getTripInfos {
    self.localTripInfos = [[NSMutableDictionary alloc] init];
    self.uploadedTripInfos = [[NSMutableDictionary alloc] init];
    AppDelegate *ad = [AppDelegate sharedDelegate];
    for (TripInfo *tripInfo in ad.trips.tripInfos.allValues) {
        if (tripInfo.uploaded && !tripInfo.edited) {
            self.uploadedTripInfos[[NSNumber numberWithInteger:tripInfo.identifier]] = tripInfo;
        } else {
            self.localTripInfos[[NSNumber numberWithInteger:tripInfo.identifier]] = tripInfo;
        }
    }
}

- (void)refreshTripTable {
    [self getTripInfos];
    [self.tableView reloadData];
}

- (TripInfo *)getTripInfo:(NSIndexPath *)indexPath {
    TripInfo *tripInfo;
    if (indexPath.section == 0) {
        NSNumber *key = [self.localTripInfos.allKeys sortedArrayUsingFunction:revertedSort
                                                                      context:nil][indexPath.row];
        tripInfo = self.localTripInfos[key];
    } else {
        NSNumber *key = [self.uploadedTripInfos.allKeys sortedArrayUsingFunction:revertedSort
                                                                         context:nil][indexPath.row];
        tripInfo = self.uploadedTripInfos[key];
    }
    return tripInfo;
}

NSInteger revertedSort(id num1, id num2, void *context) {
    NSNumber *n1 = (NSNumber *)num1;
    NSNumber *n2 = (NSNumber *)num2;
    return [n2 compare:n1];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.editButton = [self iconBarButtonWithSystemName:@"square.and.pencil"
                                          fallbackTitle:NSLocalizedString(@"Edit", @"Edit")
                                                 action:@selector(editToggle:)];
    self.doneButton = [self iconBarButtonWithSystemName:@"checkmark"
                                          fallbackTitle:NSLocalizedString(@"Done", @"Done")
                                                 action:@selector(editToggle:)];
    self.allButton = [self iconBarButtonWithSystemName:@"checkmark.circle"
                                         fallbackTitle:NSLocalizedString(@"All", @"Table Select All")
                                                action:@selector(selectAll:)];
    self.noneButton = [self iconBarButtonWithSystemName:@"circle"
                                          fallbackTitle:NSLocalizedString(@"None", @"Table Select None")
                                                 action:@selector(selectNone:)];

    [self configureBottomToolbar];

    NSMutableArray<UIBarButtonItem *> *r = [self.navigationItem.rightBarButtonItems mutableCopy];
    if (!r) {
        r = [[NSMutableArray alloc] init];
    }
    [r addObject:self.editButton];
    [self.navigationItem setRightBarButtonItems:r animated:TRUE];
}

- (IBAction)selectAll:(id)sender {
    NSMutableArray<UIBarButtonItem *> *l = [self.navigationItem.leftBarButtonItems mutableCopy];
    if (!l) {
        l = [[NSMutableArray alloc] init];
    } else {
        [l removeLastObject];
    }
    [l addObject:self.noneButton];
    [self.navigationItem setLeftBarButtonItems:l animated:TRUE];
    for (NSInteger i = 0; i < self.localTripInfos.count; i++) {
        [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0] animated:FALSE scrollPosition:UITableViewScrollPositionNone];
    }
    for (NSInteger i = 0; i < self.uploadedTripInfos.count; i++) {
        [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:1] animated:FALSE scrollPosition:UITableViewScrollPositionNone];
    }
    [self setUIElements];
}

- (IBAction)selectNone:(id)sender {
    NSMutableArray<UIBarButtonItem *> *l = [self.navigationItem.leftBarButtonItems mutableCopy];
    if (!l) {
        l = [[NSMutableArray alloc] init];
    } else {
        [l removeLastObject];
    }
    [l addObject:self.allButton];
    [self.navigationItem setLeftBarButtonItems:l animated:TRUE];
    for (NSInteger i = 0; i < self.localTripInfos.count; i++) {
        [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0] animated:FALSE];
    }
    for (NSInteger i = 0; i < self.uploadedTripInfos.count; i++) {
        [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:1] animated:FALSE];
    }
    [self setUIElements];
}

- (IBAction)editToggle:(id)sender {
    [self.tableView setEditing:!self.tableView.editing animated:TRUE];
    NSMutableArray<UIBarButtonItem *> *l = [self.navigationItem.leftBarButtonItems mutableCopy];
    if (!l) {
        l = [[NSMutableArray alloc] init];
    }
    NSMutableArray<UIBarButtonItem *> *r = [self.navigationItem.rightBarButtonItems mutableCopy];
    if (!r) {
        r = [[NSMutableArray alloc] init];
    } else {
        [r removeLastObject];
    }
    if (self.tableView.editing) {
        [r addObject:self.doneButton];
        [l addObject:self.allButton];
        [self.navigationController setToolbarHidden:FALSE];
        [self setUIElements];
    } else {
        [r addObject:self.editButton];
        if (l.count > 0) {
            [l removeLastObject];
        }
        [self.navigationController setToolbarHidden:TRUE];
    }
    [self.navigationItem setLeftBarButtonItems:l animated:TRUE];
    [self.navigationItem setRightBarButtonItems:r animated:TRUE];
}
- (IBAction)uploadPressed:(UIBarButtonItem *)sender {
    if ([self checkRegion]) {
        [self beginUploadBatchWithTripInfos:[self selectedLocalTripInfos]];
    }
}

- (IBAction)deletePressed:(UIBarButtonItem *)sender {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    for (NSIndexPath *indexPath in self.tableView.indexPathsForSelectedRows) {
        TripInfo *tripInfo = [self getTripInfo:indexPath];
        [ad.trips deleteTripWithIdentifier:tripInfo.identifier];
    }
    [self.tableView performBatchUpdates:^{
        for (NSIndexPath *indexPath in self.tableView.indexPathsForSelectedRows) {
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        }
    } completion:^(BOOL finished) {
        [self getTripInfos];
        [self setUIElements];
    }];
}

- (void)setUIElements {
    if (self.tableView.indexPathsForSelectedRows.count > 0) {
        self.uploadButton.enabled = TRUE;
        self.deleteButton.enabled = TRUE;
    } else {
        self.uploadButton.enabled = FALSE;
        self.deleteButton.enabled = FALSE;
    }
}

- (void)configureBottomToolbar {
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                      target:nil
                                      action:nil];
    UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc]
                                   initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                   target:nil
                                   action:nil];
    fixedSpace.width = 18.0;
    UIBarButtonItem *uploadItem = self.uploadButton ?: [[UIBarButtonItem alloc]
                                                        initWithTitle:NSLocalizedString(@"Upload", @"Upload")
                                                        style:UIBarButtonItemStylePlain
                                                        target:self
                                                        action:@selector(uploadPressed:)];
    UIBarButtonItem *deleteItem = self.deleteButton ?: [[UIBarButtonItem alloc]
                                                        initWithTitle:NSLocalizedString(@"Delete", @"Delete")
                                                        style:UIBarButtonItemStylePlain
                                                        target:self
                                                        action:@selector(deletePressed:)];
    self.toolbarItems = @[flexibleSpace, uploadItem, fixedSpace, deleteItem, flexibleSpace];
}

- (NSArray<TripInfo *> *)selectedLocalTripInfos {
    NSArray<NSIndexPath *> *selectedRows = self.tableView.indexPathsForSelectedRows;
    if (selectedRows.count == 0) {
        return @[];
    }

    NSArray<NSIndexPath *> *sortedRows = [selectedRows sortedArrayUsingComparator:^NSComparisonResult(NSIndexPath *lhs, NSIndexPath *rhs) {
        if (lhs.section < rhs.section) {
            return NSOrderedAscending;
        }
        if (lhs.section > rhs.section) {
            return NSOrderedDescending;
        }
        if (lhs.row < rhs.row) {
            return NSOrderedAscending;
        }
        if (lhs.row > rhs.row) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];

    NSMutableArray<TripInfo *> *tripInfos = [[NSMutableArray alloc] init];
    for (NSIndexPath *indexPath in sortedRows) {
        if (indexPath.section == 0) {
            TripInfo *tripInfo = [self getTripInfo:indexPath];
            if (tripInfo) {
                [tripInfos addObject:tripInfo];
            }
        }
    }
    return [tripInfos copy];
}

- (void)beginUploadBatchWithTripInfos:(NSArray<TripInfo *> *)tripInfos {
    if (tripInfos.count == 0) {
        return;
    }

    if (!self.uploadQueue) {
        self.uploadQueue = dispatch_queue_create("org.simra.uploadBatch", DISPATCH_QUEUE_SERIAL);
    }

    self.pendingUploadTripInfos = tripInfos;
    self.activeUploadTrip = nil;
    self.activeUploadTripInfo = nil;
    self.uploadBatchIndex = 0;
    self.uploadBatchSuccessCount = 0;
    self.uploadBatchFailureCount = 0;
    self.uploadBatchFailures = [[NSMutableArray alloc] init];
    self.currentUploadingTripInfo = nil;
    self.uploadButton.enabled = FALSE;
    self.deleteButton.enabled = FALSE;
    self.navigationItem.prompt = [NSString stringWithFormat:
                                  NSLocalizedString(@"Uploading %lu trips", @"Uploading trips prompt"),
                                  (unsigned long)tripInfos.count];

    [self refreshTripTable];
    [self uploadNextTripInBatch];
}

- (void)uploadNextTripInBatch {
    if (self.uploadBatchIndex >= self.pendingUploadTripInfos.count) {
        [self finishUploadBatch];
        return;
    }

    self.activeUploadTripInfo = self.pendingUploadTripInfos[self.uploadBatchIndex];
    self.currentUploadingTripInfo = self.activeUploadTripInfo;
    self.uploadBatchIndex++;
    self.navigationItem.prompt = [NSString stringWithFormat:
                                  NSLocalizedString(@"Uploading %lu of %lu", @"Uploading progress prompt"),
                                  (unsigned long)self.uploadBatchIndex,
                                  (unsigned long)self.pendingUploadTripInfos.count];
    [self refreshTripTable];

    TripInfo *tripInfo = self.activeUploadTripInfo;
    dispatch_async(self.uploadQueue, ^{
        Trip *trip = [[Trip alloc] initFromStorage:tripInfo.identifier];
        self.activeUploadTrip = trip;
        [trip uploadFile:@"ride"
          WithController:self
                   error:@selector(uploadTripError:)
              completion:@selector(uploadTripCompleted:)];
    });
}

- (void)uploadTripError:(NSError *)connectionError {
    NSString *failure = [NSString stringWithFormat:@"%ld: %@",
                         (long)self.activeUploadTripInfo.identifier,
                         connectionError.localizedDescription];
    [self.uploadBatchFailures addObject:failure];
    self.uploadBatchFailureCount++;
    self.activeUploadTrip = nil;
    self.currentUploadingTripInfo = nil;
    [self refreshTripTable];
    [self uploadNextTripInBatch];
}

- (void)uploadTripCompleted:(NSDictionary *)dict {
    NSURLResponse *response = dict[@"response"];
    NSData *data = dict[@"data"];

    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299) {
            self.uploadBatchSuccessCount++;
            self.activeUploadTrip = nil;
            self.currentUploadingTripInfo = nil;
            [self refreshTripTable];
            [self uploadNextTripInBatch];
            return;
        }

        NSString *message = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSString *failure = [NSString stringWithFormat:@"%ld: HTTP %ld %@",
                             (long)self.activeUploadTripInfo.identifier,
                             (long)httpResponse.statusCode,
                             message ?: @""];
        [self.uploadBatchFailures addObject:failure];
    } else {
        NSString *failure = [NSString stringWithFormat:@"%ld: %@",
                             (long)self.activeUploadTripInfo.identifier,
                             NSLocalizedString(@"No HTTP response", @"No HTTP response")];
        [self.uploadBatchFailures addObject:failure];
    }

    self.uploadBatchFailureCount++;
    self.activeUploadTrip = nil;
    self.currentUploadingTripInfo = nil;
    [self refreshTripTable];
    [self uploadNextTripInBatch];
}

- (void)finishUploadBatch {
    self.pendingUploadTripInfos = nil;
    self.activeUploadTrip = nil;
    self.activeUploadTripInfo = nil;
    self.currentUploadingTripInfo = nil;
    self.navigationItem.prompt = nil;
    self.uploadButton.enabled = TRUE;
    self.deleteButton.enabled = TRUE;
    [self refreshTripTable];

    NSString *message = [NSString stringWithFormat:
                         NSLocalizedString(@"Uploaded %lu trip(s), %lu failed.", @"Upload batch summary"),
                         (unsigned long)self.uploadBatchSuccessCount,
                         (unsigned long)self.uploadBatchFailureCount];
    if (self.uploadBatchFailures.count > 0) {
        message = [message stringByAppendingFormat:@"\n%@", [self.uploadBatchFailures componentsJoinedByString:@"\n"]];
    }

    UIAlertController *summary = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Upload", @"Upload")
                                                                     message:message
                                                              preferredStyle:UIAlertControllerStyleAlert];
    [summary addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK")
                                                style:UIAlertActionStyleDefault
                                              handler:nil]];
    [self presentViewController:summary animated:TRUE completion:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (self.preselectedTrip) {
        [self performSegueWithIdentifier:@"editTrip:" sender:nil];
    }
    [self.tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    [self getTripInfos];
    if (section == 0) {
        return self.localTripInfos.count;
    } else {
        return self.uploadedTripInfos.count;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return self.localTripInfos.count > 0 ? NSLocalizedString(@"Not Uploaded", @"Not Uploaded") : nil;
    } else {
        return self.uploadedTripInfos.count > 0 ? NSLocalizedString(@"Uploaded", @"Uploaded") : nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"trip" forIndexPath:indexPath];
    TripInfo *tripInfo = [self getTripInfo:indexPath];

    NSString *status;

    if (self.currentUploadingTripInfo &&
        self.currentUploadingTripInfo.identifier == tripInfo.identifier) {
        status = NSLocalizedString(@"Uploading", @"Uploading");
    } else if (tripInfo.edited) {
        status = NSLocalizedString(@"Edited", @"Edited");
        if (tripInfo.statisticsAdded) {
            status = [status stringByAppendingFormat:@"-%@",
                      NSLocalizedString(@"Completed", @"Completed")];
        }
    } else {
        if (tripInfo.uploaded) {
            status = NSLocalizedString(@"Uploaded", @"Uploaded");
        } else {
            status = NSLocalizedString(@"New", @"New");
            if (tripInfo.statisticsAdded) {
                status = [status stringByAppendingFormat:@"-%@",
                          NSLocalizedString(@"Completed", @"Completed")];
            }
        }
    }

    NSDateFormatter *startFormatter = [[NSDateFormatter alloc] init];
    startFormatter.dateStyle = NSDateFormatterShortStyle;
    startFormatter.timeStyle =NSDateFormatterShortStyle;

    NSDateInterval *duration = tripInfo.duration;
    NSTimeInterval seconds = [duration.endDate timeIntervalSinceDate:duration.startDate];

    cell.textLabel.text = [NSString stringWithFormat:@"%@",
                           status];

    NSString *detail = [NSString stringWithFormat:@" %@, %@, %.01f km",
                        [startFormatter stringFromDate:tripInfo.duration.startDate],
                        hms(seconds),
                        tripInfo.length / 1000.0];
#ifdef EXTRA_OUTPUT
    detail = [detail stringByAppendingFormat:@" (%ld/%ld/%d)",
              (long)tripInfo.validAnnotationsCount,
              (long)tripInfo.annotationsCount,
              tripInfo.reUploaded];
#endif

    cell.detailTextLabel.text = detail;
    return cell;
}

// Override to support conditional editing of the table view.
//- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
//    return YES;
//}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section > 0) {
        return nil;
    }
    UIContextualAction *uploadAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                               title:NSLocalizedString(@"Upload", @"Upload Context")
                                                                             handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        if ([self checkRegion]) {
            [self beginUploadBatchWithTripInfos:@[[self getTripInfo:indexPath]]];
        }
    }];
    uploadAction.backgroundColor = [UIColor systemBlueColor];
    UISwipeActionsConfiguration *sac = [UISwipeActionsConfiguration configurationWithActions:@[uploadAction]];
    sac.performsFirstActionWithFullSwipe = TRUE;
    return sac;
}
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                               title:NSLocalizedString(@"Delete locally", @"Confirmation button for delete My Trips table row")
                                                                             handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        TripInfo *tripInfo = [self getTripInfo:indexPath];
        AppDelegate *ad = [AppDelegate sharedDelegate];
        [ad.trips deleteTripWithIdentifier:tripInfo.identifier];
        [tableView performBatchUpdates:^{
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        } completion:^(BOOL finished) {
            [self getTripInfos];
        }];
    }];
    UISwipeActionsConfiguration *sac = [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
    sac.performsFirstActionWithFullSwipe = TRUE;
    return sac;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!tableView.editing) {
        [self performSegueWithIdentifier:@"editTrip:" sender:[tableView cellForRowAtIndexPath:indexPath]];
    } else {
        [self setUIElements];
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self setUIElements];
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point  API_AVAILABLE(ios(13.0)){

    TripInfo *tripInfo = [self getTripInfo:indexPath];
    Trip *trip = [[Trip alloc] initFromStorage:tripInfo.identifier];

    UIImage *shareIcon = [UIImage systemImageNamed:@"square.and.arrow.up"];

    UIAction *exportAction = [UIAction actionWithTitle:NSLocalizedString(@"Manual Export", @"MyTrips View Context menu export title")
                                                 image:shareIcon identifier:nil
                                               handler:^(__kindof UIAction * _Nonnull action) {
        UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:@[[trip csvFile]] applicationActivities:nil];
        [self presentViewController:activityController animated:true completion:nil];
    }];
    
    UIAction *exportGPXAction = [UIAction actionWithTitle:NSLocalizedString(@"GPX Export", @"MyTrips View Context menu GPX title")
                                                 image:shareIcon identifier:nil
                                               handler:^(__kindof UIAction * _Nonnull action) {
        UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:@[[trip gpxFile]] applicationActivities:nil];
        [self presentViewController:activityController animated:true completion:nil];
    }];

    UIAction *exportGeoJSONAction = [UIAction actionWithTitle:NSLocalizedString(@"GeoJSON Export", @"MyTrips View Context menu GeoJSON title")
                                                 image:shareIcon identifier:nil
                                               handler:^(__kindof UIAction * _Nonnull action) {
        UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:@[[trip geoJSONFile]] applicationActivities:nil];
        [self presentViewController:activityController animated:true completion:nil];
    }];

    UIAction *exportKMLAction = [UIAction actionWithTitle:NSLocalizedString(@"KML Export", @"MyTrips View Context menu KML title")
                                                 image:shareIcon identifier:nil
                                               handler:^(__kindof UIAction * _Nonnull action) {
        UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:@[[trip kmlFile]] applicationActivities:nil];
        [self presentViewController:activityController animated:true completion:nil];
    }];

    return [UIContextMenuConfiguration configurationWithIdentifier:nil
                                                   previewProvider:nil
                                                    actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
        return [UIMenu menuWithTitle:NSLocalizedString(@"Actions", @"MyTrips View Context menu title")
                            children:@[exportAction, exportGPXAction, exportGeoJSONAction, exportKMLAction]];
    }];
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"editTrip:"] &&
        [segue.destinationViewController isKindOfClass:[TripEditVC class]]) {
        TripEditVC *tripEditVC = (TripEditVC *)segue.destinationViewController;
        if ([sender isKindOfClass:[UITableViewCell class]]) {
            UITableViewCell *cell = (UITableViewCell *)sender;
            NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
            TripInfo *tripInfo = [self getTripInfo:indexPath];
            Trip *trip = [[Trip alloc] initFromStorage:tripInfo.identifier];
            tripEditVC.trip = trip;
            tripEditVC.clean = TRUE;
            tripEditVC.changed = FALSE;
        } else {
            tripEditVC.trip = self.preselectedTrip;
            self.preselectedTrip = false;
            tripEditVC.changed = FALSE;
        }
    }
}

- (BOOL)checkRegion {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    if (!ad.regions.regionSelected) {
        NSString *message = [NSString stringWithFormat:@"%@ %@",
                             NSLocalizedString(@"Please choose your correct region, so that we can analyse your ride correctly. Your selected region:",
                                                       @"Please choose your correct region, so that we can analyse your ride correctly. Your selected region:"),
                             ad.regions.regionId == 0 ? ad.regions.currentRegion.identifier : ad.regions.currentRegion.localizedDescription];


        UIAlertController *ac = [UIAlertController
                                 alertControllerWithTitle:NSLocalizedString(@"Please choose a Region",
                                                                            @"Please choose a Region")
                                 message: message
                                 preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *aay = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK")
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * _Nonnull action) {
                                                        [self performSegueWithIdentifier:@"profile" sender:nil];
                                                    }];
        [ac addAction:aay];
        [self presentViewController:ac animated:TRUE completion:nil];
        return FALSE;
    }
    return TRUE;
}

@end
