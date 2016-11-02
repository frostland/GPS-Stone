//
//  MainViewController.m
//  GPS Stone Trip Recorder
//
//  Created by François on 7/10/09.
//  Copyright VSO-Software 2009. All rights reserved.
//

#import "MainViewController.h"
#import "MainView.h"

#import "VSOUtils.h"

#define VSO_TIME_BEFORE_RELEASE_OF_UNUSED_CTRLS 15.

@interface MainViewController (Private)

- (void)loadPreviousRecordingList;
- (void)saveCurrentGpx;

#ifdef SIMULATOR_CODE
- (void)refreshFalseLocation:(NSTimer *)t;
#endif

- (void)updateUI;
- (void)refreshInfoButtonAnimated:(BOOL)aniamte;
- (void)selectPage:(int)p animated:(BOOL)animate;
- (void)loadScrollViewWithPage:(int)page;
- (void)unloadScrollViewPageControllerNumber:(int)p;

- (void)setRecordState:(VSORecordState)s;

- (void)setCurrentGPXOfControllers;
- (void)setCurrentLocationOfControllers:(BOOL)pointWasRecorded;
- (void)setCurrentRecordingInfosOfControllers;
- (void)setCurrentHeadingOfControllers:(CLHeading *)h;

- (void)refreshInfos;
- (void)refreshHeadingInfos;
- (void)refreshCurrentSpeedAverage;
- (void)refreshTimes:(NSTimer *)t;

- (void)resetIdleTimer:(NSNotification *)n;

@end

@interface MainViewController (DoThings)

- (void)addCurrentLocationToCurrentTrack;
- (void)showRecordsList;
- (void)pauseRecording;
- (void)stopRecording;

@end

#pragma mark -
@implementation MainViewController (Private)

- (void)loadPreviousRecordingList
{
	NSFileManager *fm = [NSFileManager defaultManager];
	
	assert(recordState == VSORecordStateStopped);
	
	[recordingList release];
	if (![fm fileExistsAtPath:VSO_PATH_TO_GPX_LIST]) {
		recordingList = [NSMutableArray new];
		return;
	}
	recordingList = [[NSKeyedUnarchiver unarchiveObjectWithData:[NSData dataWithContentsOfFile:VSO_PATH_TO_GPX_LIST]] retain];
	if ([recordingList count] == 0) {
		assert(![fm fileExistsAtPath:VSO_PATH_TO_PAUSED_REC_WITNESS]);
		return;
	}
	
	if ([fm fileExistsAtPath:VSO_PATH_TO_PAUSED_REC_WITNESS]) {
		NSString *path = fullPathFromRelativeForGPXFile([[recordingList objectAtIndex:0] valueForKey:VSO_REC_LIST_PATH_KEY]);
		[currentRecordingInfo release];
		currentRecordingInfo = [[recordingList objectAtIndex:0] retain];
		[recordingList removeObjectAtIndex:0];
		
		[viewControllersStates release];
		viewControllersStates = [[NSKeyedUnarchiver unarchiveObjectWithData:[NSData dataWithContentsOfFile:VSO_PATH_TO_PAUSED_REC_WITNESS]] retain];
		for (NSUInteger i = 0; i<[viewControllers count]; i++) {
			VSOInfoGenericController *curCtrl = [viewControllers objectAtIndex:i];
			if ((NSNull *)curCtrl != [NSNull null])
				[curCtrl restoreStateFrom:[viewControllersStates objectAtIndex:i]];
		}
		[fm removeItemAtPath:VSO_PATH_TO_PAUSED_REC_WITNESS error:NULL];
		
		[currentGpx release];
		currentGpx = [[GPXgpxType alloc] initWithAttributes:[NSDictionary dictionaryWithObjects:[NSArray array] forKeys:[NSArray array]] elementName:@"gpx"];
		[currentGpx addTrack];
		[[currentGpx firstTrack] addTrackSegment];
		currentTracksegment = [[currentGpx firstTrack] lastTrackSegment];
		
		assert(currentGpxOutput == nil);
		assert(currentGpxOutputPath == nil);
		currentGpxOutputPath = [path copy];
		currentGpxOutput = [[NSFileHandle fileHandleForWritingAtPath:path] retain];
		[currentGpxOutput seekToEndOfFile];
		if ([[currentRecordingInfo valueForKey:VSO_REC_LIST_RECORD_STATE_KEY] unsignedIntValue] != VSORecordStatePaused)
			[currentGpxOutput writeData:[currentTracksegment XMLOutputForTagClosing:2]];
		
		[self setRecordState:VSORecordStatePaused];
		[self setCurrentRecordingInfosOfControllers];
		[self setCurrentGPXOfControllers];
		[self beginRecording];
	}
}

