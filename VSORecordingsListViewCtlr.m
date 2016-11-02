//
//  VSORecordingsListViewCtlr.m
//  GPS Stone Trip Recorder
//
//  Created by François on 7/13/09.
//  Copyright 2009 VSO-Software. All rights reserved.
//

#import "VSORecordingsListViewCtlr.h"

#import "Constants.h"
#import "VSOUtils.h"

@implementation VSORecordingsListViewCtlr

@synthesize delegate, recordingList;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil recordingList:(NSMutableArray *)recs
{
	if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
		self.recordingList = recs;
		self.title = NSLocalizedString(@"recordings", nil);
	}
	return self;
}


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
	[super viewDidLoad];
	
	self.navigationItem.rightBarButtonItem = buttonDone;
	self.navigationItem.leftBarButtonItem = buttonEdit;
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
	buttonEdit.enabled = !tableViewEditing;
}

- (IBAction)editTableView:(id)sender
{
	[tableViewRecordings setEditing:YES animated:YES];
	[self updateTabBarButtons:tableViewRecordings.editing];
}

- (IBAction)done:(id)sender
{
	if (!tableViewRecordings.editing) [self.delegate recordingsListViewControllerDidFinish:self];
	else {
		[tableViewRecordings setEditing:NO  animated:YES];
		[self updateTabBarButtons:tableViewRecordings.editing];
	}
}


- (void)nameChanged
{
	[tableViewRecordings reloadData];
}

- (void)recordingsDetailViewControllerDidFinish:(VSORecordingDetailViewCtrl *)controller
{
	[self dismissModalViewControllerAnimated:YES];
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
	return [recordingList count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *CellIdentifier = @"Cell";
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	
	NSDictionary *curRecDescr = [recordingList objectAtIndex:[indexPath indexAtPosition:1]];
	cell.textLabel.text = [curRecDescr valueForKey:VSO_REC_LIST_NAME_KEY];
	
	NSString *distanceStr = NSStringFromDistance([[curRecDescr valueForKey:VSO_REC_LIST_TOTAL_REC_DISTANCE_KEY] doubleValue]);
	NSString *recTimeStr = NSStringFromTimeInterval([[curRecDescr valueForKey:VSO_REC_LIST_TOTAL_REC_TIME_KEY] doubleValue]);
	cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ / %@", recTimeStr, distanceStr];
	
	return cell;
}

// Override to support row selection in the table view.
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSMutableDictionary *rec = [[recordingList objectAtIndex:[indexPath indexAtPosition:1]] mutableCopy];
	[recordingList replaceObjectAtIndex:[indexPath indexAtPosition:1] withObject:rec];
	
	VSORecordingDetailViewCtrl *controller = [[VSORecordingDetailViewCtrl alloc] initWithNibName:@"VSORecordingDetailView" bundle:nil recording:rec];
	controller.delegate = self;
	[self.navigationController pushViewController:controller animated:YES];
	[controller release];
	
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	return YES;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		NSUInteger i = [indexPath indexAtPosition:1];
		
		NSFileManager *fm = [NSFileManager defaultManager];
		if (![fm removeItemAtPath:fullPathFromRelativeForGPXFile([[recordingList objectAtIndex:i] valueForKey:VSO_REC_LIST_PATH_KEY]) error:NULL]) {
			[[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"internal error", nil) message:[NSString stringWithFormat:NSLocalizedString(@"cannot delete recording. please contact developer error code #", nil), 2] delegate:self cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"ok", nil), nil] autorelease] show];
			NSLog(@"Can't delete relative path \"%@\" (full path is: \"%@\")", [[recordingList objectAtIndex:i] valueForKey:VSO_REC_LIST_PATH_KEY], fullPathFromRelativeForGPXFile([[recordingList objectAtIndex:i] valueForKey:VSO_REC_LIST_PATH_KEY]));
			return;
		}
		[recordingList removeObjectAtIndex:i];
		
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
	
	[recordingList release];
	
	[super dealloc];
}

@end
