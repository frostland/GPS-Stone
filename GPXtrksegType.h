/*
 * trkseg.h
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 7/30/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import <Foundation/Foundation.h>
#import <CoreLocation/CLLocation.h>

#import "XMLElement.h"
#import "GPXwptType.h"



@interface GPXtrksegType : XMLElement {
	NSArray *cachedPoints;
}
- (GPXwptType *)firstTrackPoint;
- (GPXwptType *)lastTrackPoint;
- (NSArray *)trackPoints;
- (void)removeAllTrackPoints;
- (BOOL)addTrackPointWithCoords:(CLLocationCoordinate2D)coords hPrecision:(CLLocationAccuracy)hPrecision
							 elevation:(CLLocationDistance)elevation vPrecision:(CLLocationAccuracy)vPrecision
								heading:(CLLocationDirection)heading date:(NSDate *)date;

@end