- (void)saveCurrentGpx
{
	if (!currentRecordingInfo) return;
	
	if ([recordingList count] > 0 && [[recordingList objectAtIndex:0] valueForKey:VSO_REC_LIST_RECORD_STATE_KEY] != nil)
		[recordingList removeObjectAtIndex:0];
	
	VSORecordState recState = [[currentRecordingInfo valueForKey:VSO_REC_LIST_RECORD_STATE_KEY] unsignedIntValue];
	if (recState == VSORecordStateStopped && [[currentRecordingInfo valueForKey:VSO_REC_LIST_N_REG_POINTS_KEY] unsignedIntValue] == 0) {
		[[NSFileManager defaultManager] removeItemAtPath:fullPathFromRelativeForGPXFile([currentRecordingInfo valueForKey:VSO_REC_LIST_PATH_KEY]) error:NULL];
		return;
	}
	
	NSTimeInterval totalRecordTime = [[currentRecordingInfo valueForKey:VSO_REC_LIST_TOTAL_REC_TIME_BEFORE_LAST_PAUSE_KEY] doubleValue];
	NSTimeInterval ti = -[dateRecordStart timeIntervalSinceNow] + totalRecordTime;
	[currentRecordingInfo setValue:[NSNumber numberWithDouble:ti] forKey:VSO_REC_LIST_TOTAL_REC_TIME_KEY];
	[currentRecordingInfo setValue:[NSDate dateWithTimeIntervalSinceNow:0] forKey:VSO_REC_LIST_DATE_END_KEY];
	if (recState == VSORecordStateStopped) {
		[currentRecordingInfo removeObjectForKey:VSO_REC_LIST_RECORD_STATE_KEY];
		for (Class curClass in ctrlClassesForPages)
			[currentRecordingInfo removeObjectForKey:VSO_REC_LIST_STORED_POINTS_FOR_CLASS_KEY(curClass)];
	}
	
	[recordingList insertObject:currentRecordingInfo atIndex:0];
}

#ifdef SIMULATOR_CODE
/* Simulator code (location generation) */

- (void)refreshFalseLocation:(NSTimer *)t
{
	CGFloat md = 0.00003*105;
	/*	if ([[currentRecordingInfo valueForKey:VSO_REC_LIST_N_REG_POINTS_KEY] unsignedIntValue] > 10) return;*/
	coordinate.latitude  -= ((((CGFloat)random()/RAND_MAX) * (md*2.)) - md);
	coordinate.longitude -= ((((CGFloat)random()/RAND_MAX) * (md*2.)) - md);
	
	CLLocation *newLoc = [[CLLocation alloc] initWithCoordinate:coordinate altitude:((CGFloat)random() / RAND_MAX)*200. - 100. horizontalAccuracy:((CGFloat)random() / RAND_MAX)*0 + 0 verticalAccuracy:((CGFloat)random() / RAND_MAX)*1.5 + 0.5 timestamp:[NSDate dateWithTimeIntervalSinceNow:0]];
	[self locationManager:nil didUpdateToLocation:[[newLoc copy] autorelease] fromLocation:[[currentLocation copy] autorelease]];
}
#endif

- (void)refreshInfoButtonAnimated:(BOOL)animate
{
	/* Setting position of the info button */
	if (animate) {
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:VSO_ANIM_TIME];
	}
	CGRect f = [buttonInfoDark frame];
	switch (selPage) {
		case VSO_PAGE_NUMBER_WITH_MAP:
			buttonInfoDark.alpha  = 0.;
			buttonInfoLight.alpha = 1.;
			break;
		case VSO_PAGE_NUMBER_WITH_DETAILED_INFOS:
			buttonInfoDark.alpha  = 1.;
			buttonInfoLight.alpha = 0.;
			break;
		case VSO_PAGE_NUMBER_WITH_GENERAL_INFOS:
			buttonInfoDark.alpha  = 1.;
			buttonInfoLight.alpha = 0.;
			break;
		default:
			buttonInfoDark.alpha  = 0.;
			buttonInfoLight.alpha = 1.;
	}
	if (selPage == VSO_PAGE_NUMBER_WITH_DETAILED_INFOS) {
		f.origin.x = VSO_INFO_X_POS_FOR_PAGE_WITH_DETAILED_INFOS;
		f.origin.y = VSO_INFO_Y_POS_FOR_PAGE_WITH_DETAILED_INFOS;
	} else {
		f.origin.x = VSO_INFO_X_POS;
		f.origin.y = VSO_INFO_Y_POS;
	}
	[buttonInfoDark  setFrame:f];
	[buttonInfoLight setFrame:f];
	if (animate) [UIView commitAnimations];
}

- (void)selectPage:(int)p animated:(BOOL)animate
{
	[self loadScrollViewWithPage:p];
	
	// update the scroll view to the appropriate page
	CGRect frame = pagesView.frame;
	frame.origin.x = frame.size.width * p;
	frame.origin.y = 0;
	[pagesView scrollRectToVisible:frame animated:animate];
	// Set the boolean used when scrolls originate from the UIPageControl. See scrollViewDidScroll: above.
	pageControlUsed = animate;
	
	[self refreshInfoButtonAnimated:animate];
}

- (void)loadScrollViewWithPage:(int)page
{
	if (page < 0) return;
	if (page >= [pageControl numberOfPages]) return;
	
	// replace the placeholder if necessary
	VSOInfoGenericController *controller = [viewControllers objectAtIndex:page];
	if ((NSNull *)controller == [NSNull null]) {
		controller = [[[ctrlClassesForPages objectAtIndex:page] alloc] initWithGPX:currentGpx location:currentLocation];
		[viewControllers replaceObjectAtIndex:page withObject:controller];
		[controller setCurrentRecordingInfo:currentRecordingInfo];
		controller.delegate = self;
		[controller release];
	}
	
	// add the controller's view to the scroll view
	if (nil == controller.view.superview) {
		CGRect frame = pagesView.frame;
		frame.origin.x = frame.size.width * page;
		frame.origin.y = 0;
		controller.view.frame = frame;
		[pagesView addSubview:controller.view];
		[controller restoreStateFrom:[viewControllersStates objectAtIndex:page]];
	}
}

