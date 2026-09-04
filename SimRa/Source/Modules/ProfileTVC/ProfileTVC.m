//
//  ProfileTVC.m
//  SimRa
//
//  Created by Hamza Khan on 21/05/2021.
//  Copyright © 2021 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "ProfileTVC.h"
#import "IdPicker.h"
#import "NSTimeInterval+hms.h"
#import "DSBarChart.h"

@interface ProfileTVC ()

@property (weak, nonatomic) IBOutlet IdPicker *age;
@property (weak, nonatomic) IBOutlet IdPicker *sex;
@property (weak, nonatomic) IBOutlet IdPicker *region;
@property (weak, nonatomic) IBOutlet IdPicker *experience;

@property (weak, nonatomic) IBOutlet UISwitch *behaviourSwitch;
@property (weak, nonatomic) IBOutlet UISlider *behaviourSlider;

@property (weak, nonatomic) IBOutlet UILabel *totalRides;
@property (weak, nonatomic) IBOutlet UILabel *totalLength;
@property (weak, nonatomic) IBOutlet UILabel *averageDistance;
@property (weak, nonatomic) IBOutlet UILabel *totalCO2;
@property (weak, nonatomic) IBOutlet UILabel *totalDuration;
@property (weak, nonatomic) IBOutlet UILabel *totalIdle;
@property (weak, nonatomic) IBOutlet UILabel *averageIdle;
@property (weak, nonatomic) IBOutlet UILabel *averageSpeed;
@property (weak, nonatomic) IBOutlet UILabel *totalIncidents;
@property (weak, nonatomic) IBOutlet UILabel *scaryEvents;

@property (weak, nonatomic) IBOutlet UIView *totalSlots;

@property (strong, nonatomic) UIAlertController *ac;

@end

@implementation ProfileTVC

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    [self configureTableView];
    [self configureControls];
    [self configureLabels];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self loadProfileOptions];
    [self update];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self writeToProfilePlist];
}

#pragma mark - Configuration

- (void)configureTableView {

    /*
     Use the system grouped appearance instead of manually
     painting every visible cell.

     This keeps the view compatible with Light Mode, Dark Mode,
     increased contrast and future UIKit appearance changes.
     */

    if (@available(iOS 13.0, *)) {
        self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
        self.tableView.sectionHeaderHeight = UITableViewAutomaticDimension;
        self.tableView.sectionFooterHeight = UITableViewAutomaticDimension;
    }

    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = UITableViewAutomaticDimension;

    /*
     Avoid unnecessary automatic content inset adjustments
     from older table-view configurations.
     */

    self.tableView.estimatedRowHeight = 56.0;
    self.tableView.estimatedSectionHeaderHeight = 32.0;
    self.tableView.estimatedSectionFooterHeight = 12.0;
}

- (void)configureControls {

    /*
     Do not hard-code systemBlueColor here.

     UIColor.tintColor allows the app/system appearance to
     determine the actual accent color.
     */

    self.view.tintColor = UIColor.tintColor;

    if (@available(iOS 13.0, *)) {
        self.behaviourSlider.minimumTrackTintColor = UIColor.tintColor;
    } else {
        self.behaviourSlider.minimumTrackTintColor = nil;
    }

    /*
     UISwitch already uses the system tint behavior.
     We therefore deliberately avoid assigning a fixed
     onTintColor.
     */

    self.behaviourSwitch.onTintColor = UIColor.tintColor;

    /*
     Make the controls more comfortable for Dynamic Type and
     modern iOS layouts.
     */

    self.behaviourSlider.accessibilityLabel =
        NSLocalizedString(@"Driving behaviour", @"Driving behaviour");

    self.behaviourSwitch.accessibilityLabel =
        NSLocalizedString(@"Record driving behaviour", @"Record driving behaviour");
}

- (void)configureLabels {

    /*
     Use Dynamic Type for statistic values where possible.
     The storyboard can still override these if required.
     */

    self.totalRides.adjustsFontForContentSizeCategory = YES;
    self.totalLength.adjustsFontForContentSizeCategory = YES;
    self.averageDistance.adjustsFontForContentSizeCategory = YES;
    self.totalCO2.adjustsFontForContentSizeCategory = YES;
    self.totalDuration.adjustsFontForContentSizeCategory = YES;
    self.totalIdle.adjustsFontForContentSizeCategory = YES;
    self.averageIdle.adjustsFontForContentSizeCategory = YES;
    self.averageSpeed.adjustsFontForContentSizeCategory = YES;
    self.totalIncidents.adjustsFontForContentSizeCategory = YES;
    self.scaryEvents.adjustsFontForContentSizeCategory = YES;
}

