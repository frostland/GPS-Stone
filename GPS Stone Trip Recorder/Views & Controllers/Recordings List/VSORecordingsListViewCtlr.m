/*
 * VSORecordingsListViewCtlr.m
 * GPS Stone Trip Recorder
 *
 * Created by François on 7/13/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import "VSORecordingsListViewCtlr.h"

#import "Constants.h"
#import "VSOUtils.h"



@implementation VSORecordingsListViewCtlr

- (id)initWithCoder:(NSCoder *)aDecoder
{
	if (self = [super initWithCoder:aDecoder]) {
		self.title = NSLocalizedString(@"recordings", nil);
	}
	return self;
}


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
	[super viewDidLoad];
	
	self.navigationItem.rightBarButtonItem = self.editButtonItem;
}


/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	// Return YES for supported orientations
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)updateTabBarButtons:(BOOL)tableViewEditing
{
}

- (IBAction)done:(id)sender
{
	if (!tableViewRecordings.editing) [self.delegate recordingsListViewControllerDidFinish:self];
	else {
		[tableViewRecordings setEditing:NO animated:YES];
		[self updateTabBarButtons:tableViewRecordings.editing];
	}
}


- (void)nameChanged
{
	[tableViewRecordings reloadData];
}

- (void)recordingsDetailViewControllerDidFinish:(VSORecordingDetailViewCtrl *)controller
{
	[self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	if ([segue.identifier isEqualToString:@"ShowDetails"]) {
		VSORecordingDetailViewCtrl *controller = segue.destinationViewController;
		
		NSMutableDictionary *rec = [[_recordingList objectAtIndex:[tableViewRecordings.indexPathForSelectedRow indexAtPosition:1]] mutableCopy];
		[_recordingList replaceObjectAtIndex:[tableViewRecordings.indexPathForSelectedRow indexAtPosition:1] withObject:rec];
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
	cell.textLabel.text = [curRecDescr valueForKey:VSO_REC_LIST_NAME_KEY];
	
	NSString *distanceStr = NSStringFromDistance([[curRecDescr valueForKey:VSO_REC_LIST_TOTAL_REC_DISTANCE_KEY] doubleValue]);
	NSString *recTimeStr = NSStringFromTimeInterval([[curRecDescr valueForKey:VSO_REC_LIST_TOTAL_REC_TIME_KEY] doubleValue]);
	cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ / %@", recTimeStr, distanceStr];
	
	return cell;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		NSUInteger i = [indexPath indexAtPosition:1];
		
		NSFileManager *fm = [NSFileManager defaultManager];
		if (![fm removeItemAtPath:fullPathFromRelativeForGPXFile([[_recordingList objectAtIndex:i] valueForKey:VSO_REC_LIST_PATH_KEY]) error:NULL]) {
			[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"internal error", nil) message:[NSString stringWithFormat:NSLocalizedString(@"cannot delete recording. please contact developer error code #", nil), 2] delegate:self cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"ok", nil), nil] show];
			NSLog(@"Can't delete relative path \"%@\" (full path is: \"%@\")", [[_recordingList objectAtIndex:i] valueForKey:VSO_REC_LIST_PATH_KEY], fullPathFromRelativeForGPXFile([[_recordingList objectAtIndex:i] valueForKey:VSO_REC_LIST_PATH_KEY]));
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

- (void)viewDidUnload
{
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}

- (void)dealloc
{
	NSDLog(@"Releasing a VSORecordingListViewCtrl");
}

@end
