/*
 * VSOInfoViewCtrl.h
 * GPS Stone Trip Recorder
 *
 * Created by François on 7/11/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import <UIKit/UIKit.h>

#import "VSOInfoGenericController.h"



@interface VSOInfoViewCtrl : VSOInfoGenericController {
	IBOutlet UIButton *buttonRecord;
}
- (IBAction)showDetailedInfos;
- (IBAction)showPositionOnMap;
- (IBAction)recordPosition;

@end
