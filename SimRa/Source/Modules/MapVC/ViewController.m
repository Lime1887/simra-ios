//
//  ViewController.m
//  simra
//
//  Created by Christoph Krey on 27.03.19.
//  Copyright © 2019-2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

#import "ViewController.h"
#import "AppDelegate.h"
#import "Trips.h"
#import "AnnotationView.h"
#import "NSTimeInterval+hms.h"
#import "MyTripsTVC.h"
#import "News.h"
#import "Regions.h"
#import "BLEManager.h"
@interface MyAnnotation: NSObject <MKAnnotation>
@property (strong, nonatomic) CLLocation *location;
- (instancetype)initWithLocation:(CLLocation *)location;
@end

@implementation MyAnnotation
- (CLLocationCoordinate2D)coordinate {
    return self.location.coordinate;
}

- (instancetype)initWithLocation:(CLLocation *)location {
    self = [super init];
    self.location = location;
    return self;
}
@end

@interface ViewController ()
{
    CBCharacteristic * closePassCharacteristic;
    CBUUID *closePassCharacteristicCBUUID;
    CBCharacteristic *sensorDistanceCharacteristic;
    CBUUID *sensorDistanceCharacteristicCBUUID;
}
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *playButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *stopButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *dummyButton;

@property (strong, nonatomic) MKUserTrackingButton *trackingButton;
@property (strong, nonatomic) Trip *trip;
@property (strong, nonatomic) Trip *recordedTrip;

@property (strong, nonatomic) AnnotationView *annotationView;
@property (strong, nonatomic) MyAnnotation *myAnnotation;

@property (strong, nonatomic) UIAlertController *ac;
@property (nonatomic) NSInteger queued;
@property (strong, nonatomic) UIButton *openBikeSensorConfigButton;
@property (strong, nonatomic) UIButton *recordActionButton;
@property (strong, nonatomic) NSDate *recordingStartedAt;
@property (strong, nonatomic) NSTimer *recordingDisplayTimer;

@property (nonatomic) BOOL initialMessagePassed;

@end

@implementation ViewController
@synthesize bleManager;

- (NSString *)recordingStatusText {
    if (!self.trip) {
        return NSLocalizedString(@"Not Recording", @"Not Recording");
    }

    NSTimeInterval seconds = 0;
    NSInteger meters = 0;

    if (self.trip.lastLocation && self.trip.startLocation) {
        AppDelegate *ad = [AppDelegate sharedDelegate];
        NSInteger deferredSecs = [ad.defaults integerForKey:@"deferredSecs"];
        seconds = [self.trip.lastLocation.timestamp timeIntervalSinceDate:self.trip.startLocation.timestamp] - deferredSecs;
        NSInteger deferredMeters = [ad.defaults integerForKey:@"deferredMeters"];
        meters = [self.trip.lastLocation distanceFromLocation:self.trip.startLocation] - deferredMeters;
    } else if (self.recordingStartedAt) {
        seconds = [[NSDate date] timeIntervalSinceDate:self.recordingStartedAt];
    }

    if (seconds < 0) {
        seconds = 0;
    }
    if (meters < 0) {
        meters = 0;
    }

    return [NSString stringWithFormat:@"%@ / %ld m",
            hms(seconds),
            (long)meters];
}

- (UIColor *)controlForegroundColor {
    return [UIColor blackColor];
}

- (UIColor *)systemTintColor {
    return [UIColor systemBlueColor];
}

- (void)styleFloatingControl:(UIView *)control {
    control.layer.shadowColor = [UIColor blackColor].CGColor;
    control.layer.shadowOpacity = 0.14;
    control.layer.shadowRadius = 18.0;
    control.layer.shadowOffset = CGSizeMake(0.0, 8.0);
}

- (void)startRecordingDisplayTimer {
    [self stopRecordingDisplayTimer];
    __weak typeof(self) weakSelf = self;
    self.recordingDisplayTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                                 repeats:YES
                                                                   block:^(NSTimer *timer) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf.trip) {
            [strongSelf updateRecordingControlState];
        } else {
            [strongSelf stopRecordingDisplayTimer];
        }
    }];
}

