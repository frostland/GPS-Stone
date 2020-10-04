/*
 * RecordingsManager.swift
 * GPS Stone
 *
 * Created by François Lamboley on 2019/6/8.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import CoreData
import CoreLocation
import Foundation



/* Inherits from NSObject to allow KVO on the instances.
 * TODO: Switch to Combine! */
final class RecordingsManager : NSObject {
	
	init(dataHandler: DataHandler) {
		dh = dataHandler
		
		super.init()
		
		do    {try checkForModelInconsistencies()}
		catch {NSLog("%@", "*** WARNING: Cannot check model for inconsistencies")}
	}
	
	/**
	Creates the next recording.
	
	Must be called on the dataHandler’s viewContext’s queue (the main thread). */
	func unsafeCreateNextRecordingAndSaveContext() throws -> Recording {
		assert(Thread.isMainThread)
		
		let s = NSEntityDescription.insertNewObject(forEntityName: "TimeSegment", into: dh.viewContext) as! TimeSegment
		s.startDate = Date()
		
		let r: Recording
		if #available(iOS 10.0, *) {r = Recording(context: dh.viewContext)}
		else                       {r = NSEntityDescription.insertNewObject(forEntityName: "Recording", into: dh.viewContext) as! Recording}
		r.name = NSLocalizedString("new recording", comment: "Default name for a recording")
		r.totalTimeSegment = s
		
		try dh.saveContextOrRollback()
		return r
	}
	
