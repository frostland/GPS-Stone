/*
 * VSOMapViewController.m
 * GPS Stone Trip Recorder
 *
 * Created by François on 7/11/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import "VSOMapViewController.h"

#import "VSOUtils.h"
#import "Constants.h"
#import "MainViewController.h"


#define DEFAULT_SPAN 3000.
#define PERCENT_FOR_MAP_BORDER 15
#define N_POINTS_BUFFER_INCREMENT 500



@interface VSOMapViewController (Private)

- (BOOL)isCurLocOnBordersOfMap;

- (void)addPointToDraw:(CLLocation *)l draw:(BOOL)shouldDraw;

- (void)allocNewPointInfos;
- (void)freePointsInfos;

- (NSData *)dataFromMapRegion;
- (MKCoordinateRegion)regionFromData:(NSData *)dta;

@end


#pragma mark -
@implementation VSOMapViewController
	
@synthesize followULCentersOnTrip, showUL;

+ (BOOL)needsAllPoints
{
	return YES;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	if ((self = [super initWithCoder:aDecoder]) != nil) {
		[self allocNewPointInfos];
		
		showUL = YES;
		followingUserLoc = YES;
		followULCentersOnTrip = NO;
		mapViewRegionRestored = NO;
		addTrackSegOnNextPoint = YES;
		settingMapViewRegionByProg = YES;
	}
	
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	NSDLog(@"viewDidLoad in VSOMapViewController");
	
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(settingsChanged:) name:VSO_NTF_SETTINGS_CHANGED object:nil];
	
	mapView.delegate = self;
	mapView.showsUserLocation = showUL;
	
	mapViewRegionZoomedOnce = NO;
	NSData *regionDta = [NSUserDefaults.standardUserDefaults valueForKey:VSO_UDK_MAP_REGION];
	if (regionDta != nil) {
		settingMapViewRegionByProg = YES;
		mapView.region = [self regionFromData:regionDta];
		mapViewRegionZoomedOnce = YES;
	}
	mapViewRegionRestored = YES;
	
	[self settingsChanged:nil];
	[self refreshInfos];
}

- (void)settingsChanged:(NSNotification *)n
{
	mapView.mapType = [NSUserDefaults.standardUserDefaults integerForKey:VSO_UDK_MAP_TYPE];
}

- (void)initDrawnPathWithCurrentGPX
{
	[self freePointsInfos];
	[self allocNewPointInfos];
	
	for (GPXtrksegType *curTrackSeg in [[currentGPX firstTrack] trackSegments])
		for (GPXwptType *curPt in [curTrackSeg trackPoints])
			[self addPointToDraw:[[CLLocation alloc] initWithLatitude:curPt.coords.latitude longitude:curPt.coords.longitude]
								 draw:NO];
	
	NSDLog(@"bounds: {{%g, %g}, {%g, %g}}", bounds.center.latitude, bounds.center.longitude, bounds.span.latitudeDelta, bounds.span.longitudeDelta);
}

- (void)redrawLastSegmentOnMap
{
	if (latestPolyline != nil) [mapView removeOverlay:latestPolyline];
	if (nTrackSeg > 0 && pointsDescrInTrack[nTrackSeg-1].realNumberOfPoints > 1) {
		latestPolyline = [MKPolyline polylineWithCoordinates:paths[nTrackSeg-1] count:pointsDescrInTrack[nTrackSeg-1].realNumberOfPoints];
		[mapView addOverlay:latestPolyline];
	}
}

- (void)hideStatusBarBlur
{
	[viewStatusBarBlur removeFromSuperview];
}

- (void)refreshInfos
{
//	[pathAnnotationView setNeedsDisplay];
}

- (void)setCurrentLocation:(CLLocation *)cl
{
	[super setCurrentLocation:cl];
	if (currentLocation == nil) return;
	
	if (nTrackSeg == 0) bounds = MKCoordinateRegionMakeWithDistance(currentLocation.coordinate, DEFAULT_SPAN, DEFAULT_SPAN);
	
	VSORecordState recState = [[currentRecordingInfo valueForKey:VSO_REC_LIST_RECORD_STATE_KEY] unsignedIntValue];
	if (recState == VSORecordStatePaused || recState == VSORecordStateScreenLocked) addTrackSegOnNextPoint = YES;
	
end:
	if (followingUserLoc) {
		if (recState != VSORecordStateRecording || [self isCurLocOnBordersOfMap]) {
			settingMapViewRegionByProg = YES;
			if (mapViewRegionZoomedOnce) [mapView setCenterCoordinate:currentLocation.coordinate animated:YES];
			else                         [mapView setRegion:bounds animated:YES];
			mapViewRegionZoomedOnce = YES;
		}
		
		[buttonCenterMapOnCurLoc setHighlighted:YES];
	}
}

- (void)setCurrentLocation:(CLLocation *)nl pointWasRecorded:(BOOL)pointWasRecorded
{
	[super setCurrentLocation:nl pointWasRecorded:pointWasRecorded];
	if (pointWasRecorded) [self addPointToDraw:currentLocation draw:YES];
}

- (void)recordingStateChangedFrom:(VSORecordState)previousState to:(VSORecordState)newState
{
	if (previousState == VSORecordStateStopped && (newState == VSORecordStateWaitingGPS || newState == VSORecordStateRecording)) {
		[mapView removeOverlays:mapView.overlays];
		
		[self freePointsInfos];
		[self allocNewPointInfos];
	} else if (previousState == VSORecordStateStopped && newState == VSORecordStatePaused) {
		addTrackSegOnNextPoint = YES;
	}
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
{
	if ([overlay isKindOfClass:MKPolyline.class]) {
		pathRenderer = [[MKPolylineRenderer alloc] initWithPolyline:(MKPolyline *)overlay];
		pathRenderer.strokeColor = [UIColor colorWithRed:92./255. green:43./255. blue:153./255. alpha:0.75];
		pathRenderer.lineWidth = 5.;
		if ([mapView.overlays indexOfObjectIdenticalTo:overlay]%2 == 1) {
			/* This is the overlay for a pause */
			pathRenderer.lineDashPattern = @[@12, @16];
		}
		return pathRenderer;
	}
	return nil;
}