- (void)stopRecordingDisplayTimer {
    [self.recordingDisplayTimer invalidate];
    self.recordingDisplayTimer = nil;
    self.recordingStartedAt = nil;
}

- (UIButtonConfiguration *)navigationButtonConfigurationWithSymbol:(NSString *)symbolName API_AVAILABLE(ios(15.0)) {
    UIButtonConfiguration *config;
    if (@available(iOS 26.0, *)) {
        config = [UIButtonConfiguration glassButtonConfiguration];
    } else {
        config = [UIButtonConfiguration borderedButtonConfiguration];
    }
    config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    config.image = [UIImage systemImageNamed:symbolName];
    config.contentInsets = NSDirectionalEdgeInsetsMake(8.0, 8.0, 8.0, 8.0);
    config.baseForegroundColor = [self systemTintColor];
    return config;
}

- (UIBarButtonItem *)barButtonItemWithSymbol:(NSString *)symbolName
                                       title:(NSString *)title
                                      target:(id)target
                                      action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.accessibilityLabel = title;
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];

    if (@available(iOS 15.0, *)) {
        button.configuration = [self navigationButtonConfigurationWithSymbol:symbolName];
    } else {
        [button setImage:[UIImage systemImageNamed:symbolName] forState:UIControlStateNormal];
        button.tintColor = [self systemTintColor];
    }
    [self styleFloatingControl:button];

    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:36.0],
        [button.heightAnchor constraintEqualToConstant:36.0],
    ]];

    return [[UIBarButtonItem alloc] initWithCustomView:button];
}

- (void)setupNavigationButtons {
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    self.navigationItem.leftBarButtonItem = [self barButtonItemWithSymbol:@"gearshape.fill"
                                                                    title:NSLocalizedString(@"Settings", @"Settings")
                                                                   target:self
                                                                   action:@selector(settingsButtonPressed)];
    self.navigationItem.rightBarButtonItem = [self barButtonItemWithSymbol:@"list.bullet"
                                                                   title:NSLocalizedString(@"Trips", @"Trips")
                                                                  target:self
                                                                  action:@selector(tripsButtonPressed)];
}

- (void)settingsButtonPressed {
    [self performSegueWithIdentifier:@"showSettings" sender:nil];
}

- (void)tripsButtonPressed {
    self.recordedTrip = nil;
    [self performSegueWithIdentifier:@"trips:" sender:self];
}

- (UIButtonConfiguration *)recordActionButtonConfigurationForRecording:(BOOL)recording API_AVAILABLE(ios(15.0)) {
    UIButtonConfiguration *config;
    
    if (@available(iOS 26.0, *)) {
        // Native Glass Configuration für iOS 26+
        config = [UIButtonConfiguration glassButtonConfiguration];
    } else {
        // Fallback: Tinted Capsule-Look für iOS 15+
        config = [UIButtonConfiguration tintedButtonConfiguration];
    }

    config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    config.imagePadding = 10.0;
    config.contentInsets = NSDirectionalEdgeInsetsMake(14.0, 24.0, 14.0, 24.0);

    if (recording) {
        config.title = NSLocalizedString(@"Stop", @"Stop");
        config.image = [UIImage systemImageNamed:@"stop.fill"];
        config.subtitle = [self recordingStatusText];
        
        // Dezent getöntes Liquid-Rot/Orange für Stopp (kein haptisches/mattes Knallrot)
        config.baseBackgroundColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.25];
        config.baseForegroundColor = [UIColor systemRedColor];
    } else {
        config.title = NSLocalizedString(@"Start Ride", @"Start Ride");
        config.image = [UIImage systemImageNamed:@"play.fill"];
        config.subtitle = nil;
        
        // Dezent getöntes Liquid-Grün für Start
        config.baseBackgroundColor = [[UIColor systemGreenColor] colorWithAlphaComponent:0.25];
        config.baseForegroundColor = [UIColor systemGreenColor];
    }

    return config;
}