- (void)unloadScrollViewPageControllerNumber:(int)p
{
	/* We do not unload the current page! */
	if (p == selPage) return;
	if ([viewControllers objectAtIndex:p] != [NSNull null])
		[viewControllersStates replaceObjectAtIndex:p withObject:[(VSOInfoGenericController *)[viewControllers objectAtIndex:p] state]];
	[viewControllers replaceObjectAtIndex:p withObject:[NSNull null]];
}

- (void)unloadAllUnusedScrollViewPageController
{
	for (NSUInteger i = 0; i<[viewControllers count]; i++) [self unloadScrollViewPageControllerNumber:i];
}

- (void)updateUI
{
	switch (recordState) {
		case VSORecordStateWaitingGPS:
			labelMiniInfosRecordingState.text = NSLocalizedString(@"waiting for gps", nil);
			[buttonRecord setImage:[UIImage imageNamed:@"pause_button.png"] forState:UIControlStateNormal];
			[buttonListOfRecordings setImage:[UIImage imageNamed:@"stop_button.png"] forState:UIControlStateNormal];
			break;
		case VSORecordStateRecording:
			[buttonRecord setImage:[UIImage imageNamed:@"pause_button.png"] forState:UIControlStateNormal];
			[buttonListOfRecordings setImage:[UIImage imageNamed:@"stop_button.png"] forState:UIControlStateNormal];
			break;
		case VSORecordStatePaused:
			labelMiniInfosRecordingState.text = NSLocalizedString(@"recording paused", nil);
			[buttonRecord setImage:[UIImage imageNamed:@"record_button.png"] forState:UIControlStateNormal];
			[buttonListOfRecordings setImage:[UIImage imageNamed:@"stop_button.png"] forState:UIControlStateNormal];
			break;
		case VSORecordStateStopped:
			[buttonRecord setImage:[UIImage imageNamed:@"record_button.png"] forState:UIControlStateNormal];
			[buttonListOfRecordings setImage:[UIImage imageNamed:@"recList_button.png"] forState:UIControlStateNormal];
			break;
		default: NSLog(@"What are we doing here??? (in updateUI of the main view controller)");
	}
	
	buttonRecord.enabled = ([locationManager locationServicesEnabled] && recordState != VSORecordStateWaitingGPS);
	
	labelMiniInfosRecordingState.hidden = !(recordState == VSORecordStatePaused || recordState == VSORecordStateWaitingGPS);
	labelMiniInfosRecordTime.hidden = !(recordState == VSORecordStateRecording);
	labelMiniInfosDistance.hidden = !(recordState == VSORecordStateRecording);
	viewMiniInfos.hidden = (recordState == VSORecordStateStopped);
	[self refreshInfos];
	[self refreshTimes:nil];
}

- (void)refreshTimes:(NSTimer *)t;
{
	if (!currentRecordingInfo) return;
	
	NSTimeInterval totalRecordTime = [[currentRecordingInfo valueForKey:VSO_REC_LIST_TOTAL_REC_TIME_BEFORE_LAST_PAUSE_KEY] doubleValue];
	NSTimeInterval ti = -[dateRecordStart timeIntervalSinceNow] + totalRecordTime;
	NSUInteger i = (NSUInteger)ti;
	
	[labelMiniInfosRecordTime setText:NSStringFromTimeInterval(i)];
	[self refreshCurrentSpeedAverage];
}

- (void)refreshInfos
{
	[self refreshCurrentSpeedAverage];
	[[viewControllers objectAtIndex:selPage] refreshInfos];
	
	[labelMiniInfosDistance setText:NSStringFromDistance([[currentRecordingInfo valueForKey:VSO_REC_LIST_TOTAL_REC_DISTANCE_KEY] doubleValue])];
}

- (void)refreshHeadingInfos
{
	[[viewControllers objectAtIndex:selPage] refreshHeadingInfos];
}

- (void)refreshCurrentSpeedAverage
{
	NSTimeInterval totalRecordTime = [[currentRecordingInfo valueForKey:VSO_REC_LIST_TOTAL_REC_TIME_BEFORE_LAST_PAUSE_KEY] doubleValue];
	CLLocationDistance totalRecordDistance = [[currentRecordingInfo valueForKey:VSO_REC_LIST_TOTAL_REC_DISTANCE_KEY] doubleValue];
	NSTimeInterval ti = -[dateRecordStart timeIntervalSinceNow] + totalRecordTime;
	[currentRecordingInfo setValue:[NSNumber numberWithDouble:totalRecordDistance/ti]
									forKey:VSO_REC_LIST_AVERAGE_SPEED_KEY];
	
	/* For informative purpose only */
	[currentRecordingInfo setValue:[NSNumber numberWithDouble:ti] forKey:VSO_REC_LIST_TOTAL_REC_TIME_KEY];
}


- (void)setCurrentLocationOfControllers:(BOOL)pointWasRecorded
{
	NSUInteger n = [viewControllers count];
	for (NSUInteger i = 0; i<n; i++) {
		VSOInfoGenericController *curCtrl = [viewControllers objectAtIndex:i];
		if ((NSNull *)curCtrl != [NSNull null]) {
			[curCtrl setCurrentLocation:currentLocation pointWasRecorded:pointWasRecorded];
		} else if (pointWasRecorded) {
			Class c = [ctrlClassesForPages objectAtIndex:i];
			if ([c needsAllPoints]) {
				NSMutableArray *curStoredPoints = [currentRecordingInfo valueForKey:VSO_REC_LIST_STORED_POINTS_FOR_CLASS_KEY(c)];
				if (!curStoredPoints) {
					curStoredPoints = [NSMutableArray array];
					[currentRecordingInfo setValue:curStoredPoints forKey:VSO_REC_LIST_STORED_POINTS_FOR_CLASS_KEY(c)];
				}
				if (recordState == VSORecordStateRecording) {
					[curStoredPoints addObject:currentLocation];
				} else {
					if ([curStoredPoints lastObject] != [NSNull null]) [curStoredPoints addObject:[NSNull null]];
				}
				if ([curStoredPoints count] > 2000) [self loadScrollViewWithPage:i];
			}
		}
	}
}

