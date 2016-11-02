/*
 * VSODetailsViewCtrl.h
 * GPS Stone Trip Recorder
 *
 * Created by François on 7/11/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import <UIKit/UIKit.h>

#import "VSOInfoGenericController.h"



@interface VSODetailsViewCtrl : VSOInfoGenericController {
	IBOutlet UILabel *labelLat, *labelLong;
	IBOutlet UILabel *labelSpeed, *labelAverageSpeed, *labelMaxSpeed;
	IBOutlet UILabel *labelHorizontalAccuracy;
	IBOutlet UILabel *labelAltitude, *labelVerticalAccuracy;
	IBOutlet UILabel *labelNumberOfPoints, *labelTotalDistance, *labelElapsedTime;
	IBOutlet UILabel *labelTrackName;
	IBOutlet UILabel *labelKmph;
	IBOutlet UIImageView *imageNorth;
	
	IBOutlet UIView *viewWithTrackInfos;
	
	IBOutlet UIButton *buttonRecord;
}
- (IBAction)startRecord:(id)sender;

@end