- (void)updateRecordingControlState {
    BOOL recording = self.trip != nil;
    self.dummyButton.title = [self recordingStatusText];

    if (@available(iOS 15.0, *)) {
        self.recordActionButton.configuration = [self recordActionButtonConfigurationForRecording:recording];
    } else {
        if (recording) {
            [self.recordActionButton setTitle:NSLocalizedString(@"Stop", @"Stop") forState:UIControlStateNormal];
            [self.recordActionButton setImage:[UIImage systemImageNamed:@"stop.fill"] forState:UIControlStateNormal];
        } else {
            [self.recordActionButton setTitle:NSLocalizedString(@"Start Ride", @"Start Ride") forState:UIControlStateNormal];
            [self.recordActionButton setImage:[UIImage systemImageNamed:@"play.fill"] forState:UIControlStateNormal];
        }
    }

    if (@available(iOS 14.0, *)) {
        self.recordActionButton.role = UIButtonRoleNormal;
    }
}

- (void)recordActionButtonPressed:(UIButton *)sender {
    if (self.trip) {
        [self stopButtonPressed:nil];
    } else {
        [self playButtonPressed:nil];
    }
}

- (void)setupRecordingControls {
    if (self.recordActionButton) {
        return;
    }

    self.navigationController.toolbarHidden = YES;
    self.toolbarItems = @[];

    UIButton *actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    actionButton.tintColor = [self controlForegroundColor];
    if (@available(iOS 15.0, *)) {
        actionButton.configuration = [self recordActionButtonConfigurationForRecording:NO];
    } else {
        [actionButton setTitle:NSLocalizedString(@"Start Ride", @"Start Ride") forState:UIControlStateNormal];
        [actionButton setImage:[UIImage systemImageNamed:@"play.fill"] forState:UIControlStateNormal];
        actionButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    }
    [self styleFloatingControl:actionButton];

    [actionButton addTarget:self action:@selector(recordActionButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:actionButton];

    [NSLayoutConstraint activateConstraints:@[
        [actionButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [actionButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16.0],
    ]];

    self.recordActionButton = actionButton;
    [self updateRecordingControlState];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.mapView.delegate = self;
    self.mapView.showsScale = TRUE;
    self.mapView.showsCompass = TRUE;
    self.mapView.showsUserLocation = TRUE;
    self.mapView.userTrackingMode = MKUserTrackingModeFollow;
    
    self.trackingButton = [MKUserTrackingButton userTrackingButtonWithMapView:self.mapView];
    self.trackingButton.translatesAutoresizingMaskIntoConstraints = false;
    self.trackingButton.tintColor = [self systemTintColor];
    [self styleFloatingControl:self.trackingButton];
    [self.view addSubview:self.trackingButton];
    NSLayoutConstraint *a = [NSLayoutConstraint constraintWithItem:self.trackingButton
                                                         attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual
                                                            toItem:self.view.safeAreaLayoutGuide
                                                         attribute:NSLayoutAttributeBottom
                                                        multiplier:1
                                                          constant:-10];
    NSLayoutConstraint *b = [NSLayoutConstraint constraintWithItem:self.trackingButton
                                                         attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual
                                                            toItem:self.view.safeAreaLayoutGuide
                                                         attribute:NSLayoutAttributeTrailing
                                                        multiplier:1
                                                          constant:-10];

    [NSLayoutConstraint activateConstraints:@[a, b]];
    [self setupOpenBikeSensor];
    [self setupNavigationButtons];
    [self setupRecordingControls];
    self.playButton.enabled = TRUE;
    self.stopButton.enabled = FALSE;
    self.navigationItem.leftBarButtonItem.enabled = TRUE;
    self.navigationItem.rightBarButtonItem.enabled = TRUE;

    self.dummyButton.title = NSLocalizedString(@"Not Recording", @"Not Recording");

    AppDelegate *ad = [AppDelegate sharedDelegate];
    

    [ad.news addObserver:self
              forKeyPath:@"newsVersion"
                 options:NSKeyValueObservingOptionNew
                 context:nil];
    [ad.regions addObserver:self
                 forKeyPath:@"loaded"
                    options:NSKeyValueObservingOptionNew
                    context:nil];
    [self setupBluetooth];

//    bleManager = BluetoothManager.shared;
    
//    NSLog(@"%@",test.someProperty);
}

-(void)setupBluetooth{
    bleManager = [BluetoothManager getInstance];
    if (bleManager.connectedPeripheral != nil){
        [bleManager disconnectPeripheral];
    }
    closePassCharacteristicCBUUID = [CBUUID UUIDWithString: @"1FE7FAF9-CE63-4236-0004-000000000003"];
    sensorDistanceCharacteristicCBUUID = [CBUUID UUIDWithString: @"1FE7FAF9-CE63-4236-0004-000000000002"];

}

-(void)setupConnectedBluetoothDevice{
    if ([self.bleManager connected]){
        [self.bleManager showConnectedState];
        bleManager.delegate = self;
        NSArray *serviceArr = [NSArray arrayWithObject:closePassCharacteristicCBUUID];
        [self.bleManager.connectedPeripheral discoverServices:serviceArr];
    }
}

-(void)viewDidDisappear:(BOOL)animated{
}

-(void)viewWillAppear:(BOOL)animated{
    AppDelegate *ad = [AppDelegate sharedDelegate];
    BOOL showHideOpenBikeSensor = [ad.defaults boolForKey:@"openBikeSensor"];
    [self showHideOpenBikeSensorConfigButton:showHideOpenBikeSensor];
    [self setupConnectedBluetoothDevice];
}

- (void)viewDidAppear:(BOOL)animated {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    if (![ad.defaults boolForKey:@"initialMessage"]) {
        [Utility saveBoolWithKey:@"initialMessage" value:TRUE];

        self.ac = [UIAlertController
                   alertControllerWithTitle:NSLocalizedString(@"How To", @"How To")
                   message:[NSString stringWithFormat:@"%@\n\n%@",
                            NSLocalizedString(@"Would you like to view the User Manual now?", @"Would you like to view the User Manual now?"),
                            NSLocalizedString(@"If not, you may access it via Settings/How To later", @"If not, you may access it via Settings/How To")
                            ]
                   preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *aay = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK")
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * _Nonnull action) {
            [ad showHowTo];
            self.initialMessagePassed = TRUE;
            [self checkRegions];
        }];
        [self.ac addAction:aay];

        UIAlertAction *aac = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel")
                                                      style:UIAlertActionStyleCancel
                                                    handler:^(UIAlertAction * _Nonnull action) {
            self.initialMessagePassed = TRUE;
            [self checkRegions];
        }];
        [self.ac addAction:aac];
        [self presentViewController:self.ac animated:TRUE completion:nil];
    } else {
        self.initialMessagePassed = TRUE;
        [self checkRegions];
    }
    [self checkRegions];
}

