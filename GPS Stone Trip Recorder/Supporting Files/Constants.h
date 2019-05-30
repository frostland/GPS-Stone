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
