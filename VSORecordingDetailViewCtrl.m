//
//  VSORecordingDetailViewCtrl.m
//  GPS Stone Trip Recorder
//
//  Created by François Lamboley on 8/4/09.
//  Copyright 2009 VSO-Software. All rights reserved.
//

#import "VSORecordingDetailViewCtrl.h"

#import "Constants.h"
#import "VSOUtils.h"

#define VSO_URL_TO_SEND_MAIL @"http://www.vso-software.fr/products/atomgps/iphone-mail.php"

@interface VSORecordingDetailViewCtrl (GPXExport)

- (void)sendMailWithVSO:(BOOL)useVSO;

@end


@implementation VSORecordingDetailViewCtrl (GPXExport)

- (void)removeSendingMailView
{
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:VSO_ANIM_TIME];
	viewSendingMail.alpha = 0.;
	[UIView commitAnimations];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	if (sentWithiPhone) return;
	
	/* Errors:
	 1: $mail->send returned an error
	 2: Bad file extension
	 3: No from field
	 4: Bad file type
	 5: No attachement file with name "GPXFile"
	 */
	NSString *errMsg = nil;
	NSUInteger err = [[[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease] intValue];
	switch (err) {
		case 0: /* No Err */ break;
		case 1:
		case 2:
		case 3:
		case 4:
		case 5: errMsg = [NSString stringWithFormat:NSLocalizedString(@"server error when sending mail code#", nil), 10+err]; break;
		default: errMsg = @""; break;
	}
	
	[self removeSendingMailView];
	if (errMsg != nil) [[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"cannot send mail", nil) message:errMsg delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"ok", nil), nil] autorelease] show];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	if (sentWithiPhone) return;
	
	NSString *errMsg = [NSString stringWithFormat:NSLocalizedString(@"reason: %@", nil), [error localizedDescription]];
	
	[self removeSendingMailView];
	[[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"cannot send mail", nil) message:errMsg delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"ok", nil), nil] autorelease] show];
}