-(void)setupOpenBikeSensor{
    self.openBikeSensorConfigButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.openBikeSensorConfigButton.translatesAutoresizingMaskIntoConstraints = false;
    self.openBikeSensorConfigButton.tintColor = [self systemTintColor];
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *config = [self navigationButtonConfigurationWithSymbol:@"sensor.tag.radiowaves.forward"];
        self.openBikeSensorConfigButton.configuration = config;
    } else {
        [self.openBikeSensorConfigButton setImage:[UIImage imageNamed:@"bluetooth"] forState:UIControlStateNormal];
    }
    [self styleFloatingControl:self.openBikeSensorConfigButton];
    [self.openBikeSensorConfigButton addTarget:self action:@selector(didTapOnOBSConfig) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.openBikeSensorConfigButton];
    NSLayoutConstraint *bottomConstraintOBS = [NSLayoutConstraint constraintWithItem:self.openBikeSensorConfigButton
                                                                           attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual
                                                                              toItem:self.view.safeAreaLayoutGuide
                                                                           attribute:NSLayoutAttributeBottom
                                                                          multiplier:1
                                                                            constant:-70];
    NSLayoutConstraint *trainlingConstraintOBS = [NSLayoutConstraint constraintWithItem:self.openBikeSensorConfigButton
                                                                              attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual
                                                                                 toItem:self.view.safeAreaLayoutGuide
                                                                              attribute:NSLayoutAttributeTrailing
                                                                             multiplier:1
                                                                               constant:-10];
    NSLayoutConstraint *widthConstraintOBS = [NSLayoutConstraint constraintWithItem:self.openBikeSensorConfigButton
                                                                          attribute:NSLayoutAttributeWidth
                                                                          relatedBy:NSLayoutRelationEqual
                                                                             toItem:nil
                                                                          attribute: NSLayoutAttributeNotAnAttribute
                                                                         multiplier:1
                                                                           constant:40];
    NSLayoutConstraint *heightConstraintOBS = [NSLayoutConstraint constraintWithItem:self.openBikeSensorConfigButton
                                                                           attribute:NSLayoutAttributeHeight
                                                                           relatedBy:NSLayoutRelationEqual
                                                                              toItem:nil
                                                                           attribute: NSLayoutAttributeNotAnAttribute
                                                                          multiplier:1
                                                                            constant:40];
    
    [NSLayoutConstraint activateConstraints:@[bottomConstraintOBS,trainlingConstraintOBS,widthConstraintOBS,heightConstraintOBS]];
}

