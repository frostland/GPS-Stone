/*
 * LocationRecorder.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 2019/5/31.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import CoreLocation
import Foundation
import UIKit /* To get app and register to app fg/bg state */



/* Inherits from NSObject to allow KVO on the instances.
 * TODO: Switch to Combine! */
final class LocationRecorder : NSObject, CLLocationManagerDelegate {
	
	enum RecordingStatus : Codable {
		
		case stopped
		
		case paused(recordingRef: URL, segmentID: Int16)
		case recording(recordingRef: URL, segmentID: Int16)
		
		init(from decoder: Decoder) throws {
			assert(Thread.isMainThread)
			let container = try decoder.container(keyedBy: CodingKeys.self)
			let stateStr = try container.decode(String.self, forKey: .state)
			if stateStr == "stopped" {
				self = .stopped
				return
			}
			
			let segmentID = try container.decode(Int16.self, forKey: .segmentID)
			let recordingRef = try container.decode(URL.self, forKey: .recordingURI)
			switch stateStr {
				case "paused":    self = .paused(recordingRef: recordingRef, segmentID: segmentID)
				case "recording": self = .recording(recordingRef: recordingRef, segmentID: segmentID)
				default:
					throw NSError(domain: "fr.vso-software.GPSStoneTripRecorder", code: 1, userInfo: nil)
			}
		}
		
		func encode(to encoder: Encoder) throws {
			let stateStr: String
			switch self {
				case .stopped:   stateStr = "stopped"
				case .paused:    stateStr = "paused"
				case .recording: stateStr = "recording"
			}
			
			var container = encoder.container(keyedBy: CodingKeys.self)
			try container.encode(stateStr, forKey: .state)
			try container.encode(recordingRef, forKey: .recordingURI)
		}
		
		var recordingRefAndSegmentID: (recordingRef: URL, segmentID: Int16)? {
			switch self {
				case .stopped:
					return nil
				
				case .paused(let rr, let id), .recording(let rr, let id):
					return (rr, id)
			}
		}
		
		var recordingRef: URL? {
			return recordingRefAndSegmentID?.recordingRef
		}
		
		var segmentID: Int16? {
			return recordingRefAndSegmentID?.segmentID
		}
		
		var isRecording: Bool {
			switch self {
				case .recording:        return true
				case .paused, .stopped: return false
			}
		}
		
		var isPaused: Bool {
			switch self {
				case .paused:              return true
				case .recording, .stopped: return false
			}
		}
		
		var isStopped: Bool {
			switch self {
				case .stopped:            return true
				case .recording, .paused: return false
			}
		}
		
		private enum CodingKeys : String, CodingKey {
			case state
			case segmentID
			case recordingURI
		}
		
	}
	
	@objc class ObjC_RecordingStatusWrapper : NSObject {
		
		let value: RecordingStatus
		
		init(_ v: RecordingStatus) {
			value = v
			
			super.init()
		}
		
	}
	
	@objc dynamic var objc_recStatus: ObjC_RecordingStatusWrapper {
		return ObjC_RecordingStatusWrapper(recStatus)
	}
	private(set) var recStatus: RecordingStatus {
		willSet {
			willChangeValue(for: \.objc_recStatus)
		}
		didSet {
			/* MUST be done in didSet. Handling the status change can change the
			 * status! If we do that in willSet, the value set in the handling will
			 * be overridden. In the didSet block it is not.
			 * Swift Note: The didSet block is not called when the value is changed
			 *             from within the didSet block directly, but it is called
			 *             if the value is changed in a function that is called in
			 *             the didSet block! (Tested w/ Xcode 11.4.1)
			 *             Not sure this is the expected behaviour nor if it will
			 *             stay the same forever though… */
			handleStatusChange(from: oldValue, to: recStatus, saveInHistory: true)
			didChangeValue(for: \.objc_recStatus)
		}
	}
	
	@objc dynamic private(set) var canRecord: Bool
	@objc dynamic private(set) var currentHeading: CLHeading?
	@objc dynamic private(set) var currentLocation: CLLocation?
	
