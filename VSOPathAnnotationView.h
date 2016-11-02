//
//  VSOPathAnnotationView.h
//  GPS Stone Trip Recorder
//
//  Created by François Lamboley on 8/7/09.
//  Copyright 2009 VSO-Software. All rights reserved.
//

#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>

@protocol MKMutableAnnotation <MKAnnotation>

- (void)setCoordinate:(CLLocationCoordinate2D)c;

@end


@interface VSOCurLocationAnnotationView : MKAnnotationView {
	CGFloat precision;
}
@property() CGFloat precision;

@end

@interface VSOPathAnnotationView : MKAnnotationView {
	MKMapView *map;
	
	BOOL firstPointAdded;
	
	CGPoint lastAddedPoint;
}
@property(nonatomic, assign) MKMapView *map;
@property(nonatomic, retain) id <MKMutableAnnotation> annotation;
- (void)clearDrawnPoints;
- (void)addPoint:(CGPoint)p createNewPath:(BOOL)createNew;

- (void)addCoords:(CLLocationCoordinate2D *)pts nCoords:(NSUInteger)nPoints bounds:(MKCoordinateRegion)bounds;

@end