-(void)didTapOnOBSConfig{
    [self performSegueWithIdentifier:@"obsConfig" sender:self];
    
}

-(void)showHideOpenBikeSensorConfigButton:(BOOL)showBtn{
    [self.openBikeSensorConfigButton setHidden:!showBtn];
}

- (void)checkRegions {
    if (!self.initialMessagePassed) {
        return;
    }
    
    AppDelegate *ad = [AppDelegate sharedDelegate];
    if (!ad.regions.loaded) {
        return;
    }

    if ([ad.defaults boolForKey:@"suppressRegionMessage"]) {
        return;
    }

    if (ad.regions.closestsRegions) {
        return;
    }

    CLLocation *myLocation = self.mapView.userLocation.location;
    [ad.regions computeClosestsRegions:myLocation];

    if (![ad.defaults boolForKey:@"onceRegionMessage"] ||
        (ad.regions.regionsId > ad.regions.lastSeenRegionsId &&
            (ad.regions.regionId == 0 || [ad.regions.currentRegion.identifier isEqualToString:@"other"])
         ) || !ad.regions.selectedIsOneOfThe3ClosestsRegions) {
        [Utility saveBoolWithKey:@"onceRegionMessage" value:TRUE];

        [ad.regions seen];

        NSString *message = [NSString stringWithFormat:@"%@ %@",
                             NSLocalizedString(@"Please choose your correct region, so that we can analyse your ride correctly. Your selected region:",
                                                       @"Please choose your correct region, so that we can analyse your ride correctly. Your selected region:"),
                             ad.regions.regionId == 0 ? ad.regions.currentRegion.identifier : ad.regions.currentRegion.localizedDescription];
        self.ac = [UIAlertController
                   alertControllerWithTitle:NSLocalizedString(@"Please choose a Region",
                                                              @"Please choose a Region")
                   message: message
                   preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *aad = [UIAlertAction actionWithTitle:NSLocalizedString(@"Don't show this again",
                                                                              @"Don't show this again")
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * _Nonnull action) {
            [Utility saveBoolWithKey:@"suppressRegionMessage" value:TRUE];

        }];
        [self.ac addAction:aad];

        UIAlertAction *aal = [UIAlertAction actionWithTitle:NSLocalizedString(@"Later", @"Later")
                                                      style:UIAlertActionStyleDefault
                                                    handler:nil];
        [self.ac addAction:aal];

        UIAlertAction *aay = [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", @"Yes")
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * _Nonnull action) {
            [self performSegueWithIdentifier:@"editRegion" sender:nil];
        }];
        [self.ac addAction:aay];

        [self presentViewController:self.ac animated:TRUE completion:nil];
    }
}

