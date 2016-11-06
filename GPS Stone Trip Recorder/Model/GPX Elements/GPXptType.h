/*
 * pt.h
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 7/30/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import <Foundation/Foundation.h>
#import <CoreLocation/CLLocation.h>

#import "XMLElement.h"



@interface GPXptType : XMLElement

@property(nonatomic, assign) CLLocationCoordinate2D coords;

@end
