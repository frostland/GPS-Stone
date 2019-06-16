/*
 * RecordingInfo.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 2019/6/8.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import CoreLocation
import Foundation



struct RecordingInfo : Codable {
	
	struct DateAndDuration : Codable {
		
		var dateStart: Date
		var duration: TimeInterval
		
		var dateEnd: Date {
			return dateStart + duration
		}
		
	}
	
	init(gpxURL url: URL, name n: String) {
		gpxURL = url
		name = n
		
		dateAndDuration = DateAndDuration(dateStart: Date(), duration: 0)
		pauses = []
		
		totalDistance = 0
		
		maxSpeed = 0
		averageSpeed = 0
		
		numberOfRecordedPoints = 0
	}
	
	var gpxURL: URL
	var name: String
	
	/** The total time spend recording the position.
	
	This is **not** necessarily equal to `dateAndDuration.duration` because the
	recording can have pauses. */
	var totalRecordedTime: TimeInterval {
		return dateAndDuration.duration - pauses.reduce(0, { $0 + $1.duration })
	}
	
	var dateAndDuration: DateAndDuration
	var pauses: [DateAndDuration]
	
	var totalDistance: CLLocationDistance
	
	var maxSpeed = CLLocationSpeed(0)
	var averageSpeed = CLLocationSpeed(0)
	
	var numberOfRecordedPoints = 0
//	var storedPointsCache = [CLLocation]()
	
}