- (IBAction)playButtonPressed:(UIBarButtonItem *)sender {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    self.trip = [ad.trips newTrip];
    self.recordingStartedAt = [NSDate date];
    [self.trip startRecording];

    [self updateRecordingControlState];
    [self startRecordingDisplayTimer];
    self.navigationItem.leftBarButtonItem.enabled = FALSE;
    self.navigationItem.rightBarButtonItem.enabled = FALSE;

    [self.trip addObserver:self
                forKeyPath:@"lastLocation"
                   options:NSKeyValueObservingOptionNew
                   context:nil];
    [self.trip addObserver:self
                forKeyPath:@"lastTripMotion"
                   options:NSKeyValueObservingOptionNew
                   context:nil];
}

- (IBAction)stopButtonPressed:(UIBarButtonItem *)sender {
    [self stopRecordingDisplayTimer];

    [self.trip removeObserver:self
                   forKeyPath:@"lastLocation"];
    [self.trip removeObserver:self
                   forKeyPath:@"lastTripMotion"];

    UIAlertController *ac = [UIAlertController
                                 alertControllerWithTitle:NSLocalizedString(@"Incident Detection Running", @"Incident Detection Running")
                                 message:NSLocalizedString(@"Please wait", @"Please wait")
                                 preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:ac animated:TRUE completion:nil];
    [self.trip stopRecording];
    [ac dismissViewControllerAnimated:TRUE completion:^{
        
        self.recordedTrip = self.trip;
        [self performSegueWithIdentifier:@"trips:" sender:nil];
        
        self.trip = nil;
        
        self.annotationView.recording = FALSE;
        self.annotationView.speed = 0.0;
        self.annotationView.course = 0.0;
        self.annotationView.accx = 0.0;
        self.annotationView.accy = 0.0;
        self.annotationView.accz = 0.0;
        [self.annotationView setNeedsDisplay];
        
        [self updateRecordingControlState];
        self.navigationItem.leftBarButtonItem.enabled = TRUE;
        self.navigationItem.rightBarButtonItem.enabled = TRUE;
    }];
//    [ac dismissViewControllerAnimated:TRUE completion:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {

    if ([keyPath isEqualToString:@"lastLocation"] ||
        [keyPath isEqualToString:@"lastTripMotion"]) {
        [self performSelectorOnMainThread:@selector(update)
                               withObject:nil
                            waitUntilDone:NO];
        self.queued++;
        //NSLog(@"Queued I: %ld", (long)self.queued);
    }

    if ([keyPath isEqualToString:@"newsVersion"]) {
        [self performSegueWithIdentifier:@"showNews" sender:nil];
    }

    if ([keyPath isEqualToString:@"loaded"]) {
        [self performSelectorOnMainThread:@selector(checkRegions)
                               withObject:nil
                            waitUntilDone:NO];
    }
}

- (IBAction)newsSeen:(UIStoryboardSegue *)unwindSegue {
    AppDelegate *ad = [AppDelegate sharedDelegate];
    [ad.news seen];
    [self dismissViewControllerAnimated:TRUE completion:nil];
}