- (void)setCurrentRecordingInfosOfControllers
{
	for (VSOInfoGenericController *curCtrl in viewControllers)
		if ((NSNull *)curCtrl != [NSNull null])
			[curCtrl setCurrentRecordingInfo:currentRecordingInfo];
}

- (void)setCurrentGPXOfControllers
{
	for (VSOInfoGenericController *curCtrl in viewControllers)
		if ((NSNull *)curCtrl != [NSNull null])
			[curCtrl setCurrentGPX:currentGpx];
}

- (void)setCurrentHeadingOfControllers:(CLHeading *)h
{
	for (VSOInfoGenericController *curCtrl in viewControllers)
		if ((NSNull *)curCtrl != [NSNull null])
			[curCtrl setCurrentHeading:h];
}

- (void)setRecordState:(VSORecordState)s
{
	VSORecordState previousRecordState = recordState;
	recordState = s;
	[currentRecordingInfo setValue:[NSNumber numberWithUnsignedInt:recordState] forKey:VSO_REC_LIST_RECORD_STATE_KEY];
	
	/* Notifying view controllers that the record state changed */
	for (VSOInfoGenericController *curCtrl in viewControllers)
		if ((NSNull *)curCtrl != [NSNull null])
			[curCtrl recordingStateChangedFrom:previousRecordState to:recordState];
}

- (void)showBlankScreen:(NSTimer *)t
{
	[timerToTurnOffScreen invalidate]; [timerToTurnOffScreen release]; timerToTurnOffScreen = nil;
	
	if (viewBlankScreen.superview != nil || ![UIDevice currentDevice].proximityMonitoringEnabled) {
		/* The screen is blanked, or the proximity monitoring is disabled. We have nothing to do. */
		if (![UIDevice currentDevice].proximityMonitoringEnabled) NSDLog(@"Power saving mode disabled...");
		return;
	}
	
	NSDLog(@"Showing Blank Screen...");
	
	selPageBeforeShuttingScreenOff = selPage;
	
	selPage = 0;
	[self selectPage:0 animated:NO];
	[self unloadAllUnusedScrollViewPageController];
	
	[self.view addSubview:viewBlankScreen];
	[viewBlankScreen showMsg];
	[[UIApplication sharedApplication] setStatusBarHidden:YES];
}

- (void)resetIdleTimer:(NSNotification *)n
{
	NSDLog(@"Resetting idle timer...");
	NSTimeInterval ti = [[NSUserDefaults standardUserDefaults] doubleForKey:VSO_UDK_TURN_OFF_SCREEN_DELAY];
	NSDLog(@"Idle time is %g", ti);
	
	if (viewBlankScreen.superview != nil) {
		/* The screen is blanked */
		selPage = selPageBeforeShuttingScreenOff;
		[self selectPage:selPageBeforeShuttingScreenOff animated:NO];
	}
	if (ti == 0) return;
	
	[timerToTurnOffScreen invalidate]; [timerToTurnOffScreen release];
	timerToTurnOffScreen = [[NSTimer scheduledTimerWithTimeInterval:ti target:self selector:@selector(showBlankScreen:) userInfo:NULL repeats:NO] retain];
}

- (void)screenLockNotification:(NSNotification *)n
{
	NSDLog(@"Screen Locked");
	if (recordState == VSORecordStateRecording) {
		[self pauseRecording];
		[self setRecordState:VSORecordStateScreenLocked];
	}
}

- (void)screenUnlockNotification:(NSNotification *)n
{
	NSDLog(@"Screen Unlocked");
	if (recordState == VSORecordStateScreenLocked) {
		NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
		if ([ud boolForKey:VSO_UDK_FIRST_UNLOCK])
			[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"lock screen msg title", nil) message:NSLocalizedString(@"lock screen info", nil)
												delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"ok", nil), nil] show];
		[ud setBool:NO forKey:VSO_UDK_FIRST_UNLOCK];
		
		[self beginRecording];
	}
}

@end


#pragma mark -
@implementation MainViewController (DoThings)

- (void)addCurrentLocationToCurrentTrack
{
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	if (currentLocation == nil || ([ud boolForKey:VSO_UDK_SKIP_NON_ACCURATE_POINTS] && currentLocation.horizontalAccuracy > VSO_MAX_ACCURACY_TO_RECORD_POINT)) return;
	
	[currentTracksegment addTrackPointWithCoords:[currentLocation coordinate] hPrecision:currentLocation.horizontalAccuracy
												  elevation:currentLocation.altitude vPrecision:currentLocation.verticalAccuracy
													 heading:currentLocation.course date:[NSDate dateWithTimeIntervalSinceNow:0.]];
	[currentGpxOutput writeData:[[currentTracksegment lastTrackPoint] XMLOutput:3]];
	
	[currentRecordingInfo setValue:[NSNumber numberWithUnsignedInt:1+[[currentRecordingInfo valueForKey:VSO_REC_LIST_N_REG_POINTS_KEY] unsignedIntValue]]
									forKey:VSO_REC_LIST_N_REG_POINTS_KEY];
	[currentRecordingInfo setValue:[NSNumber numberWithDouble:MAX(currentLocation.speed, [[currentRecordingInfo valueForKey:VSO_REC_LIST_MAX_SPEED_KEY] doubleValue])]
									forKey:VSO_REC_LIST_MAX_SPEED_KEY];
	
	[self saveRecordingListStoppingGPX:NO];
}

