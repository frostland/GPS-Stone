//
//  VSORecordingDetailViewCtrl.h
//  GPS Stone Trip Recorder
//
//  Created by François Lamboley on 8/4/09.
//  Copyright 2009 VSO-Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <MessageUI/MessageUI.h>
#import <AddressBookUI/AddressBookUI.h>

#import "VSOMapViewController.h"
#import "GPXgpxType.h"

@protocol VSORecordingDetailViewCtrlDelegate;

@interface VSORecordingDetailViewCtrl : UIViewController <UITextFieldDelegate, ABPeoplePickerNavigationControllerDelegate, MFMailComposeViewControllerDelegate> {
	IBOutlet UIView *viewSendingMail;
	IBOutlet UIView *viewWithMap;
	IBOutlet UIView *viewChooseMail;
	UIViewController *chooseMailCtrl;
	VSOMapViewController *mapViewController;
	
	IBOutlet UITextField *textFieldYourEmail;
	IBOutlet UITextField *textFieldDestEmails;
	
	IBOutlet UIView *viewForName;
	IBOutlet UITextField *textFieldName;
	IBOutlet UILabel *labelInfos;
	IBOutlet UILabel *labelDate;
	CGFloat vPosOfNameUIElements;
	
	BOOL sentWithiPhone;
	BOOL peoplePickerIsForFromField;
	
	NSMutableDictionary *recordingInfos;
	GPXgpxType *gpx;
	
	id <VSORecordingDetailViewCtrlDelegate> delegate;
	
	NSURLConnection *urlConnection;
}
@property(nonatomic, assign) id <VSORecordingDetailViewCtrlDelegate> delegate;
@property(nonatomic, retain) NSMutableDictionary *recordingInfos;
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil recording:(NSDictionary *)recInfos;

- (IBAction)done:(id)sender;
- (IBAction)exportGPX:(id)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)doneButtonOfNameEditingHit:(id)sender;

- (IBAction)yourMailEndEditing:(id)sender;
- (IBAction)destMailEndEditing:(id)sender;
- (IBAction)setYourMailFromAdressBook:(id)sender;
- (IBAction)addMailToDestFromAdressBook:(id)sender;

@end

@protocol VSORecordingDetailViewCtrlDelegate

- (void)nameChanged;
- (void)recordingsDetailViewControllerDidFinish:(VSORecordingDetailViewCtrl *)controller;

@end
