/*
 *  Constants.h
 *  GPS Stone Trip Recorder
 *
 *  Created by François on 7/13/09.
 *  Copyright 2009 VSO-Software. All rights reserved.
 *
 */

typedef enum VSORecordState {
	VSORecordStateStopped = 0,
	VSORecordStatePaused,
	VSORecordStateRecording,
	VSORecordStateWaitingGPS,
	VSORecordStateScreenLocked
} VSORecordState;

typedef enum VSODistanceUnit {
	VSODistanceUnitKilometers = 0,
	VSODistanceUnitMiles
} VSODistanceUnit;

#define ONE_MILE_INTO_KILOMETER 1.609344
#define ONE_FOOT_INTO_METER 0.3048

#define VSO_COORD_PRINT_FORMAT @"%.10f"

#define VSO_MAIN_DATA_DIR [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]
#define VSO_PATH_TO_NICE_EXIT_WITNESS [VSO_MAIN_DATA_DIR stringByAppendingPathComponent:@"Unclean Exit Witness.witness"]
#define VSO_PATH_TO_FOLDER_WITH_GPX_FILES [VSO_MAIN_DATA_DIR stringByAppendingPathComponent:@"GPX Files/"]
#define VSO_PATH_TO_GPX_LIST [VSO_PATH_TO_FOLDER_WITH_GPX_FILES stringByAppendingPathComponent:@"GPX Files List Description.data"]
#define VSO_PATH_TO_PAUSED_REC_WITNESS [VSO_PATH_TO_FOLDER_WITH_GPX_FILES stringByAppendingPathComponent:@"Last Recording Is Paused.witness"]
#define VSO_BASE_PATH_TO_GPX [VSO_PATH_TO_FOLDER_WITH_GPX_FILES stringByAppendingPathComponent:@"Recording #"]

#define VSO_MAX_ACCURACY_TO_RECORD_POINT 50 /* Meters */

/* Constants for the GPX List file format */
#define VSO_REC_LIST_DATE_END_KEY @"Date"
#define VSO_REC_LIST_PATH_KEY @"Rec Path"
#define VSO_REC_LIST_NAME_KEY @"Recording Name"
#define VSO_REC_LIST_TOTAL_REC_TIME_KEY @"Total Record Time"
#define VSO_REC_LIST_TOTAL_REC_TIME_BEFORE_LAST_PAUSE_KEY @"Total Record Time Before Last Pause"
#define VSO_REC_LIST_TOTAL_REC_DISTANCE_KEY @"Total Record Distance"
#define VSO_REC_LIST_MAX_SPEED_KEY @"Max Reached Speed"
#define VSO_REC_LIST_AVERAGE_SPEED_KEY @"Average Speed"
#define VSO_REC_LIST_N_REG_POINTS_KEY @"N Points Recorded"
#define VSO_REC_LIST_RECORD_STATE_KEY @"Record State"
#define VSO_REC_LIST_STORED_POINTS_FOR_CLASS_KEY(class) [NSString stringWithFormat:@"Stored Points For Class %@", NSStringFromClass(class)]

/* Constants for UI */
#define VSO_INFO_X_POS 295
#define VSO_INFO_Y_POS 7
#define VSO_INFO_X_POS_FOR_PAGE_WITH_DETAILED_INFOS 291
#define VSO_INFO_Y_POS_FOR_PAGE_WITH_DETAILED_INFOS 10
#define VSO_PAGE_NUMBER_WITH_MAP 2
#define VSO_PAGE_NUMBER_WITH_GENERAL_INFOS 0
#define VSO_PAGE_NUMBER_WITH_DETAILED_INFOS 1
#define VSO_DELAY_BEFORE_ALLOWING_SCROLL 0.20 /* Seconds */
#define VSO_ANIM_TIME 0.3

/* Constants for user defaults */
#define VSO_UDK_FIRST_RUN @"VSO First Run"
#define VSO_UDK_FIRST_UNLOCK @"VSO Screen Never Locked While This App Is Launched"
#define VSO_UDK_SELECTED_PAGE @"VSO Selected Page"
#define VSO_UDK_MAP_TYPE @"VSO Map Type"
#define VSO_UDK_MAP_REGION @"VSO Map Region"
#define VSO_UDK_PAUSE_ON_QUIT @"VSO Pause When Quitting Instead Of Stopping"
#define VSO_UDK_SKIP_NON_ACCURATE_POINTS @"VSO Skip Non Accurate Points"
#define VSO_UDK_MAP_SWIPE_WARNING_SHOWN @"VSO Map Swipe Warning Was Shown"
#define VSO_UDK_SHOW_MEMORY_CLEAR_WARNING @"VSO Stored Points Clearing Wrarning"
#define VSO_UDK_MEMORY_WARNING_PATH_CUT_SHOWN @"VSO Path Cut Memory Warning Shown"
#define VSO_UDK_MIN_PATH_DISTANCE @"VSO Min Distance Before Adding Point" /* Value is in meter */
#define VSO_UDK_MIN_TIME_FOR_UPDATE @"VSO Min Time Between Updates" /* Value is in second */
#define VSO_UDK_DISTANCE_UNIT @"VSO Distance Unit"
#define VSO_UDK_USER_EMAIL @"VSO User eMail"

/* Constants for the names of the notifications */
#define VSO_NTF_SETTINGS_CHANGED @"VSO App Settings Changed"
