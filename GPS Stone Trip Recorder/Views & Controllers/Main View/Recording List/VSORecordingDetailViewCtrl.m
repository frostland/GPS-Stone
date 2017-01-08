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

#define VSO_URL_TO_SEND_MAIL @"http://www.vso-software.fr/products/atomgps/iphone-mail.php"



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
	
	viewSendingMail.alpha = 0.;
	[self.view addSubview:viewSendingMail];
	vPosOfNameUIElements = viewForName.frame.origin.y;
	self.title = [_recordingInfos valueForKey:VSO_REC_LIST_NAME_KEY];
	
	NSTimeInterval time = [[_recordingInfos valueForKey:VSO_REC_LIST_TOTAL_REC_TIME_KEY] doubleValue];
	NSTimeInterval distance = [[_recordingInfos valueForKey:VSO_REC_LIST_TOTAL_REC_DISTANCE_KEY] doubleValue];
	[labelInfos setText:[NSString stringWithFormat:@"%@ / %@ / %@", NSStringFromTimeInterval(time), NSStringFromDistance(distance), NSStringFromSpeed(distance/time, YES)]];
	[labelDate setText:NSStringFromDate([_recordingInfos valueForKey:VSO_REC_LIST_DATE_END_KEY])];
	
	[textFieldName setText:[_recordingInfos valueForKey:VSO_REC_LIST_NAME_KEY]];
	
	mapViewController = [VSOMapViewController instantiateWithGPX:gpx location:nil];
	mapViewController.showUL = NO;
	
	CGRect frame = viewWithMap.frame;
	frame.origin.x = 0;
	frame.origin.y = 0;
	mapViewController.view.frame = frame;
	[viewWithMap addSubview:mapViewController.view];
	
	[mapViewController initDrawnPathWithCurrentGPX];
	[mapViewController redrawAllPointsOnMap];
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
	
	CGRect f = viewForName.frame;
	f.origin.y = 30;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:VSO_ANIM_TIME];
	viewForName.frame = f;
	viewWithMap.alpha = 0.;
	[UIView commitAnimations];
	
	return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
	if (textField != textFieldName) return;
	
	[_recordingInfos setValue:[textFieldName text] forKey:VSO_REC_LIST_NAME_KEY];
	self.title = [textFieldName text];
	
	CGRect f = viewForName.frame;
	f.origin.y = vPosOfNameUIElements;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:VSO_ANIM_TIME];
	viewForName.frame = f;
	viewWithMap.alpha = 1.;
	[UIView commitAnimations];
	
	[self.delegate nameChanged];
}

- (IBAction)exportGPX:(id)sender
{
	if ([MFMailComposeViewController canSendMail]) {
		sentWithiPhone = YES;
		
		MFMailComposeViewController *ctrl = [MFMailComposeViewController new];
		ctrl.mailComposeDelegate = self;
		
		[ctrl setSubject:NSLocalizedString(@"gpx file sent", nil)];
		[ctrl addAttachmentData:[NSData dataWithContentsOfFile:fullPathFromRelativeForGPXFile([_recordingInfos valueForKey:VSO_REC_LIST_PATH_KEY])]
							mimeType:@"application/octet-stream" fileName:[NSString stringWithFormat:@"%@.gpx", [_recordingInfos valueForKey:VSO_REC_LIST_NAME_KEY]]];
		
		[self presentModalViewController:ctrl animated:YES];
	} else {
		sentWithiPhone = NO;
		
		chooseMailCtrl = [[UIViewController alloc] initWithNibName:nil bundle:nil];
		[chooseMailCtrl setView:viewChooseMail];
		
		[textFieldYourEmail setText:[[NSUserDefaults standardUserDefaults] valueForKey:VSO_UDK_USER_EMAIL]];
		if ([textFieldYourEmail.text isEqualToString:@""]) [textFieldYourEmail becomeFirstResponder];
		else                                               [textFieldDestEmails becomeFirstResponder];
		
		chooseMailCtrl.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
		[self presentModalViewController:chooseMailCtrl animated:YES];
	}
}

- (IBAction)cancel:(id)sender
{
	[self dismissModalViewControllerAnimated:YES];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

@end
