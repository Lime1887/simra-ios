//
//  SettingsTVC.m
//  simra
//
//  Created by Christoph Krey on 28.03.19.
//  Copyright © 2019-2021 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "SettingsTVC.h"

#import <MessageUI/MessageUI.h>
#import "../../../../Pods/SSZipArchive/SSZipArchive/SSZipArchive.h"

#import "IdPicker.h"
#import "NSTimeInterval+hms.h"
#import "DSBarChart.h"
#import "SimRa-Swift.h"
#import "NSString+hashCode.h"
#import "API.h"

@interface SettingsTVC ()

@property (nonatomic, weak) IBOutlet UILabel *version;
@property (nonatomic, weak) IBOutlet UITableViewCell *versionCell;

@property (nonatomic, strong) UIAlertController *ac;
@property (nonatomic, strong) UITapGestureRecognizer *versionTapGesture;

@end


@implementation SettingsTVC

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    [self configureView];
    [self configureActionButtons];
    [self configureVersionInteraction];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self update];
}

#pragma mark - Appearance

- (void)configureView {

    if (@available(iOS 13.0, *)) {
        self.view.tintColor = [UIColor systemBlueColor];
        self.tableView.backgroundColor =
            [UIColor systemGroupedBackgroundColor];
    } else {
        self.view.tintColor = [UIColor blueColor];
    }

    /*
     Let UIKit handle the system table appearance.
     In particular, do not manually create a Liquid Glass
     background for the navigation bar.
     */

    self.tableView.separatorStyle =
        UITableViewCellSeparatorStyleNone;

    if (@available(iOS 13.0, *)) {
        self.versionCell.backgroundColor =
            [UIColor secondarySystemGroupedBackgroundColor];
    }
}

#pragma mark - Buttons

- (void)configureActionButtons {
    [self configureButtonsRecursively:self.view];
}

- (void)configureButtonsRecursively:(UIView *)view {

    if ([view isKindOfClass:[UIButton class]]) {
        [self configureButton:(UIButton *)view];
    }

    for (UIView *subview in view.subviews) {
        [self configureButtonsRecursively:subview];
    }
}

- (void)configureButton:(UIButton *)button {

    if (!button) {
        return;
    }

    NSString *title = button.currentTitle;

    if (title.length == 0) {
        return;
    }

    NSString *symbolName =
        [self symbolForButtonTitle:title];

    if (symbolName.length == 0) {
        return;
    }

    button.accessibilityLabel = title;

    /*
     iOS 26:
     Use Apple's native Liquid Glass button configuration.
     
     Nothing is simulated here with blur/materials.
     */

    if (@available(iOS 26.0, *)) {

        UIButtonConfiguration *configuration =
            [UIButtonConfiguration glassButtonConfiguration];

        configuration.title = title;

        configuration.image =
            [UIImage systemImageNamed:symbolName];

        configuration.imagePlacement =
            NSDirectionalRectEdgeLeading;

        configuration.imagePadding = 8.0;

        configuration.contentInsets =
            NSDirectionalEdgeInsetsMake(
                10.0,
                16.0,
                10.0,
                16.0
            );

        button.configuration = configuration;

        button.tintColor =
            [UIColor labelColor];

        return;
    }

    /*
     iOS 15–25 fallback.
     */

    if (@available(iOS 15.0, *)) {

        UIButtonConfiguration *configuration =
            [UIButtonConfiguration
                borderedTintedButtonConfiguration];

        configuration.title = title;

        configuration.image =
            [UIImage systemImageNamed:symbolName];

        configuration.imagePlacement =
            NSDirectionalRectEdgeLeading;

        configuration.imagePadding = 8.0;

        configuration.contentInsets =
            NSDirectionalEdgeInsetsMake(
                10.0,
                16.0,
                10.0,
                16.0
            );

        configuration.baseForegroundColor =
            [UIColor labelColor];

        button.configuration = configuration;

        return;
    }

    /*
     Older iOS fallback.
     */

    [button setTitle:title
            forState:UIControlStateNormal];

    [button setImage:
        [UIImage systemImageNamed:symbolName]
          forState:UIControlStateNormal];

    if (@available(iOS 13.0, *)) {
        [button setTitleColor:
            [UIColor labelColor]
              forState:UIControlStateNormal];
    } else {
        [button setTitleColor:
            [UIColor blackColor]
              forState:UIControlStateNormal];
    }

    button.titleLabel.font =
        [UIFont preferredFontForTextStyle:
            UIFontTextStyleBody];

    button.contentHorizontalAlignment =
        UIControlContentHorizontalAlignmentCenter;
}