- (void)update {
    self.queued--;
//    NSLog(@"Queued O: %ld", (long)self.queued);

    if (!self.queued) {
        if (self.annotationView) {
            self.annotationView.recording = self.trip != nil;
            if (self.trip) {
                if (self.trip.lastLocation) {
                    
//                    NSLog(@"update lastLocation %f", self.trip.lastLocation.coordinate.latitude);
                    self.annotationView.speed = self.trip.lastLocation.speed;
                    self.annotationView.course = self.trip.lastLocation.course;
                }
                if (self.trip.lastTripMotion) {
                    //NSLog(@"update lastTripMotion %@", self.trip.lastTripMotion);
                    self.annotationView.accx = self.trip.lastTripMotion.x;
                    self.annotationView.accy = self.trip.lastTripMotion.y;
                    self.annotationView.accz = self.trip.lastTripMotion.z;
                }
            }
            [self.annotationView setNeedsDisplay];
        }

        if (self.trip) {
            [self updateRecordingControlState];
        } else {
            [self updateRecordingControlState];
        }
    }
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView
            viewForAnnotation:(id<MKAnnotation>)annotation {
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        self.annotationView = (AnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"me"];
        if (!self.annotationView) {
            self.annotationView = [[AnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"me"];
        }

        UIImage *image = [UIImage imageNamed:@"pin"];
        self.annotationView.personImage = image;

        self.annotationView.recording = self.trip != nil;
        self.annotationView.speed = 0.0;
        self.annotationView.course = 0.0;
        self.annotationView.accx = 0.0;
        self.annotationView.accy = 0.0;
        self.annotationView.accz = 0.0;
        [self.annotationView setNeedsDisplay];

        return self.annotationView;
    }
    return nil;
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view {
    [self.mapView deselectAnnotation:self.myAnnotation animated:FALSE];
    if (self.trip) {
        [self stopButtonPressed:nil];
    } else {
        [self playButtonPressed:nil];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if (!sender && self.recordedTrip) {
        if ([segue.destinationViewController isKindOfClass:[MyTripsTVC class]]) {
            MyTripsTVC *myTripsTVC = (MyTripsTVC *)segue.destinationViewController;
            myTripsTVC.preselectedTrip = self.recordedTrip;
        }
    }
}

# pragma mark -
# pragma mark - Core Bluetooth

-(void)didDiscoverCharacteritics:(CBService *)service{
    [self connectToClosePassCharacteristic:service];
    [self connectToSensorDistanceCharacteristic:service];
}
-(void)connectToSensorDistanceCharacteristic:(CBService * )service{
    sensorDistanceCharacteristic = [self.bleManager getSpecificCharacteristic:service.UUID :sensorDistanceCharacteristicCBUUID.UUIDString];
    if (sensorDistanceCharacteristic != nil){
        [self.bleManager discoverDescriptor:sensorDistanceCharacteristic];
    }
}
-(void)connectToClosePassCharacteristic:(CBService *)service{
    closePassCharacteristic = [self.bleManager getSpecificCharacteristic:service.UUID :closePassCharacteristicCBUUID.UUIDString];
    if (closePassCharacteristic != nil){
        [self.bleManager discoverDescriptor:closePassCharacteristic];
        [self .bleManager setNotificationWithEnable:YES forCharacteristic:closePassCharacteristic];
    }
}
- (void)didDiscoverDescriptors:(CBCharacteristic *)characteristic{
    if ([characteristic.UUID.UUIDString isEqualToString:closePassCharacteristic.UUID.UUIDString]){
        closePassCharacteristic = characteristic;
    }
    if ([characteristic.UUID.UUIDString isEqualToString:sensorDistanceCharacteristic.UUID.UUIDString]) {
        sensorDistanceCharacteristic = characteristic;
    }
}

- (void)didReadValueForCharacteristic:(CBCharacteristic *)characteristic {
    NSArray<NSNumber *> *byteArray = [self.bleManager getByteArrayWithCharacteristic:characteristic];
    //when the close pass button is pressed
    if ([characteristic.UUID.UUIDString isEqualToString:closePassCharacteristic.UUID.UUIDString]){
        //get left and right sensor values
        NSNumber * leftSensor1Val = byteArray[4];
        NSNumber * leftSensor2Val = byteArray[5];
        // CK: not sure if this is right, may be 6 and 7
        NSNumber * rightSensor1Val = byteArray[1];
        NSNumber * rightSensor2Val = byteArray[1];

        NSNumber * leftSensor = [self.bleManager compareLeftSensorLeastSignificantBitWithBytes:byteArray];
        NSNumber * rightSensor = [self.bleManager compareRightSensorLeastSignificantBitWithBytes:byteArray];

        if (self.trip != nil){
            // if recording the trip, store values in the trip.
            [self.trip storeClosePassValueForTripWithLeftSensorVal:leftSensor
                                                    rightSensorVal:rightSensor
                                                    leftSensor1Val:leftSensor1Val
                                                    leftSensor2Val:leftSensor2Val
                                                   rightSensor1Val:rightSensor1Val
                                                   rightSensor2Val:rightSensor2Val];
        }
    }
    if ([characteristic.UUID.UUIDString isEqualToString:sensorDistanceCharacteristic.UUID.UUIDString]) {
    }
}

- (void)didDiscoverServices:(CBPeripheral *)peripheral{
    [self.bleManager discoverCharacteristics];
}

@end