- (void)showRecordsList
{
	[self stopRecording];
	[UIDevice currentDevice].proximityMonitoringEnabled = NO;
	
	VSORecordingsListViewCtlr *controller = [[VSORecordingsListViewCtlr alloc] initWithNibName:@"VSORecordingsListViewCtlr" bundle:nil recordingList:recordingList];
	UINavigationController *navCtrl = [[UINavigationController alloc] initWithRootViewController:controller];
	controller.delegate = self;
	
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
	controller.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
	[self presentModalViewController:navCtrl animated:YES];
	
	[navCtrl release];
	[controller release];
}

- (void)pauseRecording
{
	if (recordState == VSORecordStateStopped || recordState == VSORecordStatePaused) return;
	[[UIApplication sharedApplication] setIdleTimerDisabled:NO];
	
	NSTimeInterval totalRecordTime = [[currentRecordingInfo valueForKey:VSO_REC_LIST_TOTAL_REC_TIME_BEFORE_LAST_PAUSE_KEY] doubleValue];
	[currentRecordingInfo setValue:[NSNumber numberWithDouble:totalRecordTime+(-[dateRecordStart timeIntervalSinceNow])] forKey:VSO_REC_LIST_TOTAL_REC_TIME_BEFORE_LAST_PAUSE_KEY];
	
	[timerToRefreshTimes invalidate]; [timerToRefreshTimes release]; timerToRefreshTimes = nil;
	[dateRecordStart release]; dateRecordStart = nil;
	
	if (recordState != VSORecordStateWaitingGPS) [self setRecordState:VSORecordStatePaused];
	[currentGpxOutput writeData:[currentTracksegment XMLOutputForTagClosing:2]];
	[self saveRecordingListStoppingGPX:NO];
	
	[self updateUI];
}

- (void)stopRecording
{
	if (recordState == VSORecordStateStopped) return;
	
	[self pauseRecording];
	[currentGpxOutput writeData:[[currentGpx firstTrack] XMLOutputForTagClosing:1]];
	[currentGpxOutput writeData:[currentGpx XMLOutputForTagClosing:0]];
	
	[self setRecordState:VSORecordStateStopped];
	[self saveRecordingListStoppingGPX:YES];
	
	[currentGpx release]; currentGpx = nil;
	[currentRecordingInfo release]; currentRecordingInfo = nil;
	[currentGpxOutput closeFile]; [currentGpxOutput release]; currentGpxOutput = nil;
	
	[self setCurrentGPXOfControllers];
	[self setCurrentRecordingInfosOfControllers];
	
	[self updateUI];
}

@end

#pragma mark -
@implementation MainViewController

@synthesize selPage; /* Setter overwritten */

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
		currentGpx = nil;
		currentTracksegment = nil;
		[self setRecordState:VSORecordStateStopped];
		
		locationManager = [[CLLocationManager alloc] init];
		locationManager.delegate = self;
		
		ctrlClassesForPages = [[NSArray arrayWithObjects:[VSOInfoViewCtrl class], [VSODetailsViewCtrl class], [VSOMapViewController class], nil] retain];
	}
	return self;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
	NSDLog(@"View did load in MainViewController");
	[super viewDidLoad];
	
	[locationManager setDesiredAccuracy:kCLLocationAccuracyBest];
	[self setLocationServicesEnable:locationManager.locationServicesEnabled];
	
	/***************** Pages *****************/
	// view controllers are created lazily
	// in the meantime, load the array with placeholders which will be replaced on demand
	[viewControllers release]; [viewControllersStates release];
	viewControllers = [[NSMutableArray alloc] init];
	viewControllersStates = [[NSMutableArray alloc] init];
	for (NSInteger i = 0; i < [pageControl numberOfPages]; i++) {
		[viewControllers addObject:[NSNull null]];
		[viewControllersStates addObject:[NSNull null]];
	}
	
	pagesView.pagingEnabled = YES;
	pagesView.bounces = YES;
	pagesView.contentSize = CGSizeMake(pagesView.frame.size.width * [pageControl numberOfPages], pagesView.frame.size.height);
	pagesView.showsHorizontalScrollIndicator = NO;
	pagesView.showsVerticalScrollIndicator = NO;
	pagesView.scrollsToTop = NO;
	pagesView.delayScroll = NO;
	pagesView.delegate = self;
	
	selPage = [[NSUserDefaults standardUserDefaults] integerForKey:VSO_UDK_SELECTED_PAGE];
	[self selectPage:selPage animated:NO];
	
	/***************** Custom buttons *****************/
	[buttonRecord setAdjustsImageWhenDisabled:YES];
	
	/***************** Location Manager *****************/
#ifndef SIMULATOR_CODE
	[locationManager startUpdatingLocation];
	[locationManager startUpdatingHeading];
#else
	srandom(time(NULL));
	coordinate.latitude  = 43.603695;
	coordinate.longitude = 1.435905;
	[self refreshFalseLocation:nil];
	t = [[NSTimer scheduledTimerWithTimeInterval:.5 target:self selector:@selector(refreshFalseLocation:) userInfo:nil repeats:YES] retain];
