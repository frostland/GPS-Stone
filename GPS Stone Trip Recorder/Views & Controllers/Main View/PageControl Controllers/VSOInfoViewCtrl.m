/*
 * VSOInfoViewCtrl.m
 * GPS Stone Trip Recorder
 *
 * Created by François on 7/11/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import "VSOInfoViewCtrl.h"



@implementation VSOInfoViewCtrl

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	if (!isDeviceScreenTallerThanOriginalIPhone()) {self.constraintMarginTopTitle.constant = 25.;}
	
	if ([[currentRecordingInfo valueForKey:VSO_REC_LIST_RECORD_STATE_KEY] unsignedIntValue] == VSORecordStateStopped) [self.buttonRecord setAlpha:1.];
	else                                                                                                              [self.buttonRecord setAlpha:0.];
}

/* ***************
   MARK: - Actions
   *************** */

- (void)openPreferences:(id)sender
{
	[self.delegate openPreferences];
}

- (IBAction)showDetailedInfos:(id)sender
{
	[self.delegate showDetailedInfosView];
}

- (IBAction)showPositionOnMap:(id)sender
{
	[self.delegate showMapView];
}

- (IBAction)startRecording:(id)sender
{
	[self.delegate showDetailedInfosView];
	[self.delegate beginRecording];
}

/* *************************************
   MARK: - Abstract Class Implementation
   ************************************* */

- (void)refreshInfos
{
	/* Nothing to do */
}

- (void)recordingStateChangedFrom:(VSORecordState)lastState to:(VSORecordState)newState
{
	[self refreshInfos];
	[UIView animateWithDuration:VSO_ANIM_TIME animations:^{
		[self.buttonRecord setAlpha:(newState == VSORecordStateStopped ? 1. : 0.)];
	}];
}

@end
