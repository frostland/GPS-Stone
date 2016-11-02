//
//  VSORecordingsListViewCtlr.h
//  GPS Stone Trip Recorder
//
//  Created by François on 7/13/09.
//  Copyright 2009 VSO-Software. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "VSORecordingDetailViewCtrl.h"

@protocol VSORecordingsListViewControllerDelegate;

@interface VSORecordingsListViewCtlr : UIViewController <VSORecordingDetailViewCtrlDelegate> {
	IBOutlet UITableView *tableViewRecordings;
	IBOutlet UIBarButtonItem *buttonEdit;
	IBOutlet UIBarButtonItem *buttonDone;
	
	NSMutableArray *recordingList;
	
	id <VSORecordingsListViewControllerDelegate> delegate;
}
@property(nonatomic, retain) NSMutableArray *recordingList;
@property(nonatomic, assign) id <VSORecordingsListViewControllerDelegate> delegate;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil recordingList:(NSMutableArray *)recs;

- (IBAction)editTableView:(id)sender;
- (IBAction)done:(id)sender;

@end

@protocol VSORecordingsListViewControllerDelegate

- (void)recordingsListViewControllerDidFinish:(VSORecordingsListViewCtlr *)controller;

@end
