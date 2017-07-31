/*
 * VSOSettingsViewController.m
 * GPS Stone Trip Recorder
 *
 * Created by François on 7/10/09.
 * Copyright VSO-Software 2009. All rights reserved.
 */

#import <MapKit/MKTypes.h>

#import "VSOSettingsViewController.h"
#import "Constants.h"



@implementation VSOSettingsViewController

@synthesize delegate;

- (void)viewDidLoad
{
	[super viewDidLoad];
	[scrollView addSubview:viewWithSettings];
	scrollView.contentSize = viewWithSettings.frame.size;
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[nc addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
	
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	
	[textFieldMinDist setText:[NSString stringWithFormat:@"%ld", (long)[ud integerForKey:VSO_UDK_MIN_PATH_DISTANCE]]];
	[textFieldMinTime setText:[NSString stringWithFormat:@"%ld", (long)[ud integerForKey:VSO_UDK_MIN_TIME_FOR_UPDATE]]];
	[switchSkip setOn:[ud boolForKey:VSO_UDK_SKIP_NON_ACCURATE_POINTS]];
	[switchMetricMeasures setOn:([ud integerForKey:VSO_UDK_DISTANCE_UNIT] == VSODistanceUnitKilometers)];
	
	switch ([ud integerForKey:VSO_UDK_MAP_TYPE]) {
		case MKMapTypeStandard:  [segmentedCtrlMapType setSelectedSegmentIndex:0]; break;
		case MKMapTypeSatellite: [segmentedCtrlMapType setSelectedSegmentIndex:1]; break;
		case MKMapTypeHybrid:    [segmentedCtrlMapType setSelectedSegmentIndex:2]; break;
		default:
			/* Unknown map type!!! */
			[[NSException exceptionWithName:@"Unknown map type in viewDidLoad of FlipsideViewController"
											 reason:@"Not FLMapTypeStandard, MKMapTypeSatellite or MKMapTypeHybrid; corresponding to no known map type!" userInfo:nil] raise];
			break;
	}
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
}

- (void)keyboardWillShow:(NSNotification *)n
{
	CGFloat h = [[n.userInfo valueForKey:UIKeyboardBoundsUserInfoKey] CGRectValue].size.height;
	CGRect f = scrollView.frame;
	f.size.height -= h;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:VSO_ANIM_TIME];
	scrollView.frame = f;
	[UIView commitAnimations];
}

- (void)keyboardWillHide:(NSNotification *)n
{
	CGFloat h = [[n.userInfo valueForKey:UIKeyboardBoundsUserInfoKey] CGRectValue].size.height;
	CGRect f = scrollView.frame;
	f.size.height += h;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:VSO_ANIM_TIME];
	scrollView.frame = f;
	[UIView commitAnimations];
}

- (IBAction)done
{
	[self.delegate settingsViewControllerDidFinish:self];	
}

- (IBAction)mapTypeChanged:(id)sender
{
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	
	switch ([segmentedCtrlMapType selectedSegmentIndex]) {
		case 0: [ud setInteger:MKMapTypeStandard  forKey:VSO_UDK_MAP_TYPE]; break;
		case 1: [ud setInteger:MKMapTypeSatellite forKey:VSO_UDK_MAP_TYPE]; break;
		case 2: [ud setInteger:MKMapTypeHybrid    forKey:VSO_UDK_MAP_TYPE]; break;
		default:
			/* Unknown segment!!! */
			[[NSException exceptionWithName:@"Wrong segment in mapTypeChanged:"
											 reason:@"Not 0, 1 or 2; corresponding to no known map type!" userInfo:nil] raise];
			break;
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:VSO_NTF_SETTINGS_CHANGED object:nil userInfo:nil];
}

- (IBAction)minDistChanged:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setInteger:[[sender text] integerValue] forKey:VSO_UDK_MIN_PATH_DISTANCE];
	[[NSNotificationCenter defaultCenter] postNotificationName:VSO_NTF_SETTINGS_CHANGED object:nil userInfo:nil];
}

- (IBAction)minTimeChanged:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setInteger:[[sender text] doubleValue] forKey:VSO_UDK_MIN_TIME_FOR_UPDATE];
	[[NSNotificationCenter defaultCenter] postNotificationName:VSO_NTF_SETTINGS_CHANGED object:nil userInfo:nil];
}

- (IBAction)skipNonAccuratePointsValueChanged:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setBool:[sender isOn] forKey:VSO_UDK_SKIP_NON_ACCURATE_POINTS];
}

- (IBAction)metricMeasuresValueChanged:(id)sender
{
	if ([sender isOn]) [[NSUserDefaults standardUserDefaults] setInteger:VSODistanceUnitKilometers forKey:VSO_UDK_DISTANCE_UNIT];
	else               [[NSUserDefaults standardUserDefaults] setInteger:VSODistanceUnitMiles      forKey:VSO_UDK_DISTANCE_UNIT];
	[[NSNotificationCenter defaultCenter] postNotificationName:VSO_NTF_SETTINGS_CHANGED object:nil userInfo:nil];
}

@end
