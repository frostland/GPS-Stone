/*
 * LocationRecorder.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 2019/5/31.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import CoreLocation
import Foundation



/* Inherits from NSObject to allow KVO on the instances.
 * TODO: Switch to Combine! */
class LocationRecorder : NSObject, CLLocationManagerDelegate {
	
	enum Status : Codable {
		
		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			let stateStr = try container.decode(String.self, forKey: .state)
			if stateStr == "stopped" {
				self = .stopped
				return
			}
			
			let recordingInfo = try container.decode(RecordingInfo.self, forKey: .recordingInfo)
			switch stateStr {
			case "recording":              self = .recording(recordingInfo)
			case "pausedByUser":           self = .pausedByUser(recordingInfo)
			case "pausedByBackground":     self = .pausedByBackground(recordingInfo)
			case "pausedByLocationDenied": self = .pausedByLocationDenied(recordingInfo)
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
			case .pausedByLocationDenied:       stateStr = "pausedByLocationDenied"
			}
			
			var container = encoder.container(keyedBy: CodingKeys.self)
			try container.encode(stateStr, forKey: .state)
			try container.encode(recordingInfo, forKey: .recordingInfo)
		}
		
		case stopped
		case stoppedAndTracking
		case recording(RecordingInfo)
		case pausedByUser(RecordingInfo)
		case pausedByBackground(RecordingInfo)
		case pausedByLocationDenied(RecordingInfo)
		
		var recordingInfo: RecordingInfo? {
			switch self {
			case .stopped, .stoppedAndTracking:
				return nil
				
			case .recording(let ri), .pausedByUser(let ri), .pausedByBackground(let ri), .pausedByLocationDenied(let ri):
				return ri
			}
		}
		
		var isTrackingUserPosition: Bool {
			switch self {
			case .stopped:                                                                                     return false
			case .stoppedAndTracking, .recording, .pausedByUser, .pausedByBackground, .pausedByLocationDenied: return true
			}
		}
		
		var isRecording: Bool {
			switch self {
			case .stopped,  .stoppedAndTracking:                                          return false
			case .recording, .pausedByUser, .pausedByBackground, .pausedByLocationDenied: return true
			}
		}
		
		private enum CodingKeys : String, CodingKey {
			case state
			case recordingInfo
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
			handleStatusChange(from: status, to: newValue)
		}
		didSet {
			didChangeValue(for: \.objc_status)
		}
	}
	
	@objc dynamic private(set) var canRecord: Bool
	@objc dynamic private(set) var currentHeading: CLHeading?
	@objc dynamic private(set) var currentLocation: CLLocation?
	
	init(locationManager: CLLocationManager, recordingsManager: RecordingsManager, constants: Constants) {
		lm = locationManager
		rm = recordingsManager
		status = (try? PropertyListDecoder().decode(Status.self, from: Data(contentsOf: constants.urlToCurrentRecordingInfo))) ?? .stopped
		canRecord = Set<CLAuthorizationStatus>(arrayLiteral: .notDetermined, .authorizedWhenInUse, .authorizedAlways).contains(CLLocationManager.authorizationStatus())
		
		super.init()
		
		lm.delegate = self
		handleStatusChange(from: .stopped, to: status) /* willSet/didSet not called from init */
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
	func startNewRecording() {
		assert(status.recordingInfo == nil)
		guard status.recordingInfo == nil else {return}
		
		let recording = RecordingInfo(gpxURL: rm.createNextGPXFile(), name: "Untitled" /* The end user should not see this string, so it’s not localized */)
		status = .recording(recording)
		
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
		assert(status.recordingInfo != nil)
		guard let r = status.recordingInfo else {return}
		
		#warning("TODO: Pause the recording...")
		
		status = .pausedByUser(r)
	}
	
	/** Resumes the current recording.
	
	This method is only valid to call while the location recorder is **paused by
	the user**. Will crash in debug mode (assert active) if called at an invalid
	time. */
	func resumeCurrentRecording() {
		guard case .pausedByUser(let r) = status else {
			assertionFailure()
			return
		}
		
		#warning("TODO: Resume the recording...")
		
		status = .recording(r)
	}
	
	/** Stops the current recording.
	
	This method is only valid to call while the location recorder is **not**
	stopped (it has a current recording). Will crash in debug mode (assert
	active) if called at an invalid time. */
	func stopCurrentRecording() {
		assert(status.recordingInfo != nil)
		guard let r = status.recordingInfo else {return}
		
		#warning("TODO: End the recording...")
		
		status = .stopped
	}
	
	/* *********************************
	   MARK: - Location Manager Delegate
	   ********************************* */
	
	func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
		canRecord = Set<CLAuthorizationStatus>(arrayLiteral: .notDetermined, .authorizedWhenInUse, .authorizedAlways).contains(status)
	}
	
	func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
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
	
	/** The GPX element containing the recording path.
	
	It is implicitly unwrapped! We have to be careful when we use it… Should
	always be non-nil while recording. I tried being careful; it should be ok. */
	private var currentGPX: GPXgpxType!
	
	/** The handle on which to write to continue the GPX file.
	
	It is implicitly unwrapped! We have to be careful when we use it… Should
	always be non-nil while recording (the willSet of the status property makes
	sure of this). */
	private var currentGPXHandle: FileHandle!
	
	/* *** Dependencies *** */
	
	private let lm: CLLocationManager
	private let rm: RecordingsManager
	
	private var numberOfClientsRequiringTracking = 0
	
	private func handleStatusChange(from oldStatus: Status, to newStatus: Status) {
		if oldStatus.recordingInfo == nil, let newRecordingInfo = newStatus.recordingInfo {
			assert(currentGPX == nil && currentGPXHandle == nil)
			/* We must create the GPX object! Note: If the GPX file already existed
			 * (e.g. the app quit/relaunched while a recording was in progress), we
			 * do not reload it; we simply create a new GPX object. Indeed, this
			 * object is only used for its conveniences to write GPX XML. */
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
			/* TODO: This is bad, to just assume the FileHandle creation will work… */
			currentGPXHandle = try! FileHandle(forWritingTo: newRecordingInfo.gpxURL)
			currentGPXHandle.seekToEndOfFile()
		} else if oldStatus.recordingInfo != nil && newStatus.recordingInfo == nil {
			currentGPX = nil
			currentGPXHandle = nil
		}
		
		if newStatus.isTrackingUserPosition {
			if newStatus.isRecording {lm.requestAlwaysAuthorization()}
			else                     {lm.requestWhenInUseAuthorization()}
		}
		if newStatus.isTrackingUserPosition && !oldStatus.isTrackingUserPosition {
			/* Also done at init time if needed. */
			lm.startUpdatingLocation()
			lm.startUpdatingHeading()
		} else if !newStatus.isTrackingUserPosition && oldStatus.isTrackingUserPosition {
			lm.stopUpdatingHeading()
			lm.stopUpdatingLocation()
		}
		if #available(iOS 9.0, *) {lm.allowsBackgroundLocationUpdates = newStatus.isRecording}
	}
	
}
