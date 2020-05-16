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
		guard let startDate = startDate else {
			return nil
		}
		return startDate + TimeInterval(duration)
	}
	
}
