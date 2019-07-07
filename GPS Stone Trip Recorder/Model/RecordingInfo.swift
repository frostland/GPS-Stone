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
	var firstRecordedPoint: RecordingPoint?
	var latestRecordedPoint: RecordingPoint?
	var allPoints = [RecordingPoint]()
	
}

struct RecordingPoint : Codable {
	
	let location: CLLocation
	let date: Date
	
	init(location l: CLLocation, date d: Date = Date()) {
		location = l
		date = d
	}
	
	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		let data = try container.decode(Data.self)
		
		let unarchiver = NSKeyedUnarchiver(forReadingWith: data)
		defer {unarchiver.finishDecoding()}
		guard let loc = unarchiver.decodeObject(forKey: "location") as? CLLocation else {
			throw NSError(domain: "fr.frostland.GPS-Stone", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot decode location"])
		}
		guard let d = unarchiver.decodeObject(forKey: "date") as? Date else {
			throw NSError(domain: "fr.frostland.GPS-Stone", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot decode date"])
		}
		
		location = loc
		date = d
	}
	
	func encode(to encoder: Encoder) throws {
		let data = NSMutableData()
		do {
			let archiver = NSKeyedArchiver(forWritingWith: data)
			defer {archiver.finishEncoding()}
			archiver.encode(location, forKey: "location")
			archiver.encode(date, forKey: "date")
		}
		
		var container = encoder.singleValueContainer()
		try container.encode(Data(data))
	}
	
}
