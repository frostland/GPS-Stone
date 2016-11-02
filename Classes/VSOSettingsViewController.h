//
//  VSOSettingsViewController.h
//  GPS Stone Trip Recorder
//
//  Created by François on 7/10/09.
//  Copyright VSO-Software 2009. All rights reserved.
//

@protocol VSOSettingsViewControllerDelegate;

@interface VSOSettingsViewController : UIViewController {
	IBOutlet UISegmentedControl *segmentedCtrlMapType;
	IBOutlet UITextField *textFieldMinDist;
	IBOutlet UITextField *textFieldMinTime;
	IBOutlet UITextField *textFieldTurnOffScreen;
	IBOutlet UISwitch *switchSkip;
	IBOutlet UISwitch *switchMetricMeasures;
	
	IBOutlet UIView *viewWithSettings;
	IBOutlet UIScrollView *scrollView;
	
	id <VSOSettingsViewControllerDelegate> delegate;
}
@property (nonatomic, assign) id <VSOSettingsViewControllerDelegate> delegate;
- (IBAction)done;

- (IBAction)mapTypeChanged:(id)sender;
- (IBAction)minDistChanged:(id)sender;
- (IBAction)minTimeChanged:(id)sender;
- (IBAction)timeBeforeSreenTurningOffChanged:(id)sender;

- (IBAction)skipNonAccuratePointsValueChanged:(id)sender;
- (IBAction)metricMeasuresValueChanged:(id)sender;

@end


@protocol VSOSettingsViewControllerDelegate

- (void)settingsViewControllerDidFinish:(VSOSettingsViewController *)controller;

@end