- (NSString *)symbolForButtonTitle:(NSString *)title {

    if ([title isEqualToString:
            NSLocalizedString(@"About", @"About")]) {
        return @"info.circle";
    }

    if ([title isEqualToString:
            NSLocalizedString(@"Privacy", @"Privacy")]) {
        return @"hand.raised";
    }

    if ([title isEqualToString:
            NSLocalizedString(@"How To", @"How To")]) {
        return @"questionmark.circle";
    }

    if ([title isEqualToString:
            NSLocalizedString(@"Feedback", @"Feedback")]) {
        return @"envelope";
    }

    if ([title isEqualToString:
            NSLocalizedString(@"Imprint", @"Imprint")]) {
        return @"building.columns";
    }

    return nil;
}

#pragma mark - Table View

- (CGFloat)tableView:(UITableView *)tableView
heightForRowAtIndexPath:(NSIndexPath *)indexPath {

    if (tableView.numberOfSections == 2 &&
        indexPath.section == 1) {

        return indexPath.row < 5 ? 56.0 : 52.0;
    }

    return 56.0;
}

- (CGFloat)tableView:(UITableView *)tableView
heightForHeaderInSection:(NSInteger)section {

    return 32.0;
}

#pragma mark - Version

- (void)configureVersionInteraction {

    if (!self.versionCell) {
        return;
    }

    if (self.versionTapGesture) {
        [self.versionCell
            removeGestureRecognizer:self.versionTapGesture];
    }

    self.versionTapGesture =
        [[UITapGestureRecognizer alloc]
            initWithTarget:self
            action:@selector(didTapOnVersion:)];

    self.versionTapGesture.numberOfTapsRequired = 1;

    [self.versionCell
        addGestureRecognizer:self.versionTapGesture];

    self.versionCell.isAccessibilityElement = YES;

    if (@available(iOS 13.0, *)) {
        self.versionCell.accessibilityTraits =
            UIAccessibilityTraitButton;
    }

    self.versionCell.accessibilityLabel =
        NSLocalizedString(
            @"App version",
            @"Accessibility label for app version"
        );

    self.versionCell.accessibilityHint =
        NSLocalizedString(
            @"Tap to send diagnostic data to the SimRa team.",
            @"Accessibility hint for app version"
        );
}

