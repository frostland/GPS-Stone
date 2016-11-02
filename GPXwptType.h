/*
 * wpt.h
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 7/29/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import <Foundation/Foundation.h>
#import <CoreLocation/CLLocation.h>

#import "XMLElement.h"



@interface GPXwptType : XMLElement {
	CLLocationCoordinate2D coords;
}
@property(nonatomic, assign) CLLocationCoordinate2D coords;
+ (GPXwptType *)waypointWithElementName:(NSString *)en coordinates:(CLLocationCoordinate2D)c hAccuracy:(CLLocationAccuracy)hPrecision
										elevation:(CLLocationDistance)elevation vAccuracy:(CLLocationAccuracy)vPrecision
										  heading:(CLLocationDirection)heading date:(NSDate *)date;
- (BOOL)hasHAccuracy;
- (CLLocationAccuracy)hAccuracy;
- (BOOL)hasVAccuracy;
- (CLLocationAccuracy)vAccuracy;
- (BOOL)hasHeading;
- (CLLocationDirection)heading;
- (BOOL)hasElevation;
- (CLLocationDistance)elevation;
- (BOOL)hasDate;
- (NSDate *)date;

@end