#pragma mark - Profile Options

- (void)loadProfileOptions {

    AppDelegate *ad = [AppDelegate sharedDelegate];

    if (!ad) {
        return;
    }

    self.age.array =
        [ad.constants valueForKey:@"ages"];

    self.sex.array =
        [ad.constants valueForKey:@"sexes"];

    self.region.array =
        [ad.regions regionTextsSorted];

    self.experience.array =
        [ad.constants valueForKey:@"experiences"];
}

#pragma mark - Update

- (void)update {

    AppDelegate *ad = [AppDelegate sharedDelegate];

    if (!ad) {
        return;
    }

    [self updateProfileSelection:ad];
    [self updateBehaviour:ad];
    [self updateStatistics:ad];
    [self updateChart:ad];
}

#pragma mark - Profile

- (void)updateProfileSelection:(AppDelegate *)ad {

    self.age.arrayIndex =
        [ad.defaults integerForKey:@"ageId"];

    self.sex.arrayIndex =
        [ad.defaults integerForKey:@"sexId"];

    self.region.arrayIndex =
        ad.regions.indexForRegionId;

    /*
     The selected region can be invalid or outside the three
     closest regions.

     Do not use hard red text as the only indication. Orange
     is less aggressive and better communicates a warning.
     */

    BOOL validRegion =
        ad.regions.regionSelected &&
        ![ad.regions.currentRegion.identifier isEqualToString:@"other"] &&
        ad.regions.selectedIsOneOfThe3ClosestsRegions;

    if (@available(iOS 13.0, *)) {

        self.region.textColor =
            validRegion
                ? UIColor.labelColor
                : UIColor.systemOrangeColor;

    } else {

        self.region.textColor =
            validRegion
                ? UIColor.darkTextColor
                : UIColor.orangeColor;
    }

    self.experience.arrayIndex =
        [ad.defaults integerForKey:@"experienceId"];
}

#pragma mark - Behaviour

- (void)updateBehaviour:(AppDelegate *)ad {

    BOOL behaviourEnabled =
        [ad.defaults boolForKey:@"behaviour"];

    self.behaviourSwitch.on =
        behaviourEnabled;

    self.behaviourSlider.enabled =
        behaviourEnabled;

    self.behaviourSlider.value =
        [ad.defaults integerForKey:@"behaviourValue"];

    /*
     Keep the disabled state visually subordinate without
     replacing the system control appearance.
     */

    self.behaviourSlider.alpha =
        behaviourEnabled ? 1.0 : 0.5;
}

#pragma mark - Statistics

