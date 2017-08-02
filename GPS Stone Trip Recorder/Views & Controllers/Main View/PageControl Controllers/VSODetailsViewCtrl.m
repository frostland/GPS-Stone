/*
 * VSODetailsViewCtrl.m
 * GPS Stone Trip Recorder
 *
 * Created by François on 7/11/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import "VSODetailsViewCtrl.h"

#import "VSOUtils.h"
#import "Constants.h"



@implementation VSODetailsViewCtrl

- (void)refreshInfos
{
	[labelLat setText:NSLocalizedString(@"getting loc", nil)];
	[labelLong setText:@""];
	[labelSpeed setText:@"0"];
	[labelAltitude setText:NSLocalizedString(@"nd", nil)];
	[labelVerticalAccuracy setText:@""];
	[labelHorizontalAccuracy setText:NSLocalizedString(@"nd", nil)];
	
	[labelTrackName setText:NSLocalizedString(@"nd", nil)];
	[labelMaxSpeed setText:NSLocalizedString(@"nd", nil)];
	[labelAverageSpeed setText:NSLocalizedString(@"nd", nil)];
	[labelElapsedTime setText:@"00:00:00"];
	[labelTotalDistance setText:NSLocalizedString(@"nd", nil)];
	[labelNumberOfPoints setText:NSLocalizedString(@"nd", nil)];
	
	if (!currentLocation) return;
	[labelLat  setText:NSStringFromDegrees(currentLocation.coordinate.latitude, YES)];
	[labelLong setText:NSStringFromDegrees(currentLocation.coordinate.longitude, NO)];
	[labelHorizontalAccuracy setText:NSStringFromDistance(currentLocation.horizontalAccuracy)];
	if (currentLocation.horizontalAccuracy > VSO_MAX_ACCURACY_TO_RECORD_POINT) [labelHorizontalAccuracy setTextColor:[UIColor redColor]];
	else                                                                       [labelHorizontalAccuracy setTextColor:[UIColor blackColor]];
	if (currentLocation.verticalAccuracy >= 0) {
		[labelAltitude setText:[NSString stringWithFormat:@"%@", NSStringFromAltitude(currentLocation.altitude)]];
		[labelVerticalAccuracy setText:currentLocation.altitude == 0? @"": [NSString stringWithFormat:NSLocalizedString(@"plus minus n percent format", nil), (NSUInteger)((currentLocation.verticalAccuracy/ABS(currentLocation.altitude))*100.)]];
	}
	if (currentLocation.speed >= 0) [labelSpeed setText:NSStringFromSpeed(currentLocation.speed, NO)];
	
	[self refreshHeadingInfos];
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:VSO_ANIM_TIME];
	if (!currentGPX) [viewWithTrackInfos setAlpha:0.];
	else             [viewWithTrackInfos setAlpha:1.];
	[UIView commitAnimations];
	
	if (!currentGPX) return;
	
	[labelTrackName setText:[currentRecordingInfo valueForKey:VSO_REC_LIST_NAME_KEY]];
	
	[labelNumberOfPoints setText:[NSString stringWithFormat:@"%d", [[currentRecordingInfo valueForKey:VSO_REC_LIST_N_REG_POINTS_KEY] unsignedIntValue]]];
	[labelElapsedTime setText:NSStringFromTimeInterval([[currentRecordingInfo valueForKey:VSO_REC_LIST_TOTAL_REC_TIME_KEY] doubleValue])];
	[labelTotalDistance setText:NSStringFromDistance([[currentRecordingInfo valueForKey:VSO_REC_LIST_TOTAL_REC_DISTANCE_KEY] doubleValue])];
	CLLocationSpeed currentAverageSpeed = [[currentRecordingInfo valueForKey:VSO_REC_LIST_AVERAGE_SPEED_KEY] doubleValue];
	if (currentAverageSpeed >= 0) [labelAverageSpeed setText:NSStringFromSpeed(currentAverageSpeed, NO)];
	
	CLLocationSpeed currentMaxSpeed = [[currentRecordingInfo valueForKey:VSO_REC_LIST_MAX_SPEED_KEY] doubleValue];
	if (currentMaxSpeed >= 0) [labelMaxSpeed setText:NSStringFromSpeed(currentMaxSpeed, NO)];
}

- (void)refreshHeadingInfos
{
	CLLocationDirection h = -1.;
	if (currentLocation != nil) h = currentLocation.course;
	if (currentHeading  != nil) h = currentHeading.trueHeading;
	if (h >= 0) {
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:VSO_ANIM_TIME];
		[imageNorth setAlpha:1.];
		[imageNorth setTransform:CGAffineTransformMakeRotation(-2.*M_PI*(h/360))];
		[UIView commitAnimations];
	}
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

- (IBAction)startRecord:(id)sender
{
	[self.delegate beginRecording];
}

- (void)settingsChanged:(NSNotification *)n
{
	if (distanceUnit() == VSODistanceUnitMiles) [labelKmph setText:NSLocalizedString(@"mph", nil)];
	else                                        [labelKmph setText:NSLocalizedString(@"km/h", nil)];
	
	[self refreshInfos];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged:) name:VSO_NTF_SETTINGS_CHANGED object:nil];
	
	[imageNorth setAlpha:0.];
	if (!currentGPX) [viewWithTrackInfos setAlpha:0.];
	else             [viewWithTrackInfos setAlpha:1.];
	if ([[currentRecordingInfo valueForKey:VSO_REC_LIST_RECORD_STATE_KEY] unsignedIntValue] == VSORecordStateStopped) [buttonRecord setAlpha:1.];
	else                                                                                                              [buttonRecord setAlpha:0.];
	
	[self settingsChanged:nil];
}

@end