#endif
	
	viewBlankScreen = [[VSOBlankView alloc] initWithFrame:self.view.bounds];
	
	[UIDevice currentDevice].proximityMonitoringEnabled = YES;
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(screenLockNotification:)   name:UIApplicationWillResignActiveNotification object:nil];
	[nc addObserver:self selector:@selector(screenUnlockNotification:) name:UIApplicationDidBecomeActiveNotification  object:nil];
	[nc addObserver:self selector:@selector(settingsChanged:) name:VSO_NTF_SETTINGS_CHANGED object:nil];
	[nc addObserver:self selector:@selector(resetIdleTimer:) name:VSO_NTF_VIEW_TOUCHED object:nil];
	
	[self updateUI];
	
	[self loadPreviousRecordingList];
	[self resetIdleTimer:nil];
}

- (void)settingsChanged:(NSNotification *)n
{
	[self resetIdleTimer:nil];
	[self refreshInfos];
}

- (void)beginRecording
{
	if (recordState == VSORecordStateRecording) return;
	[[UIApplication sharedApplication] setIdleTimerDisabled:YES];
	
	if (!currentGpx) {
		assert(currentGpxOutput == nil);
		assert(currentRecordingInfo == nil);
		
		/* Opening file handle to output xml on the fly */
		NSFileManager *fm = [NSFileManager defaultManager];
		
		NSUInteger i = 1;
		[currentGpxOutputPath release];
		while ([fm fileExistsAtPath:(currentGpxOutputPath = [VSO_BASE_PATH_TO_GPX stringByAppendingFormat:@"%d.gpx", i++])]);
		
		[currentGpxOutputPath retain];
		[[NSData data] writeToFile:currentGpxOutputPath atomically:NO];
		currentGpxOutput = [[NSFileHandle fileHandleForWritingAtPath:currentGpxOutputPath] retain];
		
		currentGpx = [[GPXgpxType alloc] initWithAttributes:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"gpx creator tag", nil), @"1.1", nil] forKeys:[NSArray arrayWithObjects:@"creator", @"version", nil]] elementName:@"gpx"];
		[currentGpx addTrack];
		
		currentRecordingInfo = [[NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:
																			relativePathFromFullForGPXFile(currentGpxOutputPath),
																			[NSNumber numberWithDouble:0.],
																			[NSNumber numberWithDouble:0.],
																			[NSNumber numberWithDouble:0.],
																			[NSNumber numberWithDouble:0.],
																			[NSNumber numberWithDouble:0.],
																			[NSNumber numberWithInt:0],
																			NSStringFromDate([NSDate dateWithTimeIntervalSinceNow:0]), nil]
																   forKeys:[NSArray arrayWithObjects:
																			VSO_REC_LIST_PATH_KEY,
																			VSO_REC_LIST_TOTAL_REC_TIME_KEY,
																			VSO_REC_LIST_TOTAL_REC_TIME_BEFORE_LAST_PAUSE_KEY,
																			VSO_REC_LIST_TOTAL_REC_DISTANCE_KEY,
																			VSO_REC_LIST_MAX_SPEED_KEY,
																			VSO_REC_LIST_AVERAGE_SPEED_KEY,
																			VSO_REC_LIST_N_REG_POINTS_KEY,
																			VSO_REC_LIST_NAME_KEY, nil]] retain];
		[currentGpxOutput writeData:[currentGpx XMLOutputForTagOpening:0]];
		[currentGpxOutput writeData:[[currentGpx firstTrack] XMLOutputForTagOpening:1]];
		
		[self setCurrentGPXOfControllers];
		[self setCurrentRecordingInfosOfControllers];
	}
	assert(dateRecordStart == nil);
	[[currentGpx firstTrack] addTrackSegment];
	currentTracksegment = [[currentGpx firstTrack] lastTrackSegment];
	[currentGpxOutput writeData:[currentTracksegment XMLOutputForTagOpening:2]];
	
	timerToRefreshTimes = [[NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(refreshTimes:) userInfo:nil repeats:YES] retain];
	[self setRecordState:VSORecordStateWaitingGPS];
	[self saveRecordingListStoppingGPX:NO];
	
	[self updateUI];
}

- (void)showDetailedInfosView
{
	selPage = VSO_PAGE_NUMBER_WITH_DETAILED_INFOS;
	pageControl.currentPage = selPage;
	[self selectPage:selPage animated:YES];
}

- (void)showMapView
{
	selPage = VSO_PAGE_NUMBER_WITH_MAP;
	pageControl.currentPage = selPage;
	[self selectPage:selPage animated:YES];
}

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	// Return YES for supported orientations
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)settingsViewControllerDidFinish:(VSOSettingsViewController *)controller
{
	[UIDevice currentDevice].proximityMonitoringEnabled = YES;
	[self dismissModalViewControllerAnimated:YES];
}

- (void)recordingsListViewControllerDidFinish:(VSORecordingsListViewCtlr *)controller
{
	[UIDevice currentDevice].proximityMonitoringEnabled = YES;
	[[UIApplication sharedApplication] setStatusBarStyle:VSO_APPLICATION_STATUS_BAR_STYLE animated:YES];
	[self dismissModalViewControllerAnimated:YES];
}


