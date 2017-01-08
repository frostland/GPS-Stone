/*
 * VSOInfoGenericController.m
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 8/6/09.
 * Copyright 2009 __MyCompanyName__. All rights reserved.
 */

#import "VSOInfoGenericController.h"



@implementation VSOInfoGenericController

@synthesize currentGPX, currentLocation, currentHeading, currentRecordingInfo, delegate;

+ (BOOL)needsAllPoints
{
	return NO;
}

+ (instancetype)instantiateWithGPX:(GPXgpxType *)gpx location:(CLLocation *)l
{
	UIStoryboard *s = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
	VSOInfoGenericController *ret = [s instantiateViewControllerWithIdentifier:NSStringFromClass(self)];
	ret.currentGPX = gpx;
	ret.currentLocation = l;
	return ret;
}

- (void)setCurrentLocation:(CLLocation *)nl pointWasRecorded:(BOOL)pointWasRecorded
{
	[self setCurrentLocation:nl];
}

- (void)refreshInfos
{
	/* Subclalsses do the stuff */
}

- (void)refreshHeadingInfos
{
	/* Subclalsses do the stuff */
}

- (void)recordingStateChangedFrom:(VSORecordState)lastState to:(VSORecordState)newState
{
	/* Subclalsses do the stuff */
}

- (NSData *)state
{
	/* Subclasses will save here what is needed for them to restore their current state */
	return [NSData data];
}

- (void)restoreStateFrom:(NSData *)dta
{
	/* Subclasses do it */
}

@end
