/*
 * Recording+Utils.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 2019/7/29.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import CoreData
import Foundation



extension Recording {
	
	var numberOfRecordedPoints: Int {
		return points?.count ?? 0
	}
	
	/**
	The total time of the recording (including the pauses). */
	var recordingDuration: TimeInterval {
		guard let totalTimeSegment = totalTimeSegment else {
			NSLog("***** ERROR - Got an invalid recording (nil totalTimeSegment): %@", self)
			return 0
		}
		return totalTimeSegment.effectiveDuration
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
			return current - pauseTimeSegment.effectiveDuration
		})
		/* Let’s still verify we have a positive duration! */
		guard totalTimeMinusPauses >= 0 else {
			NSLog("***** ERROR - Total time minus pauses time is negative in recording %@", self)
			return 0
		}
		return totalTimeMinusPauses
	}
	
	func latestPointInTime() throws -> RecordingPoint? {
		guard let context = managedObjectContext else {
			return nil
		}
		
		if #available(iOS 11.0, *) {
			let _ = "warning on iOS 11"
//			NSLog("%@", "The index is configured with an ascending index for the recording point date. We can set it descending (as it should be) starting w/ iOS 11, not before.")
		}
		let fetchRequest: NSFetchRequest<RecordingPoint> = RecordingPoint.fetchRequest()
		fetchRequest.fetchLimit = 1
		fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(RecordingPoint.recording), self)
		fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RecordingPoint.date, ascending: false)]
		return try context.fetch(fetchRequest).first
	}
	
	func latestPoint(before date: Date) throws -> RecordingPoint? {
		guard let context = managedObjectContext else {
			return nil
		}
		
		/* First we check the latest point in time. Currently the “latest point”
		 * method does pretty much the same as what we do after this if, but
		 * someday it might get optimized… */
		if let p = try latestPointInTime() {
			if let d = p.date, d < date {
				/* The latest recorded point has a date which is lower than the
				 * required date: this is the point we want! */
				return p
			}
		}
		
		let fetchRequest: NSFetchRequest<RecordingPoint> = RecordingPoint.fetchRequest()
		fetchRequest.fetchLimit = 1
		fetchRequest.predicate = NSPredicate(format: "%K == %@ && %K < %@", #keyPath(RecordingPoint.recording), self, #keyPath(RecordingPoint.date), date as NSDate)
		fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RecordingPoint.date, ascending: false)]
		return try context.fetch(fetchRequest).first
	}
	
}