- (void)mapView:(MKMapView *)mpV regionWillChangeAnimated:(BOOL)animated
{
	previousRegionSpan = [mpV region].span;
}

- (void)mapView:(MKMapView *)mpV regionDidChangeAnimated:(BOOL)animated
{
	if (mapViewRegionRestored) [NSUserDefaults.standardUserDefaults setValue:self.dataFromMapRegion forKey:VSO_UDK_MAP_REGION];
	
	MKCoordinateSpan curSpan = [mpV region].span;
	if (ABS(1. - curSpan.latitudeDelta/ previousRegionSpan.latitudeDelta)  > 0.01 ||
		 ABS(1. - curSpan.longitudeDelta/previousRegionSpan.longitudeDelta) > 0.01) {
	} else {
		if (!settingMapViewRegionByProg) {
			followingUserLoc = NO;
			[buttonCenterMapOnCurLoc setHighlighted:NO];
		}
	}
	
	settingMapViewRegionByProg = NO;
	[timerToForceFollowUL invalidate];
	timerToForceFollowUL = [NSTimer scheduledTimerWithTimeInterval:10. target:self selector:@selector(centerMapOnCurLoc:) userInfo:NULL repeats:NO];
}

- (NSData *)state
{
	NSMutableData *dta = [NSMutableData data];
	[dta appendData:[self dataFromMapRegion]];
	
	VSORecordState recState = [[currentRecordingInfo valueForKey:VSO_REC_LIST_RECORD_STATE_KEY] unsignedIntValue];
	[dta appendBytes:&recState length:sizeof(VSORecordState)];
	
	[dta appendBytes:&nTrackSeg length:sizeof(NSUInteger)];
	[dta appendBytes:pointsDescrInTrack length:nTrackSeg*sizeof(VSOArrayOfPointsDescr)];
	for (NSUInteger i = 0; i<nTrackSeg; i++)
		[dta appendBytes:paths[i] length:pointsDescrInTrack[i].bufferNumberOfPoints*sizeof(CLLocationCoordinate2D)];
	
	[dta appendBytes:&followingUserLoc length:sizeof(BOOL)];
	
	return dta;
}

