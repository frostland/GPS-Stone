/*
 * MainViewController.h
 * GPS Stone Trip Recorder
 *
 * Created by François on 7/10/09.
 * Copyright VSO-Software 2009. All rights reserved.
 */

#import "VSOSettingsViewController.h"
#import "VSORecordingsListViewCtlr.h"

#import "VSODetailsViewCtrl.h"
#import "VSOMapViewController.h"
#import "VSOInfoViewCtrl.h"
#import "VSOScrollView.h"
#import "VSOBlankView.h"

#import "GPXgpxType.h"
#import "Constants.h"



/* Note: The code to manage the pages is found in the sample codes of Apple (sample named PageControl) */

#define SIMULATOR_CODE
#undef SIMULATOR_CODE

@interface MainViewController : UIViewController <VSOSettingsViewControllerDelegate, VSORecordingsListViewControllerDelegate, UIScrollViewDelegate, CLLocationManagerDelegate, VSOInfoGenericControllerDelegate> {
	IBOutlet VSOScrollView *pagesView;
	IBOutlet UIPageControl *pageControl;
	
	IBOutlet UIButton *buttonRecord;
	IBOutlet UIButton *buttonInfoDark;
	IBOutlet UIButton *buttonInfoLight;
	IBOutlet UIButton *buttonListOfRecordings;
	
	IBOutlet UIView *viewMiniInfos;
	IBOutlet UILabel *labelMiniInfosDistance;
	IBOutlet UILabel *labelMiniInfosRecordTime;
	IBOutlet UILabel *labelMiniInfosRecordingState;
	
	/* To manage the pages */
	int selPage;
	BOOL pageControlUsed;
	NSArray *ctrlClassesForPages;
	NSMutableArray *viewControllers;
	NSMutableArray *viewControllersStates;
	NSTimer *timerToUnloadUnusedPages;
	
	NSTimer *timerToTurnOffScreen;
	VSOBlankView *viewBlankScreen;
	int selPageBeforeShuttingScreenOff;
	
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
	
#ifdef SIMULATOR_CODE
	NSTimer *t;
	CLLocationCoordinate2D coordinate;
#endif
}
@property(nonatomic, assign) int selPage;
- (IBAction)showInfo;
- (IBAction)changePage:(id)sender;

- (IBAction)recordPauseButtonAction:(id)sender;
- (IBAction)showRecordsListStopRecordButtonAction:(id)sender;

- (void)setLocationServicesEnable:(BOOL)enabled;

- (void)saveRecordingListStoppingGPX:(BOOL)saveGPX;
- (void)recoverFromCrash;

@end
