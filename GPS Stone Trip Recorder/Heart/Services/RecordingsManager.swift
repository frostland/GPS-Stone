/*
 * RecordingsManager.swift
 * GPS Stone Trip Recorder
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
	func unsafeAddPoint(location: CLLocation, addedDistance: CLLocationDistance, segmentID: Int16, to recording: Recording) -> RecordingPoint {
		assert(Thread.isMainThread)
		
		NSLog("Adding new location in recording %@: %@", recording.name ?? "<no name>", location)
		
		let recordingPoint = NSEntityDescription.insertNewObject(forEntityName: "RecordingPoint", into: dh.viewContext) as! RecordingPoint
		recordingPoint.date = location.timestamp
		recordingPoint.location = location
		recordingPoint.segmentID = segmentID
		
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
		
		guard let pause = recording.pauses?.sortedArray(using: [NSSortDescriptor(keyPath: \TimeSegment.startDate, ascending: true)]).last as! TimeSegment? else {
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
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/* *** Dependencies *** */
	
	private let dh: DataHandler
	
}
