//
//  VSOInfoViewCtrl.m
//  GPS Stone Trip Recorder
//
//  Created by François on 7/11/09.
//  Copyright 2009 VSO-Software. All rights reserved.
//

#import "VSOInfoViewCtrl.h"

@implementation VSOInfoViewCtrl

- (void)refreshInfos
{
	/* Nothing to do */
}

- (void)recordingStateChangedFrom:(VSORecordState)lastState to:(VSORecordState)newState
{
	[self refreshInfos];
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:VSO_ANIM_TIME];
	if (newState == VSORecordStateStopped) [buttonRecord setAlpha:1.];
	else                                   [buttonRecord setAlpha:0.];
	[UIView commitAnimations];
}

- (IBAction)showDetailedInfos
{
	[self.delegate showDetailedInfosView];
}

- (IBAction)showPositionOnMap
{
	[self.delegate showMapView];
}

- (IBAction)recordPosition
{
	[self.delegate showDetailedInfosView];
	[self.delegate beginRecording];
}

- (void)viewDidLoad
{
	if ([[currentRecordingInfo valueForKey:VSO_REC_LIST_RECORD_STATE_KEY] unsignedIntValue] == VSORecordStateStopped) [buttonRecord setAlpha:1.];
	else                                                                                                              [buttonRecord setAlpha:0.];
}

- (void)dealloc
{
	[super dealloc];
}

@end