- (void)updateStatistics:(AppDelegate *)ad {

    NSUserDefaults *defaults =
        ad.defaults;

    NSInteger rideCount =
        [defaults stringForKey:@"totalRides"].integerValue;

    double totalLengthMeters =
        [defaults doubleForKey:@"totalLength"];

    double totalLengthKilometers =
        totalLengthMeters / 1000.0;

    double totalIdleMilliseconds =
        [defaults doubleForKey:@"totalIdle"];

    double totalDurationMilliseconds =
        [defaults doubleForKey:@"totalDuration"];

    double totalIdleSeconds =
        totalIdleMilliseconds / 1000.0;

    double totalDurationSeconds =
        totalDurationMilliseconds / 1000.0;

    /*
     Total idle time
     */

    self.totalIdle.text =
        hms(totalIdleSeconds);

    /*
     Average idle time
     */

    if (rideCount > 0) {

        self.averageIdle.text =
            hms(totalIdleSeconds / rideCount);

    } else {

        self.averageIdle.text =
            @"0:00";
    }

    /*
     Total rides
     */

    self.totalRides.text =
        [defaults stringForKey:@"totalRides"] ?: @"0";

    /*
     Total distance
     */

    self.totalLength.text =
        [self localizedDistanceString:totalLengthKilometers];

    /*
     Average distance
     */

    if (rideCount > 0) {

        double averageDistance =
            totalLengthKilometers / rideCount;

        self.averageDistance.text =
            [self localizedDistanceString:averageDistance];

    } else {

        self.averageDistance.text =
            [self localizedDistanceString:0.0];
    }

    /*
     CO₂ calculation.

     Existing SimRa calculation is deliberately preserved:
     0.138 kg CO₂ per kilometer.
     */

    double totalCO2 =
        totalLengthKilometers * 0.138;

    self.totalCO2.text =
        [self localizedCO2String:totalCO2];

    /*
     Total duration
     */

    self.totalDuration.text =
        hms(totalDurationSeconds);

    /*
     Average moving speed

     Idle time is removed from the total duration.
     */

    double movingSeconds =
        totalDurationSeconds -
        totalIdleSeconds;

    if (movingSeconds > 0.0 &&
        totalLengthKilometers >= 0.0) {

        double averageSpeed =
            totalLengthKilometers /
            (movingSeconds / 3600.0);

        self.averageSpeed.text =
            [self localizedSpeedString:averageSpeed];

    } else {

        self.averageSpeed.text =
            [self localizedSpeedString:0.0];
    }

    /*
     Incidents
     */

    self.totalIncidents.text =
        [defaults stringForKey:@"totalIncidents"] ?: @"0";

    /*
     Scary events
     */

    self.scaryEvents.text =
        [defaults stringForKey:@"numberOfScary"] ?: @"0";

    /*
     Accessibility values
     */

    self.totalRides.accessibilityValue =
        self.totalRides.text;

    self.totalLength.accessibilityValue =
        self.totalLength.text;

    self.averageDistance.accessibilityValue =
        self.averageDistance.text;

    self.totalCO2.accessibilityValue =
        self.totalCO2.text;

    self.totalDuration.accessibilityValue =
        self.totalDuration.text;

    self.totalIdle.accessibilityValue =
        self.totalIdle.text;

    self.averageIdle.accessibilityValue =
        self.averageIdle.text;

    self.averageSpeed.accessibilityValue =
        self.averageSpeed.text;

    self.totalIncidents.accessibilityValue =
        self.totalIncidents.text;

    self.scaryEvents.accessibilityValue =
        self.scaryEvents.text;
}

#pragma mark - Formatting

- (NSString *)localizedDistanceString:(double)kilometers {

    if (@available(iOS 13.0, *)) {

        NSNumberFormatter *formatter =
            [[NSNumberFormatter alloc] init];

        formatter.numberStyle =
            NSNumberFormatterDecimalStyle;

        formatter.minimumFractionDigits =
            1;

        formatter.maximumFractionDigits =
            1;

        formatter.locale =
            [NSLocale currentLocale];

        NSString *number =
            [formatter stringFromNumber:@(kilometers)];

        return [NSString stringWithFormat:@"%@ km", number];
    }

    return [NSString stringWithFormat:@"%.1f km", kilometers];
}

- (NSString *)localizedCO2String:(double)kilograms {

    NSNumberFormatter *formatter =
        [[NSNumberFormatter alloc] init];

    formatter.numberStyle =
        NSNumberFormatterDecimalStyle;

    formatter.minimumFractionDigits =
        1;

    formatter.maximumFractionDigits =
        1;

    formatter.locale =
        [NSLocale currentLocale];

    NSString *number =
        [formatter stringFromNumber:@(kilograms)];

    return [NSString stringWithFormat:@"%@ kg", number];
}

- (NSString *)localizedSpeedString:(double)kilometersPerHour {

    NSNumberFormatter *formatter =
        [[NSNumberFormatter alloc] init];

    formatter.numberStyle =
        NSNumberFormatterDecimalStyle;

    formatter.minimumFractionDigits =
        1;

    formatter.maximumFractionDigits =
        1;

    formatter.locale =
        [NSLocale currentLocale];

    NSString *number =
        [formatter stringFromNumber:@(kilometersPerHour)];

    return [NSString stringWithFormat:@"%@ km/h", number];
}

#pragma mark - Chart