- (void)restoreStateFrom:(NSData *)dta
{
	if ((NSNull *)dta == [NSNull null]) return;
	
	[self freePointsInfos];
	
	size_t s;
	const char *bytes = (char *)[dta bytes];
	[mapView setRegion:[self regionFromData:dta]];
	bytes += sizeof(MKCoordinateRegion);
	
	VSORecordState recState = *(VSORecordState*)bytes;
	bytes += sizeof(VSORecordState);
	
	nTrackSeg = *(NSUInteger*)bytes;
	bytes += sizeof(NSUInteger);
	
	s = nTrackSeg*sizeof(VSOArrayOfPointsDescr);
	pointsDescrInTrack = mallocTable(nTrackSeg, sizeof(VSOArrayOfPointsDescr));
	memcpy(pointsDescrInTrack, bytes, s);
	bytes += s;
	
	paths = mallocTable(nTrackSeg, sizeof(CLLocationCoordinate2D*));
	for (NSUInteger i = 0; i<nTrackSeg; i++) {
		s = pointsDescrInTrack[i].bufferNumberOfPoints*sizeof(CLLocationCoordinate2D);
		paths[i] = mallocTable(pointsDescrInTrack[i].bufferNumberOfPoints, sizeof(CLLocationCoordinate2D));
		memcpy(paths[i], bytes, s);
		bytes += s;
	}
	
	followingUserLoc = *(BOOL*)bytes;
	
	NSDLog(@"%d -> %d", recState, [[currentRecordingInfo valueForKey:VSO_REC_LIST_RECORD_STATE_KEY] unsignedIntValue]);
	[self recordingStateChangedFrom:recState to:[[currentRecordingInfo valueForKey:VSO_REC_LIST_RECORD_STATE_KEY] unsignedIntValue]];
	
	addTrackSegOnNextPoint = (nTrackSeg == 0);
	NSArray *storedPoints = [currentRecordingInfo valueForKey:VSO_REC_LIST_STORED_POINTS_FOR_CLASS_KEY([self class])];
	if (storedPoints != nil) {
		for (CLLocation *cl in storedPoints) {
			if ((NSNull *)cl == [NSNull null]) addTrackSegOnNextPoint = YES;
			else                               [self addPointToDraw:cl draw:NO];
		}
	}
	[(NSMutableDictionary*)currentRecordingInfo removeObjectForKey:VSO_REC_LIST_STORED_POINTS_FOR_CLASS_KEY([self class])];
	
	[self redrawLastSegmentOnMap];
}

- (IBAction)centerMapOnCurLoc:(id)sender
{
	[timerToForceFollowUL invalidate]; timerToForceFollowUL = nil;
	
	followingUserLoc = YES;
	settingMapViewRegionByProg = YES;
	if (followULCentersOnTrip) [mapView setRegion:bounds animated:YES];
	else                       [mapView setCenterCoordinate:currentLocation.coordinate animated:YES];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if (buttonIndex != [alertView cancelButtonIndex])
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:VSO_UDK_SHOW_MEMORY_CLEAR_WARNING];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	NSDLog(@"Memory warning in Map View Controller. Cleaning all drawn points.");
	
	if ([[currentRecordingInfo valueForKey:VSO_REC_LIST_RECORD_STATE_KEY] unsignedIntValue] == VSORecordStateStopped) return;
	
	[self freePointsInfos];
	[self allocNewPointInfos];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:VSO_UDK_SHOW_MEMORY_CLEAR_WARNING])
		[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"memory performances", nil) message:NSLocalizedString(@"removing stored points cache for map", nil)
											delegate:self cancelButtonTitle:NSLocalizedString(@"dont show again", nil) otherButtonTitles:NSLocalizedString(@"ok", nil), nil] show];
}

- (void)dealloc
{
	NSDLog(@"Deallocing a VSOMapViewController. mapView retainCount is: <<inaccessible>>");
	/* Note: mapView seems to be never dealloced. I don't know why. */
	
	[self freePointsInfos];
	[timerToForceFollowUL invalidate]; timerToForceFollowUL = nil;
	
	mapView.delegate = nil;
	[mapView removeOverlays:mapView.overlays];
}

@end



@implementation VSOMapViewController (Private)

- (BOOL)isCurLocOnBordersOfMap
{
	CGPoint p = [mapView convertCoordinate:currentLocation.coordinate toPointToView:mapView];
	if (p.x < mapView.frame.size.width  * PERCENT_FOR_MAP_BORDER/100.) return YES;
	if (p.y < mapView.frame.size.height * PERCENT_FOR_MAP_BORDER/100.) return YES;
	if (p.x > mapView.frame.size.width  - mapView.frame.size.width  * PERCENT_FOR_MAP_BORDER/100.) return YES;
	if (p.y > mapView.frame.size.height - mapView.frame.size.height * PERCENT_FOR_MAP_BORDER/100.) return YES;
	
	return NO;
}

