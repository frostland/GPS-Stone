/*
 * MainViewController.h
 * GPS Stone
 *
 * Created by François on 7/10/09.
 * Copyright VSO-Software 2009. All rights reserved.
 */

#import "VSOSettingsViewController.h"
#import "VSORecordingsListViewCtlr.h"

#import "VSODetailsViewCtrl.h"
#import "VSOMapViewController.h"
#import "VSOInfoViewCtrl.h"

#import "GPXgpxType.h"
#import "Constants.h"



/* Note: The code to manage the pages is found in the sample codes of Apple (sample named PageControl) */

@interface MainViewController_OBS : UIViewController <VSOSettingsViewControllerDelegate, VSORecordingsListViewControllerDelegate, UIScrollViewDelegate, CLLocationManagerDelegate, VSOInfoGenericControllerDelegate> {
	IBOutlet UIScrollView *pagesView;
	IBOutlet UIPageControl *pageControl;
	
	IBOutlet UIButton *buttonRecord;
	IBOutlet UIButton *buttonListOfRecordings;
	
	IBOutlet UIView *viewMiniInfos;
	IBOutlet UILabel *labelMiniInfosDistance;
	IBOutlet UILabel *labelMiniInfosRecordTime;
	IBOutlet UILabel *labelMiniInfosRecordingState;
	
	/* To manage the pages */
	NSInteger selPage;
	BOOL pageControlUsed;
	NSArray *ctrlClassesForPages;
	NSMutableArray *viewControllers;
	NSMutableArray *viewControllersStates;
	NSTimer *timerToUnloadUnusedPages;
	
	NSMutableArray *recordingList;
	
	GPXgpxType *currentGpx;
	GPXtrksegType *currentTracksegment;
	NSString *currentGpxOutputPath;
	NSFileHandle *currentGpxOutput;
	
	VSORecordState recordState;
	NSDate *dateRecordStart;
	NSMutableDictionary *currentRecordingInfo;
	
	CLLocationManager *locationManager;
	CLLocation *currentLocation;
	NSTimer *timerToRefreshTimes;
	
	BOOL alertIsForStop;
}

@property(nonatomic, assign) NSInteger selPage;

- (IBAction)showInfo;
- (IBAction)changePage:(id)sender;

- (IBAction)recordPauseButtonAction:(id)sender;
- (IBAction)showRecordsListStopRecordButtonAction:(id)sender;

- (void)saveRecordingListStoppingGPX:(BOOL)saveGPX;
- (void)recoverFromCrash;

@end
