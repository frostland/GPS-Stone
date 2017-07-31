/*
 * VSOMapViewController.h
 * GPS Stone Trip Recorder
 *
 * Created by François on 7/11/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>

#import "VSOInfoGenericController.h"



typedef struct VSOArrayOfPointsDescr {
	NSUInteger realNumberOfPoints;
	NSUInteger bufferNumberOfPoints;
	
	MKCoordinateRegion bounds;
} VSOArrayOfPointsDescr;



@interface VSOMapViewController : VSOInfoGenericController <MKMapViewDelegate> {
	IBOutlet UIButton *buttonCenterMapOnCurLoc;
	IBOutlet MKMapView *mapView;
	
	MKPolyline *latestPolyline;
	MKOverlayPathRenderer *pathRenderer;
	
	BOOL showUL;
	BOOL followingUserLoc;
	BOOL followULCentersOnTrip;
	NSTimer *timerToForceFollowUL;
	MKCoordinateRegion bounds;
	
	NSUInteger nTrackSeg;
	/* nPointsInTrack is an array of size nTrackSeg */
	VSOArrayOfPointsDescr *pointsDescrInTrack;
	/* paths is an array of size nTrackSeg of arrays of size nPointsInTrack[i].bufferNumberOfPoints */
	CLLocationCoordinate2D **paths;
	
	BOOL mapViewRegionRestored;
	BOOL mapViewRegionZoomedOnce;
	BOOL settingMapViewRegionByProg;
	MKCoordinateSpan previousRegionSpan;
	
	BOOL addTrackSegOnNextPoint;
}
@property() BOOL showUL;
@property() BOOL followULCentersOnTrip;
- (void)initDrawnPathWithCurrentGPX;
- (void)redrawLastSegmentOnMap;

- (IBAction)centerMapOnCurLoc:(id)sender;

@end
