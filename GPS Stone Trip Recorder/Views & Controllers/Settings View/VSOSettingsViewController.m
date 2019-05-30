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
	
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	
	[textFieldMinDist setText:[NSString stringWithFormat:@"%ld", (long)[ud integerForKey:VSO_UDK_MIN_PATH_DISTANCE]]];
	[textFieldMinTime setText:[NSString stringWithFormat:@"%ld", (long)[ud integerForKey:VSO_UDK_MIN_TIME_FOR_UPDATE]]];
	
	switch ([ud integerForKey:VSO_UDK_MAP_TYPE]) {
		case MKMapTypeSatellite: [segmentedCtrlMapType setSelectedSegmentIndex:1]; break;
		case MKMapTypeHybrid:    [segmentedCtrlMapType setSelectedSegmentIndex:2]; break;
		case MKMapTypeStandard: /* No Break */
		default:
			/* We use the standard map type when map type is unknown. */
			[segmentedCtrlMapType setSelectedSegmentIndex:0];
	}
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
}

- (IBAction)done
{
	[self.delegate settingsViewControllerDidFinish:self];	
}

- (IBAction)mapTypeChanged:(id)sender
{
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	
	switch ([segmentedCtrlMapType selectedSegmentIndex]) {
		case 1: [ud setInteger:MKMapTypeSatellite forKey:VSO_UDK_MAP_TYPE]; break;
		case 2: [ud setInteger:MKMapTypeHybrid    forKey:VSO_UDK_MAP_TYPE]; break;
		case 0: /* No Break */
		default:
			/* Let's set the map type to standard for unknown segment. */
			[ud setInteger:MKMapTypeStandard  forKey:VSO_UDK_MAP_TYPE];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:c.ntfSettingsChanged object:nil userInfo:nil];
}

- (IBAction)minDistChanged:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setInteger:[[sender text] integerValue] forKey:VSO_UDK_MIN_PATH_DISTANCE];
	[[NSNotificationCenter defaultCenter] postNotificationName:c.ntfSettingsChanged object:nil userInfo:nil];
}

- (IBAction)minTimeChanged:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setInteger:[[sender text] doubleValue] forKey:VSO_UDK_MIN_TIME_FOR_UPDATE];
	[[NSNotificationCenter defaultCenter] postNotificationName:c.ntfSettingsChanged object:nil userInfo:nil];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
	switch (indexPath.section) {
		case 1:
			if (indexPath.row == 2) {
				[cell setAccessoryType:([ud boolForKey:VSO_UDK_SKIP_NON_ACCURATE_POINTS]? UITableViewCellAccessoryCheckmark: UITableViewCellAccessoryNone)];
			}
			break;
			
		case 2: {
			NSInteger unit = [ud integerForKey:VSO_UDK_DISTANCE_UNIT];
			switch (indexPath.row) {
				case 0: [cell setAccessoryType:(unit == VSODistanceUnitAutomatic?  UITableViewCellAccessoryCheckmark: UITableViewCellAccessoryNone)]; break;
				case 1: [cell setAccessoryType:(unit == VSODistanceUnitKilometers? UITableViewCellAccessoryCheckmark: UITableViewCellAccessoryNone)]; break;
				case 2: [cell setAccessoryType:(unit == VSODistanceUnitMiles?      UITableViewCellAccessoryCheckmark: UITableViewCellAccessoryNone)]; break;
			}
			break;
		}
			
		default: /* nop */;
	}
	return cell;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
	return [indexPath isEqual:[NSIndexPath indexPathForRow:2 inSection:1]] || indexPath.section == 2;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
	switch (indexPath.section) {
		case 1:
			if (indexPath.row == 2) {
				BOOL skip = ![ud boolForKey:VSO_UDK_SKIP_NON_ACCURATE_POINTS];
				[ud setBool:skip forKey:VSO_UDK_SKIP_NON_ACCURATE_POINTS];
				[[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:(skip? UITableViewCellAccessoryCheckmark: UITableViewCellAccessoryNone)];
				[[NSNotificationCenter defaultCenter] postNotificationName:c.ntfSettingsChanged object:nil userInfo:nil];
			}
			break;
			
		case 2: {
			NSInteger newUnit = VSODistanceUnitAutomatic;
			switch (indexPath.row) {
				case 0: newUnit = VSODistanceUnitAutomatic;  break;
				case 1: newUnit = VSODistanceUnitKilometers; break;
				case 2: newUnit = VSODistanceUnitMiles;      break;
			}
			[ud setInteger:newUnit forKey:VSO_UDK_DISTANCE_UNIT];
			[[tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:2]] setAccessoryType:(newUnit == VSODistanceUnitAutomatic?  UITableViewCellAccessoryCheckmark: UITableViewCellAccessoryNone)];
			[[tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:2]] setAccessoryType:(newUnit == VSODistanceUnitKilometers? UITableViewCellAccessoryCheckmark: UITableViewCellAccessoryNone)];
			[[tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:2]] setAccessoryType:(newUnit == VSODistanceUnitMiles?      UITableViewCellAccessoryCheckmark: UITableViewCellAccessoryNone)];
			[[NSNotificationCenter defaultCenter] postNotificationName:c.ntfSettingsChanged object:nil userInfo:nil];
			break;
		}
			
		default: /* nop */;
	}
}

@end