	init(locationManager: CLLocationManager, recordingsManager: RecordingsManager, dataHandler: DataHandler, appSettings: AppSettings, constants: Constants) {
		assert(Thread.isMainThread)
		
		c = constants
		s = appSettings
		dh = dataHandler
		lm = locationManager
		rm = recordingsManager
		canRecord = Set<CLAuthorizationStatus>(arrayLiteral: .notDetermined, .authorizedWhenInUse, .authorizedAlways).contains(CLLocationManager.authorizationStatus())
		recStatusesHistory = (try? PropertyListDecoder().decode([RecordingStatusHistoryEntry].self, from: Data(contentsOf: constants.urlToCurrentRecordingInfo))) ?? []
		recStatus = recStatusesHistory.last?.status ?? .stopped
		
		super.init()
		
		#warning("TODO: Set pausesLocationUpdatesAutomatically to true")
		#warning("TODO: Use allowDeferredLocationUpdatesUntilTraveled:timeout:")
		#warning("TODO: Monitor the AppSettings for changes on the minPathDistance property")
		lm.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
		lm.distanceFilter = appSettings.minPathDistance
		lm.activityType = .fitness
		lm.delegate = self
		/* KVO on \.applicationState does not work, so we observe the app notifications instead. */
		notificationObservers.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: OperationQueue.main, using: { [weak self] _ in self?.applyGPSRestrictionsToStatus() }))
		notificationObservers.append(NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: OperationQueue.main, using: { [weak self] _ in self?.applyGPSRestrictionsToStatus() }))
		notificationObservers.append(NotificationCenter.default.addObserver(forName: UIApplication.backgroundRefreshStatusDidChangeNotification, object: nil, queue: OperationQueue.main, using: { [weak self] _ in self?.applyGPSRestrictionsToStatus() }))
		
		/* The method below calls applyGPSRestrictionsToStatus() */
		handleStatusChange(from: .stopped, to: recStatus, saveInHistory: false) /* willSet/didSet not called from init */
	}
	
	deinit {
		for o in notificationObservers {
			NotificationCenter.default.removeObserver(o)
		}
	}
	
	/** Tell the location recorder a new client requires the user’s position.
	
	When you don’t need the position anymore, call `releaseTracking()` */
	func retainTracking() {
		numberOfClientsRequiringTracking += 1
		if numberOfClientsRequiringTracking == 1 {
			/* Nobody was requesting tracking, now someone does. */
			#warning("TODO")
		}
	}
	
	func releaseTracking() {
		numberOfClientsRequiringTracking -= 1
		if numberOfClientsRequiringTracking == 0 {
			/* Nobody needs the tracking anymore. */
			#warning("TODO")
		}
	}
	
	/** Starts a new recording.
	
	This method is only valid to call while the location recorder is **stopped**
	(it does not have a current recording). Will crash in debug mode (assert
	active) if called while the recording is recording. */
	func startNewRecording() throws {
		assert(Thread.isMainThread)
		assert(recStatus.recordingRef == nil)
		guard recStatus.recordingRef == nil else {return}
		
		let (recording, _) = try rm.unsafeCreateNextRecording()
		recStatus = .recording(recordingRef: rm.recordingRef(from: recording.objectID), segmentID: 0)
		guard let wCache = cachedRecordingWriteObjects else {return} /* If there was an error creating the output file or other, the cache might be `nil`. */
		assert(wCache.recording === recording)
		
		/* Writing the GPX header to the GPX file */
		do {
			if #available(iOS 13.0, *) {
				try wCache.fileHandle?.write(contentsOf: wCache.gpx.xmlOutput(forTagOpening: 0))
				try wCache.fileHandle?.write(contentsOf: wCache.gpx.firstTrack()!.xmlOutput(forTagOpening: 1))
				try wCache.fileHandle?.write(contentsOf: wCache.gpx.firstTrack()!.lastTrackSegment()!.xmlOutput(forTagOpening: 2))
			} else {
				var error: Error?
				objc_try({
					wCache.fileHandle?.write(wCache.gpx.xmlOutput(forTagOpening: 0))
					wCache.fileHandle?.write(wCache.gpx.firstTrack()!.xmlOutput(forTagOpening: 1))
					wCache.fileHandle?.write(wCache.gpx.firstTrack()!.lastTrackSegment()!.xmlOutput(forTagOpening: 2))
				}, { exception in
					error = NSError(domain: "fr.vso-software.GPSStoneTripRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot write to GPX output file."])
				})
				if let e = error {throw e}
			}
		} catch {
			recording.gpxFileBookmark = nil
			do    {try dh.saveContextOrRollback()}
			catch {recStatus = .stopped}
		}
	}
	
	/** Pauses the current recording.
	
	This method is only valid to call while the location recorder is **not**
	stopped (it has a current recording). Will crash in debug mode (assert
	active) if called at an invalid time. */
	func pauseCurrentRecording() {
		assert(Thread.isMainThread)
		assert(recStatus.recordingRef != nil)
		guard let rrAndSID = recStatus.recordingRefAndSegmentID else {return}
		
		recStatus = .paused(recordingRef: rrAndSID.recordingRef, segmentID: rrAndSID.segmentID)
		
		/* Let’s add the end of the segment to the GPX */
		if let wCache = try? recordingWriteObjects(for: rrAndSID.recordingRef) {
			do {
				if #available(iOS 13.0, *) {
					try wCache.fileHandle?.write(contentsOf: wCache.gpx.firstTrack()!.lastTrackSegment()!.xmlOutput(forTagClosing: 2))
				} else {
					var error: Error?
					objc_try({
						wCache.fileHandle?.write(wCache.gpx.firstTrack()!.lastTrackSegment()!.xmlOutput(forTagClosing: 2))
					}, { exception in
						error = NSError(domain: "fr.vso-software.GPSStoneTripRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot write to GPX output file."])
					})
					if let e = error {throw e}
				}
			} catch {
				wCache.recording.gpxFileBookmark = nil
				do    {try dh.saveContextOrRollback()}
				catch {recStatus = .stopped}
			}
		}
	}
	
	/** Resumes the current recording.
	
	This method is only valid to call while the location recorder is **paused by
	the user**. Will crash in debug mode (assert active) if called at an invalid
	time. */
	func resumeCurrentRecording() {
		assert(Thread.isMainThread)
		guard case .paused(let rr, var sid) = recStatus else {
			assertionFailure()
			return
		}
		
		sid += 1
		recStatus = .recording(recordingRef: rr, segmentID: sid)
		
		/* Let’s add the start of the new segment to the GPX */
		if let wCache = try? recordingWriteObjects(for: rr) {
			do {
				if #available(iOS 13.0, *) {
					try wCache.fileHandle?.write(contentsOf: wCache.gpx.firstTrack()!.lastTrackSegment()!.xmlOutput(forTagOpening: 2))
				} else {
					var error: Error?
					objc_try({
						wCache.fileHandle?.write(wCache.gpx.firstTrack()!.lastTrackSegment()!.xmlOutput(forTagOpening: 2))
					}, { exception in
						error = NSError(domain: "fr.vso-software.GPSStoneTripRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot write to GPX output file."])
					})
					if let e = error {throw e}
				}
			} catch {
				wCache.recording.gpxFileBookmark = nil
				do    {try dh.saveContextOrRollback()}
				catch {recStatus = .stopped}
			}
		}
	}
	
	/** Stops the current recording.
	
	This method is only valid to call while the location recorder is **not**
	stopped (it has a current recording). Will crash if called at an invalid time */
	func stopCurrentRecording() throws -> Recording {
		assert(Thread.isMainThread)
		
		let r = try recordingWriteObjects(for: recStatus.recordingRef!)
		r.recording.endDate = Date()
		try dh.saveContextOrRollback()
		
		/* Let’s save the end of the GPX */
		if let wCache = try? recordingWriteObjects(for: recStatus.recordingRef!) {
			do {
				if #available(iOS 13.0, *) {
					try wCache.fileHandle?.write(contentsOf: wCache.gpx.firstTrack()!.lastTrackSegment()!.xmlOutput(forTagClosing: 2))
					try wCache.fileHandle?.write(contentsOf: wCache.gpx.firstTrack()!.xmlOutput(forTagClosing: 1))
					try wCache.fileHandle?.write(contentsOf: wCache.gpx.xmlOutput(forTagClosing: 0))
				} else {
					var error: Error?
					objc_try({
						wCache.fileHandle?.write(wCache.gpx.firstTrack()!.lastTrackSegment()!.xmlOutput(forTagClosing: 2))
						wCache.fileHandle?.write(wCache.gpx.firstTrack()!.xmlOutput(forTagClosing: 1))
						wCache.fileHandle?.write(wCache.gpx.xmlOutput(forTagClosing: 0))
					}, { exception in
						error = NSError(domain: "fr.vso-software.GPSStoneTripRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot write to GPX output file."])
					})
					if let e = error {throw e}
				}
			} catch {
				wCache.recording.gpxFileBookmark = nil
				try dh.saveContextOrRollback()
			}
		}
		
		recStatus = .stopped
		return r.recording
	}
	
	/* *********************************
	   MARK: - Location Manager Delegate
	   ********************************* */
	
	func locationManager(_ manager: CLLocationManager, didChangeAuthorization authStatus: CLAuthorizationStatus) {
		assert(Thread.isMainThread)
		canRecord = Set<CLAuthorizationStatus>(arrayLiteral: .notDetermined, .authorizedWhenInUse, .authorizedAlways).contains(authStatus)
		applyGPSRestrictionsToStatus()
	}
	
	func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
		NSLog("%@", "Location manager error \(error)")
		currentLocation = nil
	}
	
	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		assert(Thread.isMainThread)
		
		NSLog("%@", "Received new locations \(locations)")
		handleNewLocations(locations)
	}
	
	func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
		assert(Thread.isMainThread)
		
		if newHeading.headingAccuracy.sign == .plus {currentHeading = newHeading}
		else                                        {currentHeading = nil}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/** Contains a reference to the resolved CoreData Recording object, and the
	FileHandle and the GPXpgxType object to write the GPX to. */
	private struct RecordingWriteObjects {
		
		let recordingRef: URL
		
		let recording: Recording
		
		/* These are only used to update the GPX file cache. We could probably
		 * skip those completely and say we only create the GPX file when the trip
		 * is exported. */
		let gpx: GPXgpxType
		/* If `nil`, the recording did not have a GPX bookmark. If the recording
		 * does have a bookmark, the FileHandle will never be `nil`. */
		let fileHandle: FileHandle?
		
		init(recordingRef rr: URL, recordingsManager: RecordingsManager) throws {
			assert(Thread.isMainThread)
			recordingRef = rr
			
			guard let r = recordingsManager.unsafeRecording(from: rr) else {
				throw NSError(domain: "fr.vso-software.GPSStoneTripRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot retrieve the given recording when instantiating a RecordingWriteObjects."])
			}
			
			recording = r
			
			/* We create a new GPX object whether there was a file already present
			 * (e.g. the app quit/relaunched while a recording was in progress).The
			 * object is only used for its conveniences to write GPX XML. */
			gpx = GPXgpxType(
				attributes: [
					"version": "1.1",
					"creator": NSLocalizedString("gpx creator tag", comment: "The text that will appear in the “creator” attribute of the exported GPX files.")
				],
				elementName: "gpx"
			)
			gpx.addTrack()
			gpx.firstTrack()!.addTrackSegment()
			
			if let bookmark = r.gpxFileBookmark {
				guard let gpxURL = recordingsManager.gpxURL(from: bookmark) else {
					throw NSError(domain: "fr.vso-software.GPSStoneTripRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot retrieve the given recording’s GPX URL when instantiating a RecordingWriteObjects."])
				}
				let fh = try FileHandle(forWritingTo: gpxURL)
				if #available(iOS 13.0, *) {
					try fh.seekToEnd()
				} else {
					var error: Error?
					objc_try({
						fh.seekToEndOfFile()
					}, { exception in
						error = NSError(domain: "fr.vso-software.GPSStoneTripRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot seek to end of output file."])
					})
					if let e = error {throw e}
				}
				fileHandle = fh
			} else {
				fileHandle = nil
			}
		}
		
	}
	
	private struct RecordingStatusHistoryEntry : Codable {
		
		var date: Date
		var status: RecordingStatus
		
	}
	
	private var notificationObservers = [NSObjectProtocol]()
	
	/** The history of recording statuses w/ the date of change.
	
	We need this because we can receive delayed location events, so we need to
	know what _was_ our recording status at the event date. */
	private var recStatusesHistory: [RecordingStatusHistoryEntry]
	
	private var cachedRecordingWriteObjects: RecordingWriteObjects?
	
	/** The locations that couldn’t be saved, with the save error. */
	#warning("TODO: Do something with those? For now they’re just saved here, doing nothing, being erased when theh app is terminated…")
	private var saveFailedLocations = [(location: CLLocation, error: Error)]()
	
	/* *** Dependencies *** */
	
	private let c: Constants
	private let s: AppSettings
	private let dh: DataHandler
	private let lm: CLLocationManager
	private let rm: RecordingsManager
	
	private var numberOfClientsRequiringTracking = 0
	
	/** Returns the recording status at the given date.
	
	If there is no recording status for the given date (the date is anterior to
	the first date we have in the statuses history), the function returns
	`.stopped`. */
	private func recStatus(at date: Date) -> RecordingStatus {
		assert(Thread.isMainThread)
		
		/* We assume recStatusesHistory is correctly ordered by date ascending. */
		return recStatusesHistory.reversed().first{
			let testedDate = $0.date
			return testedDate < date
		}?.status ?? .stopped
	}
	
	private func recordingWriteObjects(for recordingRef: URL) throws -> RecordingWriteObjects {
		assert(Thread.isMainThread)
		
		if let cachedObjects = cachedRecordingWriteObjects, cachedObjects.recordingRef == recordingRef {
			return cachedObjects
		}
		
		let writeObjects = try RecordingWriteObjects(recordingRef: recordingRef, recordingsManager: rm)
		cachedRecordingWriteObjects = writeObjects
		return writeObjects
	}
	
	private func handleNewLocations(_ locations: [CLLocation]) {
		assert(Thread.isMainThread)
		
		for newLocation in locations {
			guard !s.skipNonAccuratePoints || newLocation.horizontalAccuracy > c.maxAccuracyToRecordPoint else {return}
			
			let checkedRecStatus = recStatus(at: newLocation.timestamp)
			guard case .recording(let recordingRef, let segmentID) = checkedRecStatus else {return}
			
			do {
				let writeObjects = try recordingWriteObjects(for: recordingRef)
				
				let distance: CLLocationDistance
				if let latestRecordedPoint = writeObjects.recording.points?.lastObject as! RecordingPoint?, let latestPointDate = latestRecordedPoint.date, let latestPointLocation = latestRecordedPoint.location {
					guard -latestPointDate.timeIntervalSinceNow >= s.minTimeForUpdate else {return}
					distance = newLocation.distance(from: latestPointLocation)
					guard distance >= s.minPathDistance else {return}
				} else {
					distance = 0
				}
				
				rm.unsafeAddPoint(location: newLocation, addedDistance: distance, segmentID: segmentID, to: writeObjects.recording)
				
				writeObjects.gpx.firstTrack()!.lastTrackSegment()!.addTrackPoint(
					withCoords: newLocation.coordinate,
					hPrecision: newLocation.horizontalAccuracy,
					elevation: newLocation.altitude,
					vPrecision: newLocation.verticalAccuracy,
					heading: newLocation.course,
					date: newLocation.timestamp
				)
				do {
					if #available(iOS 13.0, *) {
						try writeObjects.fileHandle?.write(contentsOf: writeObjects.gpx.firstTrack()!.lastTrackSegment()!.lastTrackPoint()!.xmlOutput(3))
					} else {
						var error: Error?
						objc_try({
							writeObjects.fileHandle?.write(writeObjects.gpx.firstTrack()!.lastTrackSegment()!.lastTrackPoint()!.xmlOutput(3))
						}, { exception in
							error = NSError(domain: "fr.vso-software.GPSStoneTripRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot write to output file."])
						})
						if let e = error {throw e}
					}
				} catch {
					writeObjects.recording.gpxFileBookmark = nil
				}
			} catch {
				/* Adding the location to the list of locations that couldn’t be
				 * saved… */
				saveFailedLocations.append((location: newLocation, error: error))
			}
		}
		do {
			try dh.saveContextOrRollback()
		} catch {
			/* Adding ALL the locations to the list of locations that couldn’t be
			 * saved… */
			saveFailedLocations.append(contentsOf: locations.map{ (location: $0, error: error) })
		}
		
		if locations.last?.horizontalAccuracy.sign == .plus {currentLocation = locations.last}
		else                                                {currentLocation = nil}
	}
	
	private func handleStatusChange(from oldStatus: RecordingStatus, to newStatus: RecordingStatus, saveInHistory: Bool) {
		assert(Thread.isMainThread)
		NSLog("%@", "Status change from \(oldStatus) to \(newStatus)")
		
		/* Let’s save the current status */
		if saveInHistory {
			recStatusesHistory.append(RecordingStatusHistoryEntry(date: Date(), status: newStatus))
			_ = try? PropertyListEncoder().encode(recStatusesHistory).write(to: c.urlToCurrentRecordingInfo)
		}
		
		if oldStatus.recordingRef == nil, let newRecordingRef = newStatus.recordingRef {
			cachedRecordingWriteObjects = try? RecordingWriteObjects(recordingRef: newRecordingRef, recordingsManager: rm)
			guard cachedRecordingWriteObjects != nil else {
				recStatus = .stopped
				return
			}
		} else if oldStatus.recordingRef != nil && newStatus.recordingRef == nil {
			cachedRecordingWriteObjects = nil
		}
		
		#warning("TODO: Not recording but location should be tracked anyway")
		if newStatus.isRecording {
			if newStatus.isRecording {lm.requestAlwaysAuthorization()}
			else                     {lm.requestWhenInUseAuthorization()}
		}
		if newStatus.isRecording && !oldStatus.isRecording {
			lm.startUpdatingLocation()
			lm.startUpdatingHeading()
			if newStatus.isRecording && !oldStatus.isRecording {
				/* This should launch the app when it gets a significant location
				 * changes even if the user has force quit it. It should. */
				lm.startMonitoringSignificantLocationChanges()
			}
		} else if !newStatus.isRecording && oldStatus.isRecording {
			lm.stopUpdatingHeading()
			lm.stopUpdatingLocation()
			if !newStatus.isRecording && oldStatus.isRecording {
				lm.stopMonitoringSignificantLocationChanges()
			}
		}
		if #available(iOS 9.0, *) {lm.allowsBackgroundLocationUpdates = newStatus.isRecording}
		
		applyGPSRestrictionsToStatus()
	}
	
	private func applyGPSRestrictionsToStatus() {
		guard recStatus.isRecording else {return}
		
		/* We do not use the background refresh status because I don’t know yet
		 * how it can modify the bg behaviour of receiving the events.
		
		 * From https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/LocationAwarenessPG/CoreLocation/CoreLocation.html#//apple_ref/doc/uid/TP40009497-CH2-SW11
		 *    Note: When a user disables the Background App Refresh setting either
		 *          globally or for your app, the significant-change location
		 *          service doesn’t relaunch your app. Further, while Background
		 *          App Refresh is off an app doesn’t receive significant-change
		 *          or region monitoring events even when it's in the foreground.
		 *    Important: A user can explicitly disable background capabilities for
		 *               any app. If a user disables Background App Refresh in the
		 *               Settings app—either globally for all apps or for your app
		 *               in particular—your app is prevented from using any
		 *               location services in the background. You can determine
		 *               whether your app can process location updates in the
		 *               background by checking the value of the
		 *               backgroundRefreshStatus property of the UIApplication
		 *               class. */
		#warning("TODO. This will probably change a “locationWarning” property clients will be able to monitor to get a sense on whether the recording will work correctly and be able to warn the user accordingly.")
//		switch (CLLocationManager.authorizationStatus(), UIApplication.shared.applicationState, UIApplication.shared.backgroundRefreshStatus) {
//			case (.notDetermined, _, _), (.restricted, _, _), (.denied, _, _), (.authorizedWhenInUse, .background, _):
//				/* Note: In the restricted case, the user won’t be able to activate
//				 * the location services. */
//				guard !status.isPausedByLocationDenied else {return}
//				status = .pausedByLocationDenied(recordingRef: rr)
//
//			case (.authorizedAlways, _, _), (.authorizedWhenInUse, .active, _), (.authorizedWhenInUse, .inactive, _):
//				guard !status.isRecording else {return}
//				status = .recording(recordingRef: rr)
//
//			@unknown default:
//				/* We’ll assume we’re recording 🤷‍♂️ */
//				guard !status.isRecording else {return}
//				status = .recording(recordingRef: rr)
//		}
	}
	
}
