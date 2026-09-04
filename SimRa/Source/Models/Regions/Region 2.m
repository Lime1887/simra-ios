//
//  Region.m
//  SimRa
//
//  Created by Christoph Krey on 21.01.20.
//

#import "Region.h"
#import <CoreLocation/CoreLocation.h>

@implementation Region

- (NSString *)localizedDescription {
    if ([self.englishDescription length] > 0) {
        return self.englishDescription;
    }
    return self.germanDescription ?: @"";
}

- (CLLocation *)location {
    CLLocationDistance lat = [self.lat doubleValue];
    CLLocationDistance lon = [self.lon doubleValue];
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(lat, lon);
    return [[CLLocation alloc] initWithCoordinate:coord
                                         altitude:0.0
                               horizontalAccuracy:0.0
                                 verticalAccuracy:0.0
                                        timestamp:[NSDate date]];
}

- (CLLocationDistance)distanceFrom:(CLLocation *)location {
    CLLocationDistance lat1 = [self.lat doubleValue];
    CLLocationDistance lon1 = [self.lon doubleValue];
    CLLocationDistance lat2 = location.coordinate.latitude;
    CLLocationDistance lon2 = location.coordinate.longitude;

    double dLat = (lat2 - lat1) * M_PI / 180.0;
    double dLon = (lon2 - lon1) * M_PI / 180.0;
    double a = pow(sin(dLat / 2.0), 2.0) + cos(lat1 * M_PI / 180.0) * cos((lat1 + dLat) * M_PI / 180.0) *
               pow(sin(dLon / 2.0), 2.0);
    double c = 2.0 * asin(sqrt(a));
    double r = 6378137.0;
    return r * c;
}

@end
