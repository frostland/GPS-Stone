/*
 * VSORecordingsListViewCtlr.h
 * GPS Stone Trip Recorder
 *
 * Created by François on 7/13/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import <UIKit/UIKit.h>

#import "VSORecordingDetailViewCtrl.h"



@protocol VSORecordingsListViewControllerDelegate;

@interface VSORecordingsListViewCtlr : UITableViewController <VSORecordingDetailViewCtrlDelegate> {
	IBOutlet UIBarButtonItem *buttonDone;
}

@property(nonatomic, retain) NSMutableArray *recordingList;
@property(nonatomic, weak) id <VSORecordingsListViewControllerDelegate> delegate;

- (IBAction)done:(id)sender;

@end



@protocol VSORecordingsListViewControllerDelegate

- (void)recordingsListViewControllerDidFinish:(VSORecordingsListViewCtlr *)controller;

@end