- (void)didTapOnVersion:(UITapGestureRecognizer *)sender {

    if (sender.state !=
        UIGestureRecognizerStateEnded) {
        return;
    }

    __weak typeof(self) weakSelf = self;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Send local app data to SimRa team", @"Send local app data to SimRa team") message:NSLocalizedString(@"Attention! Only tap the Continue button, if you were asked to do so by the SimRa team. By pressing the Upload button in the next step, you send your SimRa configuration to the SimRa team. You can also specify to upload the last 10 rides or all rides.", @"Diagnostic upload warning") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        [Utility writeSimRaPrefs];
        [strongSelf showTotalRidesAlert];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Version Information

- (void)update {

    NSDictionary *info =
        [[NSBundle mainBundle] infoDictionary];

    NSString *name =
        info[@"CFBundleName"];

    NSString *version =
        info[@"CFBundleVersion"];

    NSString *language =
        [NSLocale currentLocale].languageCode;

    if (name.length == 0) {
        name = @"SimRa";
    }

    if (version.length == 0) {
        version = @"";
    }

    if (language.length == 0) {
        language = @"";
    }

    self.version.text =
        [NSString stringWithFormat:@"%@-%@-%@",
            name,
            version,
            language];
}

#pragma mark - Trip Files

- (NSArray<NSString *> *)tripFilePathsForAllTrips:(BOOL)allTrips {

    AppDelegate *appDelegate =
        [AppDelegate sharedDelegate];

    NSArray<NSNumber *> *tripIdentifiers =
        [appDelegate.trips.tripInfos.allKeys sortedArrayUsingSelector:@selector(compare:)];

    if (tripIdentifiers.count == 0) {
        return @[];
    }

    NSArray<NSNumber *> *selectedTripIdentifiers = tripIdentifiers;

    if (!allTrips && tripIdentifiers.count > minimumTripsToSend) {
        NSRange range = NSMakeRange(tripIdentifiers.count - minimumTripsToSend, minimumTripsToSend);
        selectedTripIdentifiers = [tripIdentifiers subarrayWithRange:range];
    }

    NSMutableArray<NSString *> *paths =
        [NSMutableArray array];

    NSString *documentsDirectory =
        [Utility getDocumentDirectory];

    for (NSNumber *tripIdentifier in selectedTripIdentifiers) {
        NSInteger tripIndex = tripIdentifier.integerValue;

        NSString *tripPath =
            [documentsDirectory
                stringByAppendingPathComponent:
                    [NSString stringWithFormat:
                        @"Trip-%ld.json",
                        (long)tripIndex]];

        NSString *tripInfoPath =
            [documentsDirectory
                stringByAppendingPathComponent:
                    [NSString stringWithFormat:
                        @"TripInfo-%ld.json",
                        (long)tripIndex]];

        [paths addObject:tripPath];
        [paths addObject:tripInfoPath];
    }

    return [paths copy];
}

#pragma mark - Trip Size

- (NSString *)getTripsSizeGetAllTrips:(BOOL)allTrips {

    NSArray<NSString *> *tripPaths =
        [self tripFilePathsForAllTrips:allTrips];

    if (tripPaths.count == 0) {

        return
            [NSByteCountFormatter
                stringFromByteCount:0
                countStyle:
                    NSByteCountFormatterCountStyleFile];
    }

    NSFileManager *fileManager =
        [NSFileManager defaultManager];

    long long totalBytes = 0;

    for (NSString *path in tripPaths) {

        NSError *error = nil;

        NSDictionary *attributes =
            [fileManager
                attributesOfItemAtPath:path
                error:&error];

        NSNumber *fileSize =
            attributes[NSFileSize];

        if (fileSize) {

            totalBytes +=
                fileSize.longLongValue;

        } else if (error) {

            NSLog(
                @"Could not determine file size for %@: %@",
                path,
                error
            );
        }
    }

    return
        [NSByteCountFormatter
            stringFromByteCount:totalBytes
            countStyle:
                NSByteCountFormatterCountStyleFile];
}

#pragma mark - ZIP

- (NSString *)createZipFilesWithPath:(BOOL)allTrips {

    NSString *temporaryDirectory =
        NSTemporaryDirectory();

    if (temporaryDirectory.length == 0) {
        return nil;
    }

    NSMutableArray<NSString *> *paths =
        [NSMutableArray
            arrayWithArray:
                [Utility getAllDocumentsPrefLinks]];

    [paths addObjectsFromArray:
        [self tripFilePathsForAllTrips:allTrips]];

    NSString *zipPath =
        [temporaryDirectory
            stringByAppendingPathComponent:
                @"Logger.zip"];

    [[NSFileManager defaultManager]
        removeItemAtPath:zipPath
        error:nil];

    BOOL created =
        [SSZipArchive
            createZipFileAtPath:zipPath
            withFilesAtPaths:paths];

    if (!created) {

        NSLog(
            @"Could not create ZIP archive at %@",
            zipPath
        );

        return nil;
    }

    return zipPath;
}

#pragma mark - Upload

- (void)sendZipToServerWithAllTrips:(BOOL)allTrips {

    NSString *zipFilePath =
        [self createZipFilesWithPath:allTrips];

    if (zipFilePath.length == 0) {
        [self showUploadError];
        return;
    }

    NSData *zipData =
        [NSData dataWithContentsOfFile:zipFilePath];

    if (zipData.length == 0) {
        [self showUploadError];
        return;
    }

    NSString *baseURL =
        [NSString stringWithFormat:
            @"%@/debug",
            API.APIPrefix];

    NSURLComponents *components =
        [NSURLComponents
            componentsWithString:baseURL];

    if (!components) {
        [self showUploadError];
        return;
    }

    components.queryItems = @[
        [NSURLQueryItem
            queryItemWithName:@"clientHash"
            value:NSString.clientHash]
    ];

    NSURL *url = components.URL;

    if (!url) {
        [self showUploadError];
        return;
    }

    NSMutableURLRequest *request =
        [NSMutableURLRequest
            requestWithURL:url];

    request.HTTPMethod = @"POST";

    NSString *boundary =
        [NSString stringWithFormat:
            @"SimRa-%@",
            NSUUID.UUID.UUIDString];

    [request setValue:
        [NSString stringWithFormat:
            @"multipart/form-data; boundary=%@",
            boundary]
        forHTTPHeaderField:@"Content-Type"];

    NSMutableData *body =
        [NSMutableData data];

    NSString *header =
        [NSString stringWithFormat:
            @"--%@\r\n"
             "Content-Disposition: form-data; "
             "name=\"file\"; filename=\"Logger.zip\"\r\n"
             "Content-Type: application/zip\r\n"
             "\r\n",
            boundary];

    [body appendData:
        [header dataUsingEncoding:
            NSUTF8StringEncoding]];

    [body appendData:zipData];

    NSString *footer =
        [NSString stringWithFormat:
            @"\r\n--%@--\r\n",
            boundary];

    [body appendData:
        [footer dataUsingEncoding:
            NSUTF8StringEncoding]];

    request.HTTPBody = body;

    __weak typeof(self) weakSelf = self;

    NSURLSessionDataTask *task =
        [[NSURLSession sharedSession]
            dataTaskWithRequest:request
            completionHandler:
            ^(NSData *data,
              NSURLResponse *response,
              NSError *error) {

        dispatch_async(
            dispatch_get_main_queue(),
            ^{

            typeof(self) strongSelf = weakSelf;

            if (!strongSelf) {
                return;
            }

            if (error) {

                NSLog(
                    @"SimRa diagnostic upload failed: %@",
                    error
                );

                [strongSelf showUploadError];
                return;
            }

            NSHTTPURLResponse *httpResponse =
                (NSHTTPURLResponse *)response;

            NSInteger statusCode =
                httpResponse.statusCode;

            NSLog(
                @"SimRa diagnostic upload response: %ld",
                (long)statusCode
            );

            if (statusCode >= 200 &&
                statusCode < 300) {

                [strongSelf showUploadSuccess];

            } else {

                [strongSelf showUploadError];
            }
        });
    }];

    [task resume];
}

#pragma mark - Upload Alerts

- (void)showUploadSuccess {

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"SimRa", @"SimRa") message:NSLocalizedString(@"Files uploaded successfully", @"Files uploaded successfully") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showUploadError {

    if (!self.viewIfLoaded.window) {
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"SimRa", @"SimRa") message:NSLocalizedString(@"Something went wrong. Please try again later", @"Something went wrong. Please try again later") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Ride Selection

- (void)showTotalRidesAlert {

    AppDelegate *appDelegate =
        [AppDelegate sharedDelegate];

    NSInteger totalTrips =
        appDelegate.trips.tripInfos.count;

    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:
                NSLocalizedString(
                    @"Do you also want to send rides?",
                    @"Do you also want to send rides?"
                )
            message:nil
            preferredStyle:
                UIAlertControllerStyleActionSheet];

    NSString *allRidesTitle =
        [NSString stringWithFormat:
            @"%@ (%@)",
            NSLocalizedString(
                @"Yes, all",
                @"Yes, all"
            ),
            [self getTripsSizeGetAllTrips:YES]];

    [alert addAction:
        [UIAlertAction
            actionWithTitle:allRidesTitle
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) {

        [self sendZipToServerWithAllTrips:YES];
    }]];

    if (totalTrips > minimumTripsToSend) {

        NSString *recentRidesTitle =
            [NSString stringWithFormat:
                @"%@ %ld (%@)",
                NSLocalizedString(
                    @"Yes, the last",
                    @"Yes, the last"
                ),
                (long)minimumTripsToSend,
                [self getTripsSizeGetAllTrips:NO]];

        [alert addAction:
            [UIAlertAction
                actionWithTitle:recentRidesTitle
                style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {

            [self sendZipToServerWithAllTrips:NO];
        }]];
    }

    [alert addAction:
        [UIAlertAction
            actionWithTitle:
                NSLocalizedString(
                    @"No, don't send any rides",
                    @"No, don't send any rides"
                )
            style:UIAlertActionStyleCancel
            handler:nil]];

    if (alert.popoverPresentationController) {

        alert.popoverPresentationController.sourceView =
            self.view;

        alert.popoverPresentationController.sourceRect =
            CGRectMake(
                CGRectGetMidX(self.view.bounds),
                CGRectGetMaxY(self.view.bounds) - 40.0,
                1.0,
                1.0
            );
    }

    [self presentViewController:alert
                       animated:YES
                     completion:nil];
}

