/*
 * VSORecordingDetailViewCtrl.m
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 8/4/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import "VSORecordingDetailViewCtrl.h"

#import "Constants.h"
#import "VSOUtils.h"



@implementation VSORecordingDetailViewCtrl

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
	if ([elementName isEqualToString:@"gpx"]) {
		gpx = [[GPXgpxType alloc] initWithAttributes:attributeDict elementName:elementName];
		parser.delegate = gpx;
	} else {
		NSLog(@"*** Error when parsing gpx file. Found a \"%@\" root element.", elementName);
	}
}

- (void)setRecordingInfos:(NSMutableDictionary *)recordingInfos
{
	_recordingInfos = recordingInfos;
	
	NSString *path = fullPathFromRelativeForGPXFile([_recordingInfos valueForKey:VSO_REC_LIST_PATH_KEY]);
	NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:[NSData dataWithContentsOfFile:path]];
	[xmlParser setDelegate:self];
	[xmlParser parse];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
	[super viewDidLoad];
	
	self.title = [_recordingInfos valueForKey:VSO_REC_LIST_NAME_KEY];
	
	NSTimeInterval time = [[_recordingInfos valueForKey:VSO_REC_LIST_TOTAL_REC_TIME_KEY] doubleValue];
	NSTimeInterval distance = [[_recordingInfos valueForKey:VSO_REC_LIST_TOTAL_REC_DISTANCE_KEY] doubleValue];
	[labelInfos setText:[NSString stringWithFormat:@"%@ / %@ / %@", NSStringFromTimeInterval(time), NSStringFromDistance(distance), NSStringFromSpeed(distance/time, YES)]];
	[labelDate setText:NSStringFromDate([_recordingInfos valueForKey:VSO_REC_LIST_DATE_END_KEY])];
	
	[textFieldName setText:[_recordingInfos valueForKey:VSO_REC_LIST_NAME_KEY]];
	
	mapViewController = [VSOMapViewController instantiateWithGPX:gpx location:nil];
	mapViewController.showUL = YES;
	
	CGRect frame = viewWithMap.frame;
	frame.origin.x = 0;
	frame.origin.y = 0;
	mapViewController.view.frame = frame;
	[mapViewController hideStatusBarBlur];
	[viewWithMap addSubview:mapViewController.view];
	
	[mapViewController initDrawnPathWithCurrentGPX];
	[mapViewController redrawLastSegmentOnMap];
	mapViewController.followULCentersOnTrip = YES;
	[mapViewController centerMapOnCurLoc:nil];
}


/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (IBAction)done:(id)sender
{
	[self.delegate recordingsDetailViewControllerDidFinish:self];
}

- (IBAction)doneButtonOfNameEditingHit:(id)sender
{
	[textFieldName resignFirstResponder];
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
	if (textField != textFieldName) return YES;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:VSO_ANIM_TIME];
	constraintNameNoKeyboard.active = NO;
	constraintNameKeyboard.active = YES;
	viewWithMap.alpha = 0.;
	[self.view layoutIfNeeded];
	[UIView commitAnimations];
	
	return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
	if (textField != textFieldName) return;
	
	[_recordingInfos setValue:[textFieldName text] forKey:VSO_REC_LIST_NAME_KEY];
	self.title = [textFieldName text];
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:VSO_ANIM_TIME];
	constraintNameNoKeyboard.active = YES;
	constraintNameKeyboard.active = NO;
	viewWithMap.alpha = 1.;
	[self.view layoutIfNeeded];
	[UIView commitAnimations];
	
	[self.delegate nameChanged];
}

- (IBAction)exportGPX:(id)sender
{
	if (!MFMailComposeViewController.canSendMail) {
		[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"configure mail", nil) message:[NSString stringWithFormat:NSLocalizedString(@"to export a GPX file, you must configure at least one email address in your phone settings", nil), 1] delegate:self cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"ok", nil), nil] show];
		return;
	}
	
	if (MFMailComposeViewController.canSendMail) {
		MFMailComposeViewController *ctrl = [MFMailComposeViewController new];
		ctrl.mailComposeDelegate = self;
		
		[ctrl setSubject:NSLocalizedString(@"gpx file sent", nil)];
		[ctrl addAttachmentData:[NSData dataWithContentsOfFile:fullPathFromRelativeForGPXFile([_recordingInfos valueForKey:VSO_REC_LIST_PATH_KEY])]
							mimeType:@"application/octet-stream" fileName:[NSString stringWithFormat:@"%@.gpx", [_recordingInfos valueForKey:VSO_REC_LIST_NAME_KEY]]];
		
		[self presentViewController:ctrl animated:YES completion:NULL];
	}
}

- (IBAction)cancel:(id)sender
{
	[self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}
	
- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
	[controller dismissViewControllerAnimated:YES completion:NULL];
}

@end
