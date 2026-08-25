//
//  TripEditVC.m
//  SimRa
//
//  UIKit → SwiftUI bridge for TripEdit.
//

#import "TripEditVC.h"

#import "AnnotationTVC.h"
#import "TripDetailTVC.h"
#import "AppDelegate.h"
#import "SimRa-Swift.h"

@interface TripEditVC () <TripEditViewHostDelegate>

@property (nonatomic, strong) TripEditViewHostController *hostingController;
@property (nonatomic) BOOL initialTripDetailShown;

@end

@implementation TripEditVC

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.systemBackgroundColor;

    [self setupSwiftUIView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    if (self.hostingController) {
        [self reloadSwiftUIView];
    }

    /*
     The original controller automatically opened the trip
     details once for an unuploaded trip.

     Keep that behaviour here so the migration does not
     change the existing navigation flow.
    */
    if (self.trip &&
        !self.trip.uploaded &&
        !self.initialTripDetailShown) {

        self.initialTripDetailShown = YES;

        dispatch_async(dispatch_get_main_queue(), ^{
            [self showTripDetail];
        });
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    /*
     Saving is handled by the SwiftUI view model.
     This method intentionally remains lightweight.
    */
}

#pragma mark - SwiftUI

- (void)setupSwiftUIView
{
    if (!self.trip) {
        return;
    }

    self.hostingController = [[TripEditViewHostController alloc]
                               initWithTrip:self.trip
                               delegate:self];

    [self addChildViewController:self.hostingController];
    self.hostingController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.hostingController.view];
    [NSLayoutConstraint activateConstraints:@[
        [self.hostingController.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.hostingController.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.hostingController.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.hostingController.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    [self.hostingController didMoveToParentViewController:self];
}

- (void)reloadSwiftUIView
{
    if (!self.trip) {
        return;
    }

    /*
     Recreate the root view so SwiftUI receives the current
     Objective-C model state after returning from another
     controller.
    */
    [self.hostingController reload];
}

#pragma mark - Navigation

- (void)tripEditViewHostDidRequestDetails:(TripEditViewHostController *)host
{
    [self showTripDetail];
}

- (void)tripEditViewHost:(TripEditViewHostController *)host
 didRequestAnnotationEdit:(TripPoint *)tripPoint
{
    [self editAnnotation:tripPoint];
}

- (void)showTripDetail
{
    [self performSegueWithIdentifier:@"tripDetail:"
                              sender:nil];
}

- (void)editAnnotation:(TripPoint *)tripPoint
{
    if (!tripPoint) {
        return;
    }

    [self performSegueWithIdentifier:@"editAnnotation:"
                              sender:tripPoint];
}

#pragma mark - Storyboard

- (void)prepareForSegue:(UIStoryboardSegue *)segue
                 sender:(id)sender
{
    if ([segue.destinationViewController
            isKindOfClass:[AnnotationTVC class]] &&
        [sender isKindOfClass:[TripPoint class]]) {

        AnnotationTVC *annotationTVC =
            (AnnotationTVC *)segue.destinationViewController;

        TripPoint *tripPoint =
            (TripPoint *)sender;

        annotationTVC.tripAnnotation =
            tripPoint.tripLocation.tripAnnotation;

        annotationTVC.changed = NO;
    }

    if ([segue.destinationViewController
            isKindOfClass:[TripDetailTVC class]]) {

        TripDetailTVC *tripDetailTVC =
            (TripDetailTVC *)segue.destinationViewController;

        tripDetailTVC.trip = self.trip;
    }
}

#pragma mark - Unwind

- (IBAction)annotationChanged:(UIStoryboardSegue *)unwindSegue
{
    [self reloadSwiftUIView];
}

- (IBAction)attributesChanged:(UIStoryboardSegue *)unwindSegue
{
    [self reloadSwiftUIView];
}

// Previously contained SwiftUI bridge code for modern UI components, now relocated to Swift files.

@end