#pragma mark - Settings Actions

- (IBAction)aboutPressed:(UIButton *)sender {

    [[AppDelegate sharedDelegate]
        openURL:@{
            @"en":
                @"https://www.digital-future.berlin/en/research/projects/simra/",
            @"de":
                @"https://www.digital-future.berlin/forschung/projekte/simra/"
        }];
}

- (IBAction)privacyPressed:(UIButton *)sender {

    [[AppDelegate sharedDelegate]
        openURL:@{
            @"en":
                @"https://www.tu.berlin/en/3s/research/projects/simra-privacy-policy-statement",
            @"de":
                @"https://www.tu.berlin/3s/forschung/projekte/simra-datenschutzerklaerung"
        }];
}

- (IBAction)howtoPressed:(UIButton *)sender {

    [[AppDelegate sharedDelegate] showHowTo];
}

- (IBAction)feedbackPressed:(UIButton *)sender {

    if ([MFMailComposeViewController canSendMail]) {

        MFMailComposeViewController *controller =
            [[MFMailComposeViewController alloc] init];

        controller.mailComposeDelegate = self;

        [controller setToRecipients:
            @[@"ask@mcc.tu-berlin.de"]];

        [controller setSubject:
            NSLocalizedString(
                @"Feedback SimRa",
                @"Feedback SimRa"
            )];

        [controller setMessageBody:
            NSLocalizedString(
                @"Dear SimRa Team",
                @"Dear SimRa Team"
            )
            isHTML:NO];

        [self presentViewController:controller
                           animated:YES
                         completion:nil];

        return;
    }

    self.ac =
        [UIAlertController
            alertControllerWithTitle:
                NSLocalizedString(
                    @"SimRa",
                    @"SimRa"
                )
            message:
                NSLocalizedString(
                    @"Configure your Email, please!",
                    @"Configure your Email, please!"
                )
            preferredStyle:
                UIAlertControllerStyleAlert];

    [self.ac addAction:
        [UIAlertAction
            actionWithTitle:
                NSLocalizedString(
                    @"OK",
                    @"OK"
                )
            style:UIAlertActionStyleDefault
            handler:nil]];

    [self presentViewController:self.ac
                       animated:YES
                     completion:nil];
}

- (IBAction)imprintPressed:(UIButton *)sender {

    [[AppDelegate sharedDelegate]
        openURL:@{
            @"en":
                @"https://www.tu.berlin/en/footer/site-credits",
            @"de":
                @"https://www.tu.berlin/footer/impressum"
        }];
}

- (IBAction)openBikeSensorSwitch:(id)sender {
}

- (IBAction)btnOpenBikeSensorSettings:(id)sender {
}

#pragma mark - Mail

- (void)mailComposeController:
            (MFMailComposeViewController *)controller
      didFinishWithResult:
            (MFMailComposeResult)result
                    error:
            (NSError *)error {

    if (error) {
        NSLog(
            @"Mail composer error: %@",
            error
        );
    }

    [self dismissViewControllerAnimated:YES
                             completion:nil];
}

@end
