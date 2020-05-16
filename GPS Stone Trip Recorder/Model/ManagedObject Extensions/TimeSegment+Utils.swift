/*
 * TimeSegment+Utils.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 2020/5/15.
 * Copyright © 2020 Frost Land. All rights reserved.
 */

import Foundation



extension TimeSegment {
	
	var endDate: Date? {
		guard let startDate = startDate, let duration = duration?.doubleValue else {
			return nil
		}
		return startDate + TimeInterval(duration)
	}
	
	/**
	The duration of a time segment, even if the time segment is unfinished.
	
	A time segment can have a `nil` duration, in which case it is considered
	“unfinished,” and its effective duration is the time interval between the
	start date and now. */
	var effectiveDuration: TimeInterval {
		if let effectiveDuration = duration?.doubleValue {
			return TimeInterval(effectiveDuration)
		} else {
			guard let startDate = startDate else {
				NSLog("***** ERROR - Got an invalid time segment (nil startDate): %@", self)
				return 0
			}
			let interval = -startDate.timeIntervalSinceNow
			guard interval >= 0 else {
				NSLog("***** ERROR - Got an invalid time segment (startDate in the future): %@", self)
				return 0
			}
			return interval
		}
	}
	
}
