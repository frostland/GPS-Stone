/*
 * RecordingsManager.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 2019/6/8.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import CoreData
import Foundation



/* Inherits from NSObject to allow KVO on the instances.
 * TODO: Switch to Combine! */
final class RecordingsManager : NSObject {
	
	init(dataHandler: DataHandler, constants: Constants) {
		c = constants
		dh = dataHandler
	}
	
	/** Creates the next recording.
	
	Must be called on the dataHandler’s viewContext’s queue (the main thread). */
	func unsafeCreateNextRecording() throws -> (Recording, URL) {
		assert(Thread.isMainThread)
		
		let gpxURL = createNextGPXFile()
		let bookmarkData = try gpxURL.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: c.urlToFolderWithGPXFiles)
		
		let s = NSEntityDescription.insertNewObject(forEntityName: "TimeSegment", into: dh.viewContext) as! TimeSegment
		s.startTime = Date()
		
		let r: Recording
		if #available(iOS 10.0, *) {r = Recording(context: dh.viewContext)}
		else                       {r = NSEntityDescription.insertNewObject(forEntityName: "Recording", into: dh.viewContext) as! Recording}
		r.name = NSLocalizedString("new recording", comment: "Default name for a recording")
		r.gpxFileBookmark = bookmarkData
		r.totalTimeSegment = s
		r.startDate = Date()
		try dh.saveContextOrRollback()
		return (r, gpxURL)
	}
	
	/** Adds a point to the given recording. Does **NOT** save the context.
	
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
		recording.mutableOrderedSetValue(forKey: #keyPath(Recording.points)).add(recordingPoint)
		recording.totalDistance += Float(addedDistance)
		recording.maxSpeed = max(Float(location.speed), recording.maxSpeed)
		
		return recordingPoint
	}
	
	/** Removes the given point from the given recording. Does **NOT** save the
	context. Will not revert the max speed to the previous max speed (we can’t
	really know it, can we?)
	
	Must be called on the dataHandler’s viewContext’s queue (the main thread). */
	func unsafeRemovePoint(point: RecordingPoint, removedDistance: CLLocationDistance, from recording: Recording) {
		assert(Thread.isMainThread)
		
		NSLog("Removing point in recording %@: %@", recording.name ?? "<no name>")
		
		dh.viewContext.delete(point)
		recording.totalDistance -= Float(removedDistance)
	}
	
	func recordingRef(from recordingID: NSManagedObjectID) -> URL {
		return recordingID.uriRepresentation()
	}
	
	/** Fetches the recording corresponding to the given ref.
	
	Must be called on the dataHandler’s viewContext’s queue (the main thread). */
	func unsafeRecording(from recordingRef: URL) -> Recording? {
		assert(Thread.isMainThread)
		
		guard let recordingID = dh.persistentStoreCoordinator.managedObjectID(forURIRepresentation: recordingRef) else {
			return nil
		}
		return try? dh.viewContext.existingObject(with: recordingID) as? Recording
	}
	
	func gpxURL(from bookmarkData: Data) -> URL? {
		return try? NSURL(resolvingBookmarkData: bookmarkData, options: [.withoutUI], relativeTo: c.urlToFolderWithGPXFiles, bookmarkDataIsStale: nil) as URL?
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/* *** Dependencies *** */
	
	private let c: Constants
	private let dh: DataHandler
	
	private func createNextGPXFile() -> URL {
		let fm = FileManager.default
		
		let url = (1...).lazy.map{ self.c.urlToGPX(number: $0) }.first{ !fm.fileExists(atPath: $0.path) }!
		/* TODO: This is bad, to just assume the file creation will work… */
		_ = fm.createFile(atPath: url.path, contents: nil, attributes: nil)
		return url
	}
	
}
