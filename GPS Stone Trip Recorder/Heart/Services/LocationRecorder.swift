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
	
	enum Status : Codable {
		
		case stopped
		case stoppedAndTracking
		case recording(recordingRef: URL)
		case pausedByUser(recordingRef: URL)
		case pausedByBackground(recordingRef: URL)
		#warning("TODO: Case below")
		case pausedByLocationError(recordingRef: URL)
		case pausedByLocationDenied(recordingRef: URL)
		
		init(from decoder: Decoder) throws {
			assert(Thread.isMainThread)
			let container = try decoder.container(keyedBy: CodingKeys.self)
			let stateStr = try container.decode(String.self, forKey: .state)
			if stateStr == "stopped" {
				self = .stopped
				return
			}
			
			let recordingRef = try container.decode(URL.self, forKey: .recordingURI)
			switch stateStr {
				case "recording":              self = .recording(recordingRef: recordingRef)
				case "pausedByUser":           self = .pausedByUser(recordingRef: recordingRef)
				case "pausedByBackground":     self = .pausedByBackground(recordingRef: recordingRef)
				case "pausedByLocationDenied": self = .pausedByLocationDenied(recordingRef: recordingRef)
				default:
					throw NSError(domain: "fr.vso-software.GPSStoneTripRecorder", code: 1, userInfo: nil)
			}
		}
		
		func encode(to encoder: Encoder) throws {
			let stateStr: String
			switch self {
				case .stopped, .stoppedAndTracking: stateStr = "stopped"
				case .recording:                    stateStr = "recording"
				case .pausedByUser:                 stateStr = "pausedByUser"
				case .pausedByBackground:           stateStr = "pausedByBackground"
				case .pausedByLocationError:        stateStr = "pausedByLocationError"
				case .pausedByLocationDenied:       stateStr = "pausedByLocationDenied"
			}
			
			var container = encoder.container(keyedBy: CodingKeys.self)
			try container.encode(stateStr, forKey: .state)
			try container.encode(recordingRef, forKey: .recordingURI)
		}
		
		var recordingRef: URL? {
			switch self {
				case .stopped, .stoppedAndTracking:
					return nil
					
				case .recording(let rr), .pausedByUser(let rr), .pausedByBackground(let rr), .pausedByLocationError(let rr), .pausedByLocationDenied(let rr):
					return rr
			}
		}
		
		var isTrackingUserPosition: Bool {
			switch self {
				case .stopped:                                                                                                             return false
				case .stoppedAndTracking, .recording, .pausedByUser, .pausedByBackground, .pausedByLocationError, .pausedByLocationDenied: return true
			}
		}
		
		var isRecording: Bool {
			switch self {
				case .stopped,  .stoppedAndTracking:                                                                  return false
				case .recording, .pausedByUser, .pausedByBackground, .pausedByLocationError, .pausedByLocationDenied: return true
			}
		}
		
//		var isWaitingForGPS: Bool {
//			#warning("Potential access of CoreData object outside of context queue")
//			guard case let .recording(recording) = self else {return false}
//			return (recording.points?.count ?? 0) == 0
//		}
		
		private enum CodingKeys : String, CodingKey {
			case state
			case recordingURI
		}
		
	}
	
	@objc class ObjC_StatusWrapper : NSObject {
		
		let value: Status
		
		init(_ v: Status) {
			value = v
			
			super.init()
		}
		
	}
	
	@objc dynamic var objc_status: ObjC_StatusWrapper {
		return ObjC_StatusWrapper(status)
	}
	private(set) var status: Status {
		willSet {
			willChangeValue(for: \.objc_status)
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
			handleStatusChange(from: oldValue, to: status)
			didChangeValue(for: \.objc_status)
		}
	}
	
	@objc dynamic private(set) var canRecord: Bool
	@objc dynamic private(set) var currentHeading: CLHeading?
	@objc dynamic private(set) var currentLocation: CLLocation? {
		willSet {
			assert(Thread.isMainThread)
			guard let newLocation = newValue else {return}
			guard !s.skipNonAccuratePoints || newLocation.horizontalAccuracy > c.maxAccuracyToRecordPoint else {return}
			
			let distance: CLLocationDistance
			guard case .recording = status else {return}
			if let latestRecordedPoint = currentRecording.points?.lastObject as! RecordingPoint?, let pointDate = latestRecordedPoint.date, let pointLocation = latestRecordedPoint.location {
				guard -pointDate.timeIntervalSinceNow >= s.minTimeForUpdate else {return}
				distance = newLocation.distance(from: pointLocation)
				guard distance >= s.minPathDistance else {return}
			} else {
				distance = 0
			}
			
			try? rm.unsafeAddPoint(location: newLocation, addedDistance: distance, segmentId: currentSegmentId, to: currentRecording)
		}
	}
	
	init(locationManager: CLLocationManager, recordingsManager: RecordingsManager, dataHandler: DataHandler, appSettings: AppSettings, constants: Constants) {
		assert(Thread.isMainThread)
		
		c = constants
		s = appSettings
		dh = dataHandler
		lm = locationManager
		rm = recordingsManager
		status = (try? PropertyListDecoder().decode(Status.self, from: Data(contentsOf: constants.urlToCurrentRecordingInfo))) ?? .stopped
		canRecord = Set<CLAuthorizationStatus>(arrayLiteral: .notDetermined, .authorizedWhenInUse, .authorizedAlways).contains(CLLocationManager.authorizationStatus())
		
		super.init()
		
		lm.delegate = self
		/* KVO on \.applicationState does not work, so we observe the app notifications instead. */
		notificationObservers.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: OperationQueue.main, using: { [weak self] _ in self?.applyGPSRestrictionsToStatus() }))
		notificationObservers.append(NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: OperationQueue.main, using: { [weak self] _ in self?.applyGPSRestrictionsToStatus() }))
		notificationObservers.append(NotificationCenter.default.addObserver(forName: UIApplication.backgroundRefreshStatusDidChangeNotification, object: nil, queue: OperationQueue.main, using: { [weak self] _ in self?.applyGPSRestrictionsToStatus() }))

		/* The method below calls applyGPSRestrictionsToStatus() */
		handleStatusChange(from: .stopped, to: status) /* willSet/didSet not called from init */
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
			if case .stopped = status {
				status = .stoppedAndTracking
			}
		}
	}
	
	func releaseTracking() {
		numberOfClientsRequiringTracking -= 1
		if numberOfClientsRequiringTracking == 0 {
			/* Nobody needs the tracking anymore. */
			if case .stoppedAndTracking = status {
				status = .stopped
			}
		}
	}
	
	/** Starts a new recording.
	
	This method is only valid to call while the location recorder is **stopped**
	(it does not have a current recording). Will crash in debug mode (assert
	active) if called while the recording is recording. */
	func startNewRecording() throws {
		assert(Thread.isMainThread)
		assert(status.recordingRef == nil)
		guard status.recordingRef == nil else {return}
		
		currentSegmentId = 0
		
		let (recording, _) = try rm.unsafeCreateNextRecording()
		status = .recording(recordingRef: rm.recordingRef(from: recording.objectID))
		guard currentRecording != nil else {return} /* If there was an error creating the output file or other, the status can go back to stopped. */
		assert(currentRecording === recording)
		
		/* Writing the GPX header to the GPX file */
		currentGPXHandle.write(currentGPX.xmlOutput(forTagClosing: 0))
		currentGPXHandle.write(currentGPX.firstTrack()!.xmlOutput(forTagOpening: 1))
		currentGPXHandle.write(currentGPX.firstTrack()!.lastTrackSegment()!.xmlOutput(forTagOpening: 2))
	}
	
	/** Pauses the current recording.
	
	This method is only valid to call while the location recorder is **not**
	stopped (it has a current recording). Will crash in debug mode (assert
	active) if called at an invalid time. */
	func pauseCurrentRecording() {
		assert(Thread.isMainThread)
		assert(status.recordingRef != nil)
		guard let rr = status.recordingRef else {return}
		
		status = .pausedByUser(recordingRef: rr)
	}
	
	/** Resumes the current recording.
	
	This method is only valid to call while the location recorder is **paused by
	the user**. Will crash in debug mode (assert active) if called at an invalid
	time. */
	func resumeCurrentRecording() {
		assert(Thread.isMainThread)
		guard case .pausedByUser(let rr) = status else {
			assertionFailure()
			return
		}
		
		currentSegmentId += 1
		status = .recording(recordingRef: rr)
	}
	
	/** Stops the current recording.
	
	This method is only valid to call while the location recorder is **not**
	stopped (it has a current recording). Will crash if called at an invalid time */
	func stopCurrentRecording() throws -> Recording {
		assert(Thread.isMainThread)
		
		let r = currentRecording!
		r.endDate = Date()
		try dh.saveContextOrRollback()
		
		status = .stopped
		return r
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
		
		guard let location = locations.last else {return}
		if location.horizontalAccuracy.sign == .plus {currentLocation = location}
		else                                         {currentLocation = nil}
	}
	
	func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
		assert(Thread.isMainThread)
		
		if newHeading.headingAccuracy.sign == .plus {currentHeading = newHeading}
		else                                        {currentHeading = nil}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private var notificationObservers = [NSObjectProtocol]()
	
	/** The current Recording CoreData object. Must always be used only on the
	main thread.
	
	It is implicitly unwrapped! We have to be careful when we use it… Should
	always be non-nil while recording (the willSet of the status property makes
	sure of this). */
	private var currentRecording: Recording!
	
	/** The GPX element containing the recording path.
	
	It is implicitly unwrapped! We have to be careful when we use it… Should
	always be non-nil while recording (the willSet of the status property makes
	sure of this). */
	private var currentGPX: GPXgpxType!
	
	/** The handle on which to write to continue the GPX file.
	
	It is implicitly unwrapped! We have to be careful when we use it… Should
	always be non-nil while recording (the willSet of the status property makes
	sure of this). */
	private var currentGPXHandle: FileHandle!
	
	private var currentSegmentId: Int16 = 0
	
	/* *** Dependencies *** */
	
	private let c: Constants
	private let s: AppSettings
	private let dh: DataHandler
	private let lm: CLLocationManager
	private let rm: RecordingsManager
	
	private var numberOfClientsRequiringTracking = 0
	
	private func handleStatusChange(from oldStatus: Status, to newStatus: Status) {
		assert(Thread.isMainThread)
		NSLog("%@", "Status change from \(oldStatus) to \(newStatus)")
		if oldStatus.recordingRef == nil, let newRecordingRef = newStatus.recordingRef {
			assert(currentGPX == nil && currentGPXHandle == nil && currentRecording == nil)
			guard
				let r = rm.unsafeRecording(from: newRecordingRef),
				let bookmark = r.gpxFileBookmark,
				let gpxURL = rm.gpxURL(from: bookmark),
				let fh = try? FileHandle(forWritingTo: gpxURL)
			else {
				status = (numberOfClientsRequiringTracking > 0 ? .stoppedAndTracking : .stopped)
				return
			}
			
			/* Set the currentRecording for future uses (to avoid resolving the
			 * reference in the status at each use). */
			currentRecording = r
			
			/* We must create the GPX object! Note: If the GPX file already existed
			 * (e.g. the app quit/relaunched while a recording was in progress), we
			 * do not reload it; we simply create a new GPX object. The object is
			 * only used for its conveniences to write GPX XML. */
			currentGPX = GPXgpxType(
				attributes: [
					"version": "1.1",
					"creator": NSLocalizedString("gpx creator tag", comment: "The text that will appear in the “creator” attribute of the exported GPX files.")
				],
				elementName: "gpx"
			)
			currentGPX.addTrack()
			currentGPX.firstTrack()!.addTrackSegment()
			
			/* And the FileHandle to write the GPX to disk */
			currentGPXHandle = fh
			currentGPXHandle.seekToEndOfFile()
		} else if oldStatus.recordingRef != nil && newStatus.recordingRef == nil {
			currentGPX = nil
			currentGPXHandle = nil
			currentRecording = nil
		}
		
		if newStatus.isTrackingUserPosition {
			if newStatus.isRecording {lm.requestAlwaysAuthorization()}
			else                     {lm.requestWhenInUseAuthorization()}
		}
		if newStatus.isTrackingUserPosition && !oldStatus.isTrackingUserPosition {
			lm.startUpdatingLocation()
			lm.startUpdatingHeading()
		} else if !newStatus.isTrackingUserPosition && oldStatus.isTrackingUserPosition {
			lm.stopUpdatingHeading()
			lm.stopUpdatingLocation()
		}
		if #available(iOS 9.0, *) {lm.allowsBackgroundLocationUpdates = newStatus.isRecording}
		
		applyGPSRestrictionsToStatus()
	}
	
	private func applyGPSRestrictionsToStatus() {
//		assert(false, "todo")
		NSLog("%@", "GPS status: \(CLLocationManager.authorizationStatus().rawValue)")
		NSLog("%@", "application state: \(UIApplication.shared.applicationState.rawValue)")
		NSLog("%@", "background refresh status: \(UIApplication.shared.backgroundRefreshStatus.rawValue)")
	}
	
}