- (void)expandBoundsFrom:(MKCoordinateRegion *)r with:(CLLocationCoordinate2D)c
{
	CLLocationDegrees d = c.latitude - (r->center.latitude - r->span.latitudeDelta/2.);
	if (d < 0) {
		r->center.latitude -= -d/2.;
		r->span.latitudeDelta += -d;
	}
	d = c.longitude - (r->center.longitude-r->span.longitudeDelta/2.);
	if (d < 0) {
		r->center.longitude -= -d/2.;
		r->span.longitudeDelta += -d;
	}
	d = (r->center.latitude+r->span.latitudeDelta/2.) - c.latitude;
	if (d < 0) {
		r->center.latitude += -d/2.;
		r->span.latitudeDelta += -d;
	}
	d = (r->center.longitude+r->span.longitudeDelta/2.) - c.longitude;
	if (d < 0) {
		r->center.longitude += -d/2.;
		r->span.longitudeDelta += -d;
	}
}

- (void)addPointToDraw:(CLLocation *)l draw:(BOOL)shouldDraw
{
	CLLocationCoordinate2D c = l.coordinate;
	
	if (nTrackSeg == 0) bounds = MKCoordinateRegionMakeWithDistance(c, DEFAULT_SPAN, DEFAULT_SPAN);
	
	if (addTrackSegOnNextPoint) {
		/* Adding track segment */
		[self redrawLastSegmentOnMap];
		latestPolyline = nil;
		if (nTrackSeg > 0) {
			CLLocationCoordinate2D coordinates[] = {
				paths[nTrackSeg-1][pointsDescrInTrack[nTrackSeg-1].realNumberOfPoints-1],
				l.coordinate
			};
			MKPolyline *polyline = [MKPolyline polylineWithCoordinates:coordinates count:2];
			[mapView addOverlay:polyline];
		}
		
		nTrackSeg++;
		paths              = realloc(paths, nTrackSeg*sizeof(CLLocationCoordinate2D *));
		pointsDescrInTrack = realloc(pointsDescrInTrack, nTrackSeg*sizeof(VSOArrayOfPointsDescr));
		
		pointsDescrInTrack[nTrackSeg-1].bounds = MKCoordinateRegionMakeWithDistance(c, 0., 0.);
		
		pointsDescrInTrack[nTrackSeg-1].realNumberOfPoints = 0;
		pointsDescrInTrack[nTrackSeg-1].bufferNumberOfPoints = N_POINTS_BUFFER_INCREMENT;
		paths[nTrackSeg-1] = mallocTable(pointsDescrInTrack[nTrackSeg-1].bufferNumberOfPoints, sizeof(CLLocationCoordinate2D));
	}
	if (++(pointsDescrInTrack[nTrackSeg-1].realNumberOfPoints) > pointsDescrInTrack[nTrackSeg-1].bufferNumberOfPoints) {
		/* More points than current buffer capacity. Increasing size of buffer */
		pointsDescrInTrack[nTrackSeg-1].bufferNumberOfPoints += N_POINTS_BUFFER_INCREMENT;
		paths[nTrackSeg-1] = realloc(paths[nTrackSeg-1], pointsDescrInTrack[nTrackSeg-1].bufferNumberOfPoints*sizeof(CLLocationCoordinate2D));
	}
	
	[self expandBoundsFrom:&bounds with:c];
	[self expandBoundsFrom:&(pointsDescrInTrack[nTrackSeg-1].bounds) with:c];
	paths[nTrackSeg-1][pointsDescrInTrack[nTrackSeg-1].realNumberOfPoints - 1] = c;
	
	addTrackSegOnNextPoint = NO;
	if (shouldDraw) [self redrawLastSegmentOnMap];
}

- (void)allocNewPointInfos
{
	nTrackSeg = 0;
	addTrackSegOnNextPoint = YES;
	paths = mallocTable(nTrackSeg, sizeof(CLLocationCoordinate2D *));
	pointsDescrInTrack = mallocTable(nTrackSeg, sizeof(VSOArrayOfPointsDescr));
}

- (void)freePointsInfos
{
	free2DTable((void **)paths, nTrackSeg); paths = NULL;
	free(pointsDescrInTrack); pointsDescrInTrack = NULL;
}

- (NSData *)dataFromMapRegion
{
	MKCoordinateRegion r = [mapView region];
	r.span.latitudeDelta  -= r.span.latitudeDelta;
	r.span.longitudeDelta -= r.span.longitudeDelta;
	return [NSData dataWithBytes:&r length:sizeof(MKCoordinateRegion)];
}

- (MKCoordinateRegion)regionFromData:(NSData *)dta
{
	if (!dta) return [mapView region];
	return *(MKCoordinateRegion*)[dta bytes];
}

@end
