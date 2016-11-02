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



@implementation VSOAnnotation

@synthesize coordinate;

- (void)dealloc
{
	NSDLog(@"Deallocing a VSOAnnotation");
}

@end

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


@implementation VSOMapViewController (Private)

- (BOOL)isCurLocOnBordersOfMap
{
	CGPoint p = [mapView convertCoordinate:currentLocation.coordinate toPointToView:mapView];
	if (p.x < mapView.frame.size.width*PERCENT_FOR_MAP_BORDER/100.)  return YES;
	if (p.y < mapView.frame.size.height*PERCENT_FOR_MAP_BORDER/100.) return YES;
	if (p.x > mapView.frame.size.width  - mapView.frame.size.width*PERCENT_FOR_MAP_BORDER/100.)  return YES;
	if (p.y > mapView.frame.size.height - mapView.frame.size.height*PERCENT_FOR_MAP_BORDER/100.) return YES;
	
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
	if (shouldDraw) {
		CGPoint p = [mapView convertCoordinate:c toPointToView:pathAnnotationView];
		[pathAnnotationView addPoint:p createNewPath:addTrackSegOnNextPoint];
		[pathAnnotationView setNeedsDisplay];
	}
	
	if (nTrackSeg == 0) bounds = MKCoordinateRegionMakeWithDistance(c, DEFAULT_SPAN, DEFAULT_SPAN);
	
	if (addTrackSegOnNextPoint) {
		/* Adding track segment */
		nTrackSeg++;
		paths          = realloc(paths, nTrackSeg*sizeof(CLLocationCoordinate2D *));
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
	/* We save the region with a delta, else, because of rounding problems, it is always too big */
	r.span.latitudeDelta  -= r.span.latitudeDelta*0.15;
	r.span.longitudeDelta -= r.span.longitudeDelta*0.15;
	return [NSData dataWithBytes:&r length:sizeof(MKCoordinateRegion)];
}

- (MKCoordinateRegion)regionFromData:(NSData *)dta
{
	if (!dta) return [mapView region];
	return *(MKCoordinateRegion*)[dta bytes];
}

@end

#pragma mark -
@implementation VSOMapViewController
	
@synthesize followULCentersOnTrip, showUL;

+ (BOOL)needsAllPoints
{
	return YES;
}

- (id)init
{
	if ((self = [super init]) != nil) {
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

- (void)settingsChanged:(NSNotification *)n
{
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	
	mapView.mapType = [ud integerForKey:VSO_UDK_MAP_TYPE];
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

- (void)redrawAllPointsOnMap
{
	[pathAnnotationView clearDrawnPoints];
	
	for (NSUInteger i = 0; i<nTrackSeg; i++) [pathAnnotationView addCoords:paths[i] nCoords:pointsDescrInTrack[i].realNumberOfPoints bounds:pointsDescrInTrack[i].bounds];
}

- (void)refreshCurLocPrecision
{
	[curLocAnnotationView setPrecision:[mapView convertRegion:MKCoordinateRegionMakeWithDistance(currentLocation.coordinate, currentLocation.horizontalAccuracy, currentLocation.horizontalAccuracy) toRectToView:curLocAnnotationView].size.width];
}

- (void)refreshInfos
{
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:VSO_ANIM_TIME];
	[UIView setAnimationBeginsFromCurrentState:YES];
	
	/* Refreshes the current user location annotation view */
	curLocAnnotation.coordinate = currentLocation.coordinate;
	[self refreshCurLocPrecision];
	
	[UIView commitAnimations];
	
	[pathAnnotationView setNeedsDisplay];
}

- (void)setCurrentLocation:(CLLocation *)cl
{
	[super setCurrentLocation:cl];
	if (currentLocation == nil || !showUL) return;
	
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
		[pathAnnotationView clearDrawnPoints];
		
		[self freePointsInfos];
		[self allocNewPointInfos];
	} else if (previousState == VSORecordStateStopped && newState == VSORecordStatePaused) {
		addTrackSegOnNextPoint = YES;
	}
}

- (MKAnnotationView *)mapView:(MKMapView *)mpV viewForAnnotation:(id <MKAnnotation>)ann
{
	if (ann == curLocAnnotation) {
		// Try to dequeue an existing loc annotation view first
		curLocAnnotationView = (VSOCurLocationAnnotationView *)[mpV dequeueReusableAnnotationViewWithIdentifier:@"CurLocAnnotation"];
		
		if (!curLocAnnotationView) curLocAnnotationView = [[VSOCurLocationAnnotationView alloc] initWithAnnotation:curLocAnnotation reuseIdentifier:@"CurLocAnnotation"];
		else                       curLocAnnotationView.annotation = curLocAnnotation;
		
		return curLocAnnotationView;
	} else if (ann == pathAnnotation) {
		// Try to dequeue an existing path annotation view first
		pathAnnotationView = (VSOPathAnnotationView *)[mpV dequeueReusableAnnotationViewWithIdentifier:@"PathAnnotation"];
		
		if (!pathAnnotationView) pathAnnotationView = [[VSOPathAnnotationView alloc] initWithAnnotation:pathAnnotation reuseIdentifier:@"PathAnnotation"];
		else                     pathAnnotationView.annotation = pathAnnotation;
		
		pathAnnotationView.map = mpV;
		[self redrawAllPointsOnMap];
		
		return pathAnnotationView;
	}
	
	return nil;
}

- (void)mapView:(MKMapView *)mpV regionWillChangeAnimated:(BOOL)animated
{
	previousRegionSpan = [mpV region].span;
}

- (void)mapView:(MKMapView *)mpV regionDidChangeAnimated:(BOOL)animated
{
	if (mapViewRegionRestored) [[NSUserDefaults standardUserDefaults] setValue:[self dataFromMapRegion] forKey:VSO_UDK_MAP_REGION];
	
	MKCoordinateSpan curSpan = [mpV region].span;
	if (ABS(1. - curSpan.latitudeDelta/ previousRegionSpan.latitudeDelta)  > 0.01 ||
		 ABS(1. - curSpan.longitudeDelta/previousRegionSpan.longitudeDelta) > 0.01) {
		/* The scale of the map changed: The points must be redrawn */
		NSDLog(@"The scale of the map changed. Redrawing points and refreshing loc accuracy.");
		[self redrawAllPointsOnMap];
		
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:VSO_ANIM_TIME];
		[UIView setAnimationBeginsFromCurrentState:YES];
		[self refreshCurLocPrecision];
		[UIView commitAnimations];
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
	
	[self redrawAllPointsOnMap];
}

- (IBAction)centerMapOnCurLoc:(id)sender
{
	[timerToForceFollowUL invalidate]; timerToForceFollowUL = nil;
	
	followingUserLoc = YES;
	settingMapViewRegionByProg = YES;
	if (followULCentersOnTrip) [mapView setRegion:bounds animated:YES];
	else                       [mapView setCenterCoordinate:currentLocation.coordinate animated:YES];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
	[super viewDidLoad];
	NSDLog(@"viewDidLoad in VSOMapViewController");
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged:) name:VSO_NTF_SETTINGS_CHANGED object:nil];
	
	pathAnnotation = [VSOAnnotation new];
	[mapView addAnnotation:pathAnnotation];
	if (showUL) {
		curLocAnnotation = [VSOAnnotation new];
		[mapView addAnnotation:curLocAnnotation];
	} else curLocAnnotation = nil;
	mapView.delegate = self;
	
	mapViewRegionZoomedOnce = NO;
	NSData *regionDta = [[NSUserDefaults standardUserDefaults] valueForKey:VSO_UDK_MAP_REGION];
	if (regionDta != nil) {
		settingMapViewRegionByProg = YES;
		mapView.region = [self regionFromData:regionDta];
		mapViewRegionZoomedOnce = YES;
	}
	mapViewRegionRestored = YES;
	
	[self settingsChanged:nil];
	[self refreshInfos];
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
	
	if (curLocAnnotation != nil) [mapView removeAnnotation:curLocAnnotation];
	if (pathAnnotation != nil) [mapView removeAnnotation:pathAnnotation];
	
	mapView.delegate = nil;
}

@end
