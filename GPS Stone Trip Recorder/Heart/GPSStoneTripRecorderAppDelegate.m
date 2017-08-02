/*
 * GPSRecorderAppDelegate.m
 * GPS Stone Trip Recorder
 *
 * Created by François on 7/10/09.
 * Copyright VSO-Software 2009. All rights reserved.
 */

#import <MapKit/MKTypes.h>

#import "GPSStoneTripRecorderAppDelegate.h"
#import "MainViewController.h"

#import "VSOUtils.h"



@implementation GPSStoneTripRecorderAppDelegate

@synthesize window;

+ (void)initialize
{
	NSMutableDictionary *defaultValues = [NSMutableDictionary dictionary];
	
	[defaultValues setValue:@YES                 forKey:VSO_UDK_FIRST_RUN];
	[defaultValues setValue:@YES                 forKey:VSO_UDK_FIRST_UNLOCK];
	[defaultValues setValue:@0                   forKey:VSO_UDK_SELECTED_PAGE];
	[defaultValues setValue:@(MKMapTypeStandard) forKey:VSO_UDK_MAP_TYPE];
	[defaultValues setValue:@25                  forKey:VSO_UDK_MIN_PATH_DISTANCE];
	[defaultValues setValue:@YES                 forKey:VSO_UDK_PAUSE_ON_QUIT];
	[defaultValues setValue:@YES                 forKey:VSO_UDK_SKIP_NON_ACCURATE_POINTS];
	[defaultValues setValue:@NO                  forKey:VSO_UDK_MAP_SWIPE_WARNING_SHOWN];
	[defaultValues setValue:@YES                 forKey:VSO_UDK_SHOW_MEMORY_CLEAR_WARNING];
	[defaultValues setValue:@NO                  forKey:VSO_UDK_MEMORY_WARNING_PATH_CUT_SHOWN];
	[defaultValues setValue:@2                   forKey:VSO_UDK_MIN_TIME_FOR_UPDATE];
	[defaultValues setValue:@""                  forKey:VSO_UDK_USER_EMAIL];
	[defaultValues setValue:@(VSODistanceUnitAutomatic) forKey:VSO_UDK_DISTANCE_UNIT];
	
	[NSUserDefaults.standardUserDefaults registerDefaults:defaultValues];
}

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex
{
	exit(1);
}

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	NSFileManager *fm = [NSFileManager defaultManager];
	/* Creating data dir */
	if (![fm createDirectoryAtPath:VSO_PATH_TO_FOLDER_WITH_GPX_FILES withIntermediateDirectories:YES attributes:nil error:NULL]) {
		[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"internal error", nil) message:[NSString stringWithFormat:NSLocalizedString(@"please contact developer error code #", nil), 1] delegate:self cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"ok", nil), nil] show];
		return YES;
	}
	
	rootViewController = (MainViewController *)self.window.rootViewController;
	
	if ([fm fileExistsAtPath:VSO_PATH_TO_NICE_EXIT_WITNESS]) {
		NSLog(@"Last exit was forced");
		[rootViewController recoverFromCrash];
	}
	[NSData.data writeToFile:VSO_PATH_TO_NICE_EXIT_WITNESS atomically:NO];
	return YES;
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	[rootViewController saveRecordingListStoppingGPX:YES];
	[NSFileManager.defaultManager removeItemAtPath:VSO_PATH_TO_NICE_EXIT_WITNESS error:NULL];
}

@end
