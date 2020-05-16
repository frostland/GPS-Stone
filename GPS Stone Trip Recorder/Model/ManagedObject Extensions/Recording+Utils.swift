/*
 * Recording+Utils.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 2019/7/29.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import Foundation



extension Recording {
	
	var numberOfRecordedPoints: Int {
		return points?.count ?? 0
	}
	
	/**
	The total time of the recording (including the pauses). */
	var recordingDuration: TimeInterval {
		if totalTimeSegment == nil {
			NSLog("***** ERROR - Got an invalid recording (nil totalTimeSegment): %@", self)
		}
		return TimeInterval(totalTimeSegment?.duration ?? 0)
	}
	
	/**
	The total time of the recording, but without the pauses. */
	var activeRecordingDuration: TimeInterval {
		let totalTime = recordingDuration
		guard let pauses = pauses else {
			NSLog("***** ERROR - Got an invalid recording (nil pauses): %@", self)
			return totalTime
		}
		let totalTimeMinusPauses = pauses.reduce(totalTime, { current, pauseTimeSegment in
			guard let pauseTimeSegment = pauseTimeSegment as? TimeSegment else {
				NSLog("***** ERROR - Got an invalid pause (not a TimeSegment): %@", self)
				return current
			}
			/* We do not validate the pause is indeed in the total time segment. We
			 * could but what would we do in case of invaid pause? */
			return current - pauseTimeSegment.duration
		})
		/* Let’s still verify we have a positive duration! */
		guard totalTimeMinusPauses >= 0 else {
			NSLog("***** ERROR - Total time minus pauses time is negative in recording %@", self)
			return 0
		}
		return totalTimeMinusPauses
	}
	
}