#pragma mark Page Control
/**************************** Page Control ****************************/
/* Does not affect the UI */
- (void)setSelPage:(int)p
{
	selPage = p;
	pagesView.delayScroll = (selPage == VSO_PAGE_NUMBER_WITH_MAP);
	
	[[NSUserDefaults standardUserDefaults] setInteger:selPage forKey:VSO_UDK_SELECTED_PAGE];
}

- (void)showMapSwipeWarning
{
	if (selPage != VSO_PAGE_NUMBER_WITH_MAP) return;
	if ([[NSUserDefaults standardUserDefaults] boolForKey:VSO_UDK_MAP_SWIPE_WARNING_SHOWN]) return;
	
	[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"swipe on map", nil) message:NSLocalizedString(@"how to come swipe when on map", nil)
										delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"ok", nil), nil] show];
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:VSO_UDK_MAP_SWIPE_WARNING_SHOWN];
}

- (IBAction)changePage:(id)sender
{
	self.selPage = pageControl.currentPage;
	
	[self selectPage:selPage animated:YES];
	[self showMapSwipeWarning];
}

- (void)scrollViewDidScroll:(UIScrollView *)sender
{
	if (timerToUnloadUnusedPages == nil) {
		[self loadScrollViewWithPage:selPage + 1];
		[self loadScrollViewWithPage:selPage - 1];
	}
	[timerToUnloadUnusedPages invalidate]; [timerToUnloadUnusedPages release];
	timerToUnloadUnusedPages = [[NSTimer scheduledTimerWithTimeInterval:VSO_TIME_BEFORE_RELEASE_OF_UNUSED_CTRLS target:self selector:@selector(fireUnloadAllUnusedScrollViewPageController:) userInfo:NULL repeats:NO] retain];
	
	// We don't want a "feedback loop" between the UIPageControl and the scroll delegate in
	// which a scroll event generated from the user hitting the page control triggers updates from
	// the delegate method. We use a boolean to disable the delegate logic when the page control is used.
	if (!sender.dragging && pageControlUsed) return;
	
	// Switch the indicator when more than 50% of the previous/next page is visible
	CGFloat pageWidth = pagesView.frame.size.width;
	self.selPage = floor((pagesView.contentOffset.x - pageWidth/2) / pageWidth) + 1;
	pageControl.currentPage = selPage;
	
	[self loadScrollViewWithPage:selPage];
}

- (void)fireUnloadAllUnusedScrollViewPageController:(NSTimer *)timer
{
	[timerToUnloadUnusedPages release];
	timerToUnloadUnusedPages = nil;
	
	[self unloadAllUnusedScrollViewPageController];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
	pageControlUsed = NO;
	[self refreshInfoButtonAnimated:YES];
	
	[self showMapSwipeWarning];
}

#pragma mark Location Management
/**************************** Location Management ****************************/
- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading
{
	if (signbit(newHeading.headingAccuracy)) return;
	
	[self setCurrentHeadingOfControllers:newHeading];
	[self refreshHeadingInfos];
}

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation
{
	BOOL pointAdded = NO;
	/* Negative accuracy means the location was not found */
	if (signbit(newLocation.horizontalAccuracy)) return;
	
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	[currentLocation release]; currentLocation = [newLocation retain];
	if (recordState != VSORecordStateRecording && recordState != VSORecordStateWaitingGPS) goto end;
	if ([ud boolForKey:VSO_UDK_SKIP_NON_ACCURATE_POINTS] && newLocation.horizontalAccuracy > VSO_MAX_ACCURACY_TO_RECORD_POINT) goto end;
	
	assert(dateRecordStart != nil || recordState != VSORecordStateRecording);
	if (dateRecordStart == nil && recordState != VSORecordStateRecording) {
		dateRecordStart = [[NSDate dateWithTimeIntervalSinceNow:0] retain];
		[self setRecordState:VSORecordStateRecording];
		[self updateUI];
	}
	
	NSUInteger minDist = [ud integerForKey:VSO_UDK_MIN_PATH_DISTANCE];
	NSTimeInterval minTimeInterval = [ud integerForKey:VSO_UDK_MIN_TIME_FOR_UPDATE];
	/* Adding new location only if distance from last saved location greater than some meters */
	GPXwptType *lastTrackPoint = [currentTracksegment lastTrackPoint];
	CLLocationDistance d = 0.;
	if (lastTrackPoint != nil) {
		CLLocation *lastPoint = [[[CLLocation alloc] initWithLatitude:lastTrackPoint.coords.latitude longitude:lastTrackPoint.coords.longitude] autorelease];
		d = [lastPoint getDistanceFrom:newLocation];
		if (d < minDist) goto end;
		if ([lastTrackPoint hasDate] && (-[[lastTrackPoint date] timeIntervalSinceNow] < minTimeInterval)) goto end;
	}
	
	CLLocationDistance totalRecordDistance = [[currentRecordingInfo valueForKey:VSO_REC_LIST_TOTAL_REC_DISTANCE_KEY] doubleValue];
	[currentRecordingInfo setValue:[NSNumber numberWithDouble:totalRecordDistance+d] forKey:VSO_REC_LIST_TOTAL_REC_DISTANCE_KEY];
	[self addCurrentLocationToCurrentTrack];
	pointAdded = YES;
	
end:
	[self setCurrentLocationOfControllers:(recordState == VSORecordStateRecording && pointAdded)];
	[self refreshInfos];
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error
{
	if ([error domain] == kCLErrorDomain) {
		// We handle CoreLocation-related errors here
		switch ([error code]) {
			case kCLErrorDenied:
				[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"cannot get location", nil) message:NSLocalizedString(@"record cancelled: cant get location", nil)
													delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"ok", nil), nil] show];
				[self setLocationServicesEnable:NO];
				break;
			case kCLErrorLocationUnknown: break;
			case kCLErrorNetwork: break;
			case kCLErrorHeadingFailure: break;
			default:
				/* We shouldn't arrive here... */;
		}
	} else {
		NSDLog(@"Cannot get User Location, domain error is not kCLErrorDomain");
		NSDLog(@"\tError domain: \"%@\"  Error code: %d", [error domain], [error code]);
		NSDLog(@"\tDescription: \"%@\"", [error localizedDescription]);
	}
	
	[self stopRecording];
}