- (void)sendMailWithVSO:(BOOL)useVSO
{
	NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleVersion"];
	if (!appVersion) appVersion = @"Unknown version. Intern bug...";
	
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:VSO_URL_TO_SEND_MAIL]];
	[request setHTTPMethod:@"POST"];
	
	NSString *boundary = @"---------------------------14v742198x6p3s1466499882128og901449VSO";
	NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
	[request addValue:contentType forHTTPHeaderField:@"Content-Type"];
	
	NSMutableData *body = [NSMutableData data];
	[body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
	[body appendData:[@"Content-Disposition: form-data; name=\"appVersion\"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
	[body appendData:[[NSString stringWithFormat:@"%@\n", appVersion] dataUsingEncoding:NSUTF8StringEncoding]];
	
	if (useVSO) {
		[body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
		[body appendData:[@"Content-Disposition: form-data; name=\"sendTo\"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
		[body appendData:[[NSString stringWithFormat:@"%@\n", textFieldDestEmails.text] dataUsingEncoding:NSUTF8StringEncoding]];
		
		[body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
		[body appendData:[@"Content-Disposition: form-data; name=\"fromField\"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
		[body appendData:[[NSString stringWithFormat:@"%@\n", [textFieldYourEmail.text isEqualToString:@""]? @"noreply@vso-software.com": textFieldYourEmail.text] dataUsingEncoding:NSUTF8StringEncoding]];
		
		[body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
		[body appendData:[@"Content-Disposition: form-data; name=\"mailTitle\"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
		[body appendData:[[NSString stringWithFormat:@"%@\n", NSLocalizedString(@"gpx file sent", nil)] dataUsingEncoding:NSUTF8StringEncoding]];
	}
	
	[body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
	[body appendData:[@"Content-Disposition: form-data; name=\"sentWithDefaultiPhoneMailSheet\"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
	[body appendData:[[NSString stringWithFormat:@"%d\n", !useVSO] dataUsingEncoding:NSUTF8StringEncoding]];
	
	[body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
	[body appendData:[@"Content-Disposition: form-data; name=\"lang\"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
	[body appendData:[[NSString stringWithFormat:@"%@\n", [[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode]] dataUsingEncoding:NSUTF8StringEncoding]];
	
	[body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
	[body appendData:[@"Content-Disposition: form-data; name=\"deviceID\"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
	[body appendData:[[NSString stringWithFormat:@"%@\n", [[UIDevice currentDevice] uniqueIdentifier]] dataUsingEncoding:NSUTF8StringEncoding]];
	
	[body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
	[body appendData:[[NSString stringWithFormat:@"Content-Disposition: file; name=\"GPXFile\"; filename=\"%@.gpx\"\r\n", [recordingInfos valueForKey:VSO_REC_LIST_NAME_KEY]] dataUsingEncoding:NSUTF8StringEncoding]];
	[body appendData:[[NSString stringWithString:@"Content-Type: application/octet-stream\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
	[body appendData:[NSData dataWithContentsOfFile:fullPathFromRelativeForGPXFile([recordingInfos valueForKey:VSO_REC_LIST_PATH_KEY])]];
	[body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
	[request setHTTPBody:body];
	
	urlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
}

@end

@implementation VSORecordingDetailViewCtrl

@synthesize delegate, recordingInfos;

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
	if ([elementName isEqualToString:@"gpx"]) {
		gpx = [[GPXgpxType alloc] initWithAttributes:attributeDict elementName:elementName];
		parser.delegate = gpx;
	} else {
		NSLog(@"*** Error when parsing gpx file. Found a \"%@\" root element.", elementName);
	}
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil recording:(NSMutableDictionary *)recInfos
{
	if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
		self.recordingInfos = recInfos;
		
		NSString *path = fullPathFromRelativeForGPXFile([recordingInfos valueForKey:VSO_REC_LIST_PATH_KEY]);
		NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:[NSData dataWithContentsOfFile:path]];
		[xmlParser setDelegate:self];
		[xmlParser parse];
		[xmlParser release];
	}
	return self;
}


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
	[super viewDidLoad];
	
	viewSendingMail.alpha = 0.;
	[self.view addSubview:viewSendingMail];
	vPosOfNameUIElements = viewForName.frame.origin.y;
	self.title = [recordingInfos valueForKey:VSO_REC_LIST_NAME_KEY];
	
	NSTimeInterval time = [[recordingInfos valueForKey:VSO_REC_LIST_TOTAL_REC_TIME_KEY] doubleValue];
	NSTimeInterval distance = [[recordingInfos valueForKey:VSO_REC_LIST_TOTAL_REC_DISTANCE_KEY] doubleValue];
	[labelInfos setText:[NSString stringWithFormat:@"%@ / %@ / %@", NSStringFromTimeInterval(time), NSStringFromDistance(distance), NSStringFromSpeed(distance/time, YES)]];
	[labelDate setText:NSStringFromDate([recordingInfos valueForKey:VSO_REC_LIST_DATE_END_KEY])];
	
	[textFieldName setText:[recordingInfos valueForKey:VSO_REC_LIST_NAME_KEY]];
	
	mapViewController = [[VSOMapViewController alloc] initWithGPX:gpx location:nil];
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
	
	[recordingInfos setValue:[textFieldName text] forKey:VSO_REC_LIST_NAME_KEY];
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

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
	if (result == MFMailComposeResultSent) [self sendMailWithVSO:NO];
	
	[self dismissModalViewControllerAnimated:YES];
}

- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker
{
	[chooseMailCtrl dismissModalViewControllerAnimated:YES];
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person
{
	return YES;
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier
{
	CFTypeRef emails = ABRecordCopyValue(person, kABPersonEmailProperty);
	NSString *email = (NSString *)ABMultiValueCopyValueAtIndex(emails, ABMultiValueGetIndexForIdentifier(emails, identifier));
	
	if (peoplePickerIsForFromField) {
		[textFieldYourEmail setText:email];
		[[NSUserDefaults standardUserDefaults] setValue:textFieldYourEmail.text forKey:VSO_UDK_USER_EMAIL];
	} else {
		if (![textFieldDestEmails.text isEqualToString:@""]) [textFieldDestEmails setText:[textFieldDestEmails.text stringByAppendingFormat:@",%@", email]];
		else                                                 [textFieldDestEmails setText:email];
	}
	[chooseMailCtrl dismissModalViewControllerAnimated:YES];
	
	return NO;
}

- (IBAction)exportGPX:(id)sender
{
	if ([MFMailComposeViewController canSendMail]) {
		sentWithiPhone = YES;
		
		MFMailComposeViewController *ctrl = [MFMailComposeViewController new];
		ctrl.mailComposeDelegate = self;
		
		[ctrl setSubject:NSLocalizedString(@"gpx file sent", nil)];
		[ctrl addAttachmentData:[NSData dataWithContentsOfFile:fullPathFromRelativeForGPXFile([recordingInfos valueForKey:VSO_REC_LIST_PATH_KEY])]
							mimeType:@"application/octet-stream" fileName:[NSString stringWithFormat:@"%@.gpx", [recordingInfos valueForKey:VSO_REC_LIST_NAME_KEY]]];
		
		[self presentModalViewController:ctrl animated:YES];
		
		[ctrl release];
	} else {
		sentWithiPhone = NO;
		
		chooseMailCtrl = [[UIViewController alloc] initWithNibName:nil bundle:nil];
		[chooseMailCtrl setView:viewChooseMail];
		
		[textFieldYourEmail setText:[[NSUserDefaults standardUserDefaults] valueForKey:VSO_UDK_USER_EMAIL]];
		if ([textFieldYourEmail.text isEqualToString:@""]) [textFieldYourEmail becomeFirstResponder];
		else                                               [textFieldDestEmails becomeFirstResponder];
		
		chooseMailCtrl.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
		[self presentModalViewController:chooseMailCtrl animated:YES];
		
		[chooseMailCtrl release];
	}
}

- (IBAction)cancel:(id)sender
{
	[self dismissModalViewControllerAnimated:YES];
}

- (IBAction)yourMailEndEditing:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setValue:textFieldYourEmail.text forKey:VSO_UDK_USER_EMAIL];
	[textFieldYourEmail resignFirstResponder];
	[textFieldDestEmails becomeFirstResponder];
}

- (IBAction)destMailEndEditing:(id)sender
{
	[textFieldDestEmails resignFirstResponder];
	[self dismissModalViewControllerAnimated:YES];
	
	/* We're sending the mail through VSO here */
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:VSO_ANIM_TIME];
	viewSendingMail.alpha = 1.;
	
	[self sendMailWithVSO:YES];
	
	[UIView commitAnimations];
}

- (void)showPeoplePicker
{
	ABPeoplePickerNavigationController *ctrl = [ABPeoplePickerNavigationController new];
	[ctrl setDisplayedProperties:[NSArray arrayWithObjects:[NSNumber numberWithInt:kABPersonEmailProperty], nil]];
	ctrl.peoplePickerDelegate = self;
	
	ctrl.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
	[chooseMailCtrl presentModalViewController:ctrl animated:YES];
	
	[ctrl release];
}

- (IBAction)setYourMailFromAdressBook:(id)sender
{
	peoplePickerIsForFromField = YES;
	[self showPeoplePicker];
}

- (IBAction)addMailToDestFromAdressBook:(id)sender
{
	peoplePickerIsForFromField = NO;
	[self showPeoplePicker];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void)dealloc
{
	[recordingInfos release];
	
	[super dealloc];
}

@end