	/**
	Adds a point to the given recording. Does **NOT** save the context.
	
	Must be called on the dataHandler’s viewContext’s queue (the main thread). */
	@discardableResult
	func unsafeAddPoint(location: CLLocation, addedDistance: CLLocationDistance, heading: CLHeading?, segmentID: Int16, to recording: Recording) -> RecordingPoint {
		assert(Thread.isMainThread)
		
		NSLog("Adding new location in recording %@: %@", recording.name ?? "<no name>", location)
		
		let recordingPoint = NSEntityDescription.insertNewObject(forEntityName: "RecordingPoint", into: dh.viewContext) as! RecordingPoint
		recordingPoint.date = location.timestamp
		recordingPoint.location = location
		recordingPoint.segmentID = segmentID
		recordingPoint.heading = heading
		
//		recording.addToPoints(recordingPoint) /* Does not work on iOS 9, so we have to do the line below! */
		recording.mutableSetValue(forKey: #keyPath(Recording.points)).add(recordingPoint)
		recording.totalDistance += Float(addedDistance)
		recording.maxSpeed = max(Float(location.speed), recording.maxSpeed)
		
		return recordingPoint
	}
	
	/**
	Removes the given point from the given recording. Does **NOT** save the
	context.
	
	Will not revert the max speed to the previous max speed (we can’t really know
	it w/ our current model, but we don’t really care).
	
	Must be called on the dataHandler’s viewContext’s queue (the main thread). */
	func unsafeRemovePoint(point: RecordingPoint, removedDistance: CLLocationDistance, from recording: Recording) {
		assert(Thread.isMainThread)
		
		NSLog("Removing point in recording %@: %@", recording.name ?? "<no name>")
		
		dh.viewContext.delete(point)
		recording.totalDistance -= Float(removedDistance)
	}
	
	func unsafeFinishRecordingAndSaveContext(_ recording: Recording) throws {
		assert(Thread.isMainThread)
		
		if let ts = recording.totalTimeSegment {
			ts.closeTimeSegment()
		} else {
			NSLog("***** ERROR: Current recording does not have a totalTimeSegment; this should not be possible. We will add a total time segment with an arbitrary duration of 1s.")
			NSLog("*****        Recording: \(recording)")
			let ts = NSEntityDescription.insertNewObject(forEntityName: "TimeSegment", into: dh.viewContext) as! TimeSegment
			ts.startDate = Date(timeIntervalSinceNow: -1)
			ts.duration = NSNumber(value: 1)
			recording.totalTimeSegment = ts
		}
		if recording.activeRecordingDuration > 0 {
			recording.averageSpeed = recording.totalDistance/Float(recording.activeRecordingDuration)
		}
		try dh.saveContextOrRollback()
	}
	
	@discardableResult
	func unsafeAddPauseAndSaveContext(to recording: Recording) throws -> TimeSegment {
		assert(Thread.isMainThread)
		
		let pause = NSEntityDescription.insertNewObject(forEntityName: "TimeSegment", into: dh.viewContext) as! TimeSegment
		pause.startDate = Date()
		pause.pauseSegmentRecording = recording
		
		try dh.saveContextOrRollback()
		return pause
	}
	
	@discardableResult
	func unsafeFinishLatestPauseAndSaveContext(in recording: Recording) throws -> TimeSegment? {
		assert(Thread.isMainThread)
		
		guard let pause = recording.latestPauseInTime() else {
			NSLog("%@", "*** WARNING: Recording does not have a pause; cannot finish pausing the recording")
			return nil
		}
		guard pause.duration == nil else {
			NSLog("%@", "*** WARNING: Latest pause in time is already finished; cannot finish recording pause; leaving as-is")
			return pause
		}
		
		pause.closeTimeSegment()
		
		try dh.saveContextOrRollback()
		return pause
	}
	
	func recordingRef(from recordingID: NSManagedObjectID) -> URL {
		return recordingID.uriRepresentation()
	}
	
	/**
	Fetches the recording corresponding to the given ref.
	
	Must be called on the dataHandler’s viewContext’s queue (the main thread). */
	func unsafeRecording(from recordingRef: URL) -> Recording? {
		assert(Thread.isMainThread)
		
		guard let recordingID = dh.persistentStoreCoordinator.managedObjectID(forURIRepresentation: recordingRef) else {
			return nil
		}
		return try? dh.viewContext.existingObject(with: recordingID) as? Recording
	}
	
	/**
	Checks for inconsistencies in the model.
	
	The model can have some inconsistencies, due to crashes or code errors. This
	method will search for such inconsistencies and report them back.
	
	In details, the following will be checked:
	- All the recordings have a total time segment, and at most one of these time
	  segments is open;
	- All the recordings have valid pause segments (fit within the total time
	  segment, are closed (except for the recording that have an open time
	  segment if any), do not overlap);
	- All the points in a recording are within the total time segment, and not in
	  any pause time segment;
	- No points nor time segments are orphans;
	- All points have a valid date (same as the location’s timestamp) and a
	location. */
	func checkForModelInconsistencies() throws {
		var recordingWithOpenTimeSegment: Recording?
		for recording: Recording in try dh.viewContext.fetch(Recording.fetchRequest()) {
			guard let totalTimeSegment = recording.totalTimeSegment else {
				NSLog("%@", "Recording \(recording.objectID) does not have a total time segment.")
				continue
			}
			guard totalTimeSegment.startDate != nil else {
				NSLog("%@", "Recording \(recording.objectID) does not have a start date.")
				continue
			}
			if totalTimeSegment.isOpen {
				if let r = recordingWithOpenTimeSegment {
					NSLog("%@", "Recording \(r.objectID) and \(recording.objectID) both have open total time segments.")
				}
				recordingWithOpenTimeSegment = recording
			}
			
			var seenPauses = [TimeSegment]()
			for (pauseIndex, pause) in ((recording.pauses?.sortedArray(using: [NSSortDescriptor(keyPath: \TimeSegment.startDate, ascending: false)]) ?? []) as! [TimeSegment]).enumerated() {
				let isLatestPauseInTime = (pauseIndex == 0)
				if pause.isOpen && (!isLatestPauseInTime || !totalTimeSegment.isOpen) {
					NSLog("%@", "Recording \(recording.objectID) contains an open time segment pause \(pause.objectID) but this pause is not the latest, or the recording is finished.")
				}
				if !(totalTimeSegment.contains(pause) ?? false) {
					NSLog("%@", "Recording \(recording.objectID) contains pause \(pause.objectID) which is not contained in the total time segment (or either segment is invalid).")
				}
				for p in seenPauses {
					if pause.intersects(p) ?? true {
						NSLog("%@", "Recording \(recording.objectID) contains two pauses \(pause.objectID) and \(p.objectID) which intersect (or either are invalid).")
					}
				}
				seenPauses.append(pause)
			}
			for point in recording.points ?? [] {
				let point = point as! RecordingPoint
				guard let pointDate = point.date else {
					NSLog("%@", "Recording \(recording.objectID) contains a point \(point.objectID) which does not have a date.")
					continue
				}
				if !(totalTimeSegment.contains(pointDate) ?? false) {
					NSLog("%@", "Recording \(recording.objectID) contains a point whose date is not contained in the total time segment.")
				}
				for pause in recording.pauses ?? [] {
					let pause = pause as! TimeSegment
					if pause.contains(pointDate) ?? false {
						NSLog("%@", "Recording \(recording.objectID) contains a point whose date is in pause segment \(pause.objectID).")
					}
				}
			}
		}
		for point: RecordingPoint in try dh.viewContext.fetch(RecordingPoint.fetchRequest()) {
			if point.recording == nil {
				NSLog("%@", "Found orphan recording point \(point.objectID).")
			}
			if point.date == nil {
				NSLog("%@", "Found a recording point without a date: \(point.objectID).")
			}
			if point.location == nil {
				NSLog("%@", "Found a recording point without a location: \(point.objectID).")
			}
			if point.date != point.location?.timestamp {
				NSLog("%@", "Found a recording point whose date is not the same as its location’s timestamp \(point.objectID).")
			}
		}
		for timeSegment: TimeSegment in try dh.viewContext.fetch(TimeSegment.fetchRequest()) {
			if timeSegment.pauseSegmentRecording == nil && timeSegment.totalTimeSegmentRecording == nil {
				NSLog("%@", "Found orphan time segment \(timeSegment.objectID).")
			}
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/* *** Dependencies *** */
	
	private let dh: DataHandler
	
}
