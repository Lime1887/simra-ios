//
//  Region.m
//  SimRa
//
//  Created by Christoph Krey on 21.01.20.
//

#import "Region.h"

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
    return [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(lon, lat)
                                       altitude:0.0
                                 horizontalAccuracy:0.0];
}

- (CLLocationDistance)distanceFrom:(CLLocation *)location {
    CLLocationDistance lat1 = [self.lat doubleValue];
    CLLocationDistance lon1 = [self.lon doubleValue];
    CLLocationDistance lat2 = location.latitude;
    CLLocationDistance lon2 = location.longitude;
    
    double dLat = (lat2 - lat1) * M_PI / 180.0;
    double dLon = (lon2 - lon1) * M_PI / 180.0;
    double a = pow(sin(dLat / 2.0), 2.0) + cos(lat1 / 2.0) * cos((lat1 + dLat) / 2.0) * 
               pow(sin(dLon / 2.0), 2.0);
    double c = 2.0 * asin(sqrt(a));
    double r = 6378137.0;
    return r * c;
}

@end