#pragma mark User Interface Actions
/**************************** UI Actions ****************************/
- (IBAction)showInfo
{
	[UIDevice currentDevice].proximityMonitoringEnabled = NO;
	
	VSOSettingsViewController *controller = [[VSOSettingsViewController alloc] initWithNibName:@"VSOSettingsView" bundle:nil];
	controller.delegate = self;
	
	controller.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
	[self presentModalViewController:controller animated:YES];
	
	[controller release];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if (buttonIndex != [alertView cancelButtonIndex]) {
		if (alertIsForStop) [self stopRecording];
		else                [self pauseRecording];
	}
}

- (IBAction)recordPauseButtonAction:(id)sender
{
	if (recordState != VSORecordStateRecording) [self beginRecording];
	else {
		alertIsForStop = NO;
		[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"record in progress", nil) message:NSLocalizedString(@"really pause?", nil)
											delegate:self cancelButtonTitle:NSLocalizedString(@"no", nil) otherButtonTitles:NSLocalizedString(@"yes", nil), nil] show];
	}
}

- (IBAction)showRecordsListStopRecordButtonAction:(id)sender
{
	if (recordState != VSORecordStateStopped) {
		alertIsForStop = YES;
		[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"record in progress", nil) message:NSLocalizedString(@"really stop?", nil)
											delegate:self cancelButtonTitle:NSLocalizedString(@"no", nil) otherButtonTitles:NSLocalizedString(@"yes", nil), nil] show];
	} else {
		[self showRecordsList];
	}
}

#pragma mark Other
/**************************** Other ****************************/
- (void)setLocationServicesEnable:(BOOL)enabled
{
	buttonRecord.enabled = enabled;
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	NSDLog(@"Memory warning in Main View Controller.");
	
	[self unloadAllUnusedScrollViewPageController];
}

- (void)viewDidUnload
{
	[super viewDidUnload];
}

- (void)saveRecordingListStoppingGPX:(BOOL)saveGPX
{
	[self saveCurrentGpx];
	
	if (saveGPX && recordState != VSORecordStateStopped) {
		if (![[NSUserDefaults standardUserDefaults] boolForKey:VSO_UDK_PAUSE_ON_QUIT]) [self stopRecording];
		else {
			[self pauseRecording];
			[self saveCurrentGpx];
			/* Saving state of controllers */
			NSUInteger i = 0;
			for (VSOInfoGenericController *curCtrl in viewControllers) {
				if ((NSNull *)curCtrl != [NSNull null]) [viewControllersStates replaceObjectAtIndex:i withObject:[curCtrl state]];
				i++;
			}
			[NSKeyedArchiver archiveRootObject:viewControllersStates toFile:VSO_PATH_TO_PAUSED_REC_WITNESS];
		}
	}
	[NSKeyedArchiver archiveRootObject:recordingList toFile:VSO_PATH_TO_GPX_LIST];
}

- (void)recoverFromCrash
{
	NSDLog(@"Recovering GPS Stone from crash");
	if ([recordingList count] == 0) return;
	
	NSDictionary *recInfos = [recordingList objectAtIndex:0];
	if ([recInfos valueForKey:VSO_REC_LIST_RECORD_STATE_KEY] != nil) {
		NSDLog(@"App crashed while recording. Recovering last state...");
		[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"app crashed", nil) message:NSLocalizedString(@"recovering last recording", nil)
											delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"ok", nil), nil] show];
		[NSKeyedArchiver archiveRootObject:viewControllersStates toFile:VSO_PATH_TO_PAUSED_REC_WITNESS];
		[self loadPreviousRecordingList];
	}
}

- (void)dealloc
{
	[locationManager stopUpdatingLocation];
	[locationManager stopUpdatingHeading];
	[locationManager release];
	[currentLocation release];
#ifdef SIMULATOR_CODE
	[t invalidate];
	[t release];
	t = nil;
#endif
	
	[currentRecordingInfo release];
	[dateRecordStart release];
	[recordingList release];
	
	[ctrlClassesForPages release];
	[viewControllers release];
	[viewControllersStates release];
	
	[pagesView release];
	[pageControl release];
	
	[buttonRecord release];
	[buttonInfoDark release];
	[buttonInfoLight release];
	[buttonListOfRecordings release];
	
	[viewMiniInfos release];
	[labelMiniInfosDistance release];
	[labelMiniInfosRecordTime release];
	[labelMiniInfosRecordingState release];
	
	[currentGpx release];
	[currentTracksegment release];
	
	[viewBlankScreen release];
	
	[timerToUnloadUnusedPages invalidate]; [timerToUnloadUnusedPages release];
	[timerToTurnOffScreen invalidate]; [timerToTurnOffScreen release];
	[timerToRefreshTimes invalidate]; [timerToRefreshTimes release];
	
	[super dealloc];
}

@end
