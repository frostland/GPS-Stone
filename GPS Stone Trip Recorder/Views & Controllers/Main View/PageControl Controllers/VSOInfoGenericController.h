/*
 * VSOInfoGenericController.h
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 8/6/09.
 * Copyright 2009 __MyCompanyName__. All rights reserved.
 */

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

#import "Constants.h"
#import "GPXgpxType.h"



@protocol VSOInfoGenericControllerDelegate

- (void)beginRecording;
- (void)showDetailedInfosView;
- (void)showMapView;

@end


@interface VSOInfoGenericController : UIViewController {
	GPXgpxType *currentGPX;
	CLHeading *currentHeading;
	CLLocation *currentLocation;
	NSDictionary *currentRecordingInfo;
}

@property(nonatomic, retain) GPXgpxType *currentGPX;
@property(nonatomic, retain) NSDictionary *currentRecordingInfo; /* Won't refresh UI when changed */
@property(nonatomic, retain) CLHeading *currentHeading; /* Won't refresh UI when changed */
@property(nonatomic, retain) CLLocation *currentLocation; /* Won't refresh UI when changed */
@property(nonatomic, weak) id <VSOInfoGenericControllerDelegate> delegate;

/* Explanation of the property below:
 * Subclasses of VSOInfoGenericController are instanciated and dealloced on the fly, at the demand of the front end user.
 * Some sublasses needs to have all the points (for instance to draw the path) while other may only need infos which are in currentRecordingInfo.
 * Points are given on the fly with setCurrentLocation:. If an instance is dealloced, it cannot get points on the fly.
 * The property below informs the controllers of the subclasses to store points which cannot be given in the currentRecordingInfo, with key VSO_REC_LIST_STORED_POINTS_FOR_CLASS_KEY(class).
 * It is up to the subclass to use and clear the stored points. */
+ (BOOL)needsAllPoints;

+ (instancetype)instantiateWithGPX:(GPXgpxType *)gpx location:(CLLocation *)l;

- (void)setCurrentLocation:(CLLocation *)nl pointWasRecorded:(BOOL)pointWasRecorded;

- (NSData *)state;
- (void)restoreStateFrom:(NSData *)dta;

/* Call this method when there is a change in the GPX to refresh the UI */
- (void)refreshInfos;
- (void)refreshHeadingInfos; /* The heading changes very often on an iPhone 3GS. We don't want to refresh everything because the heading changed! */
- (void)recordingStateChangedFrom:(VSORecordState)lastState to:(VSORecordState)newState;

@end
