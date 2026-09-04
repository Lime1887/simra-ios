#import "RecordingShortcutBridge.h"

@implementation RecordingShortcutBridge

+ (nullable ViewController *)findMapViewControllerInController:(UIViewController *)controller
{
    if ([controller isKindOfClass:[ViewController class]]) {
        return (ViewController *)controller;
    }

    for (UIViewController *child in controller.childViewControllers) {
        ViewController *mapViewController = [self findMapViewControllerInController:child];
        if (mapViewController) {
            return mapViewController;
        }
    }

    return nil;
}

+ (nullable ViewController *)mapViewController
{
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }

        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            UIViewController *controller = window.rootViewController;
            while (controller.presentedViewController) {
                controller = controller.presentedViewController;
            }

            ViewController *mapViewController =
                [self findMapViewControllerInController:controller];
            if (mapViewController) {
                return mapViewController;
            }
        }
    }

    return nil;
}

+ (BOOL)startRecording
{
    return [[self mapViewController] startRecordingFromShortcut];
}

+ (BOOL)stopRecording
{
    return [[self mapViewController] stopRecordingFromShortcut];
}

@end
