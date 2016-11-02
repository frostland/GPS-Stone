//
//  bounds.h
//  GPS Stone Trip Recorder
//
//  Created by François Lamboley on 7/30/09.
//  Copyright 2009 VSO-Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CLLocation.h>

#import "XMLElement.h"

@interface GPXboundsType : XMLElement {
	CLLocationCoordinate2D minCoords;
	CLLocationCoordinate2D maxCoords;
}
@property(nonatomic, assign) CLLocationCoordinate2D minCoords;
@property(nonatomic, assign) CLLocationCoordinate2D maxCoords;

@end
