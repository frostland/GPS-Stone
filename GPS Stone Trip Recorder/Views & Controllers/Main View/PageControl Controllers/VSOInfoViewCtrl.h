/*
 * VSOInfoViewCtrl.h
 * GPS Stone Trip Recorder
 *
 * Created by François on 7/11/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import <UIKit/UIKit.h>

#import "VSOInfoGenericController.h"



@interface VSOInfoViewCtrl : VSOInfoGenericController

@property(nonatomic, strong) IBOutlet NSLayoutConstraint *constraintMarginTopTitle;

@property(nonatomic, weak) IBOutlet UIButton *buttonRecord;

- (IBAction)openPreferences:(id)sender;

- (IBAction)showDetailedInfos:(id)sender;
- (IBAction)showPositionOnMap:(id)sender;
- (IBAction)startRecording:(id)sender;

@end
