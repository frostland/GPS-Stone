/*
 * VSORecordingsListViewCtlr.m
 * GPS Stone Trip Recorder
 *
 * Created by François on 7/13/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import "VSORecordingsListViewCtlr.h"

#import "MainViewController.h"
#import "Constants.h"
#import "VSOUtils.h"



@implementation VSORecordingsListViewCtlr

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)updateTabBarButtons:(BOOL)tableViewEditing
{
}

- (IBAction)done:(id)sender
{
	if (!self.tableView.editing) [self.delegate recordingsListViewControllerDidFinish:self];
	else {
		[self.tableView setEditing:NO animated:YES];
		[self updateTabBarButtons:self.tableView.editing];
	}
}

- (void)nameChanged
{
	[self.tableView reloadData];
	MainViewController *root = (MainViewController *)UIApplication.sharedApplication.keyWindow.rootViewController;
	if ([root isKindOfClass:MainViewController.class]) {
		[root saveRecordingListStoppingGPX:NO];
	}
}

- (void)recordingsDetailViewControllerDidFinish:(VSORecordingDetailViewCtrl *)controller
{
	[self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	if ([segue.identifier isEqualToString:@"ShowDetails"]) {
		VSORecordingDetailViewCtrl *controller = segue.destinationViewController;
		
		NSMutableDictionary *rec = [[_recordingList objectAtIndex:[self.tableView.indexPathForSelectedRow indexAtPosition:1]] mutableCopy];
		[_recordingList replaceObjectAtIndex:[self.tableView.indexPathForSelectedRow indexAtPosition:1] withObject:rec];
		controller.recordingInfos = rec;
		
		controller.delegate = self;
	}
}

/* Settings table view dataSource and delegate */
#pragma mark Data source / Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [_recordingList count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *CellIdentifier = @"Cell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
	
	NSDictionary *curRecDescr = [_recordingList objectAtIndex:[indexPath indexAtPosition:1]];
	cell.textLabel.text = [curRecDescr valueForKey:c.recListNameKey];
	
	NSString *distanceStr = NSStringFromDistance([[curRecDescr valueForKey:c.recListTotalRecDistanceKey] doubleValue]);
	NSString *recTimeStr = NSStringFromTimeInterval([[curRecDescr valueForKey:c.recListTotalRecTimeKey] doubleValue]);
	cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ / %@", recTimeStr, distanceStr];
	
	return cell;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		NSUInteger i = [indexPath indexAtPosition:1];
		
		NSFileManager *fm = [NSFileManager defaultManager];
		if (![fm removeItemAtPath:fullPathFromRelativeForGPXFile([[_recordingList objectAtIndex:i] valueForKey:c.recListPathKey]) error:NULL]) {
			[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"internal error", nil) message:[NSString stringWithFormat:NSLocalizedString(@"cannot delete recording. please contact developer error code #", nil), 2] delegate:self cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"ok", nil), nil] show];
			NSLog(@"Can't delete relative path \"%@\" (full path is: \"%@\")", [[_recordingList objectAtIndex:i] valueForKey:c.recListPathKey], fullPathFromRelativeForGPXFile([[_recordingList objectAtIndex:i] valueForKey:c.recListPathKey]));
			return;
		}
		[_recordingList removeObjectAtIndex:i];
		
		[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
	}   
}

- (void)tableView:(UITableView*)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self updateTabBarButtons:YES];
}

- (void)tableView:(UITableView*)tableView didEndEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self updateTabBarButtons:NO];
}

- (void)didReceiveMemoryWarning
{
	// Releases the view if it doesn't have a superview.
	[super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)dealloc
{
	NSDLog(@"Releasing a VSORecordingListViewCtrl");
}

@end