- (void)updateChart:(AppDelegate *)ad {

    if (!self.totalSlots) {
        return;
    }

    NSArray *totalSlots =
        [ad.defaults arrayForKey:@"totalSlots"];

    /*
     Remove an existing chart before creating a new one.
     */

    [self.totalSlots.subviews
        makeObjectsPerformSelector:@selector(removeFromSuperview)];

    if (totalSlots.count == 0) {
        return;
    }

    NSArray *totalRefs = @[
        @"00", @"", @"",
        @"03", @"", @"",
        @"06", @"", @"",
        @"09", @"", @"",
        @"12", @"", @"",
        @"15", @"", @"",
        @"18", @"", @"",
        @"21", @"", @"23"
    ];

    /*
     DSBarChart is an existing SimRa dependency, so keep it
     for compatibility.

     The chart color is made dynamic instead of hard-coded
     black.
     */

    UIColor *chartColor;

    if (@available(iOS 13.0, *)) {
        chartColor = UIColor.labelColor;
    } else {
        chartColor = UIColor.blackColor;
    }

    DSBarChart *chart =
        [[DSBarChart alloc]
            initWithFrame:self.totalSlots.bounds
            color:chartColor
            references:totalRefs
            andValues:totalSlots];

    chart.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;

    chart.frame =
        self.totalSlots.bounds;

    [self.totalSlots addSubview:chart];
}

#pragma mark - Persistence

- (void)writeToProfilePlist {

    [Utility writeProfile];
}

#pragma mark - Closest Regions

- (IBAction)closestPressed:(UIButton *)sender {

    AppDelegate *ad = [AppDelegate sharedDelegate];

    if (!ad || ad.regions.closestsRegions.count == 0) {
        return;
    }

    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:
                NSLocalizedString(
                    @"Closest Regions to your Location",
                    @"Closest Regions to your Location"
                )
            message:
                NSLocalizedString(
                    @"Choose the region closest to your location.",
                    @"Choose the region closest to your location."
                )
            preferredStyle:UIAlertControllerStyleActionSheet];

    NSInteger regionCount =
        MIN(ad.regions.closestsRegions.count, 3);

    for (NSInteger n = 0; n < regionCount; n++) {

        UIAlertAction *action =
            [UIAlertAction
                actionWithTitle:
                    [ad.regions.closestsRegions[n] localizedDescription]
                style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {

                    /*
                     Use the existing Regions API directly.
                     This avoids the ambiguous `position` selector
                     caused by treating the region object as `id`.
                     */

                    [ad.regions
                        selectPosition:
                            ad.regions.closestsRegions[n].position];

                    [self update];
                }];

        [alert addAction:action];
    }

    [alert addAction:
        [UIAlertAction
            actionWithTitle:
                NSLocalizedString(
                    @"Cancel",
                    @"Cancel"
                )
            style:UIAlertActionStyleCancel
            handler:nil]];

    /*
     Action sheets require an anchor on iPad.
     */

    if (alert.popoverPresentationController) {

        alert.popoverPresentationController.sourceView =
            sender;

        alert.popoverPresentationController.sourceRect =
            sender.bounds;
    }

    self.ac = alert;

    [self presentViewController:alert
                         animated:YES
                       completion:nil];
}

#pragma mark - Profile Changes

- (IBAction)ageChanged:(IdPicker *)sender {

    [Utility saveIntWithKey:@"ageId"
                      value:sender.arrayIndex];
}

- (IBAction)sexChanged:(IdPicker *)sender {

    [Utility saveIntWithKey:@"sexId"
                      value:sender.arrayIndex];
}

- (IBAction)regionChanged:(IdPicker *)sender {

    AppDelegate *ad =
        [AppDelegate sharedDelegate];

    if (!ad) {
        return;
    }

    [ad.regions selectIdSorted:sender.arrayIndex];

    [self update];
}

- (IBAction)experienceChanged:(IdPicker *)sender {

    [Utility saveIntWithKey:@"experienceId"
                      value:sender.arrayIndex];
}

#pragma mark - Behaviour

- (IBAction)behaviourSwitchChanged:(UISwitch *)sender {

    [Utility saveBoolWithKey:@"behaviour"
                       value:sender.on];

    [self update];
}

- (IBAction)behaviourSliderChanged:(UISlider *)sender {

    NSInteger value =
        (NSInteger)round(sender.value);

    [Utility saveIntWithKey:@"behaviourValue"
                      value:value];

    [self update];
}

@end
