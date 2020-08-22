/*
 * LocationRecorder.swift
 * GPS Stone
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
	
	public static let errorDomain = Constants.appDomain + ".LocationRecorder"
	public static let errorCodeUnknown = 1
	public static let errorCodeLocationManagerPausedUpdates = 42
	
	enum RecordingStatus : Codable, Equatable {
		
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
					throw NSError(domain: LocationRecorder.errorDomain, code: LocationRecorder.errorCodeUnknown, userInfo: nil)
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
			try container.encode(segmentID, forKey: .segmentID)
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
	var recStatus: RecordingStatus {
		return status.recordingStatus
	}
	
	@objc dynamic private(set) var currentHeading: CLHeading?
	@objc dynamic private(set) var currentLocation: CLLocation?
	@objc dynamic private(set) var currentLocationManagerError: NSError?
	
	init(locationManager: CLLocationManager, recordingsManager: RecordingsManager, dataHandler: DataHandler, appSettings: AppSettings, constants: Constants, notificationCenter: NotificationCenter = .default) {
		assert(Thread.isMainThread)
		
		c = constants
		s = appSettings
		dh = dataHandler
		lm = locationManager
		rm = recordingsManager
		nc = notificationCenter
		recStatusesHistory = (try? PropertyListDecoder().decode([RecordingStatusHistoryEntry].self, from: Data(contentsOf: constants.urlToCurrentRecordingInfo))) ?? []
		status = Status(recordingStatus: recStatusesHistory.last?.status ?? .stopped, appSettingBestAccuracy: appSettings.useBestGPSAccuracy)
		
		super.init()
		
		lm.pausesLocationUpdatesAutomatically = true
		lm.desiredAccuracy = status.desiredAccuracy
		lm.distanceFilter = kCLDistanceFilterNone
		lm.activityType = .fitness
		lm.delegate = self
		/* KVO on \.applicationState does not work, so we observe the app notifications instead. */
		notificationObservers.append(nc.addObserver(forName: AppSettings.changedNotification, object: nil, queue: OperationQueue.main, using: { [weak self] _ in self?.appSettingsChanged() }))
		notificationObservers.append(nc.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: OperationQueue.main, using: { [weak self] _ in self?.appStateChanged() }))
		notificationObservers.append(nc.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: OperationQueue.main, using: { [weak self] _ in self?.appStateChanged() }))
		/* See comment in appStateChanged for explanation of the removal of the observation below. */
//		notificationObservers.append(nc.addObserver(forName: UIApplication.backgroundRefreshStatusDidChangeNotification, object: nil, queue: OperationQueue.main, using: { [weak self] _ in self?.appStateChanged() }))
		/* No need to call appStateChanged() (at least for now). Only the
		 * appIsInBg property is modified by the method, and this property is
		 * correctly initialized. */
		
		handleStatusChange(from: Status(recordingStatus: .stopped, appSettingBestAccuracy: appSettings.useBestGPSAccuracy), to: status) /* willSet/didSet not called from init */
	}
	
	deinit {
		for o in notificationObservers {
			nc.removeObserver(o)
		}
	}
	
	/**
	Tells the location recorder a new client requires the user’s position.
	
	When you don’t need the position anymore, call `releaseLocationTracking()` */
	func retainLocationTracking() {
		status.nClientsRequiringLocTracking += 1
	}
	
	func releaseLocationTracking() {
		guard status.nClientsRequiringLocTracking > 0 else {
			NSLog("***** ERROR: releaseLocationTracking called but there are no clients requiring tracking.")
			return
		}
		status.nClientsRequiringLocTracking -= 1
	}
	
	/**
	Tells the location recorder a new client requires the user’s heading.
	
	When you don’t need the position anymore, call `releaseHeadingTracking()` */
	func retainHeadingTracking() {
		status.nClientsRequiringHeadingTracking += 1
	}
	
	func releaseHeadingTracking() {
		guard status.nClientsRequiringHeadingTracking > 0 else {
			NSLog("***** ERROR: releaseHeadingTracking called but there are no clients requiring tracking.")
			return
		}
		status.nClientsRequiringHeadingTracking -= 1
	}
	
	/**
	Starts a new recording.
	
	This method is only valid to call while the location recorder is **stopped**
	(it does not have a current recording). Will crash in debug mode (assert
	active) if called while the recording is recording. */
	func startNewRecording() throws {
		assert(Thread.isMainThread)
		assert(recStatus.isStopped)
		guard recStatus.isStopped else {return}
		
		let recording = try rm.unsafeCreateNextRecordingAndSaveContext()
		status.recordingStatus = .recording(recordingRef: rm.recordingRef(from: recording.objectID), segmentID: 0)
	}
	
	/**
	Pauses the current recording.
	
	This method is only valid to call while the location recorder is **not**
	stopped (it has a current recording). Will crash in debug mode (assert
	active) if called at an invalid time. */
	func pauseCurrentRecording() throws {
		assert(Thread.isMainThread)
		assert(recStatus.recordingRef != nil)
		guard let rrAndSID = recStatus.recordingRefAndSegmentID else {return}
		
		let r = try recordingWriteObjects(for: rrAndSID.recordingRef)
		assert(r.recording.pauses?.count ?? 0 == rrAndSID.segmentID)
		try rm.unsafeAddPauseAndSaveContext(to: r.recording)
		
		status.recordingStatus = .paused(recordingRef: rrAndSID.recordingRef, segmentID: rrAndSID.segmentID)
	}
	
	/**
	Resumes the current recording.
	
	This method is only valid to call while the location recorder is **paused by
	the user**. Will crash in debug mode (assert active) if called at an invalid
	time. */
	func resumeCurrentRecording() throws {
		assert(Thread.isMainThread)
		guard case .paused(let rr, let sid) = recStatus else {
			assertionFailure()
			return
		}
		
		let r = try recordingWriteObjects(for: rr)
		assert(r.recording.pauses?.count ?? 0 == sid + 1)
		try rm.unsafeFinishLatestPauseAndSaveContext(in: r.recording)
		
		status.locationTrackingPaused = false
		status.recordingStatus = .recording(recordingRef: rr, segmentID: sid + 1)
	}
	
	/**
	Stops the current recording.
	
	This method is only valid to call while the location recorder is **not**
	stopped (it has a current recording). Will crash if called at an invalid
	time. */
	func stopCurrentRecording() throws -> Recording {
		assert(Thread.isMainThread)
		
		let r = try recordingWriteObjects(for: recStatus.recordingRef!)
		
		if case .paused = recStatus {
			/* If we were paused we close the latest pause time segment. */
			try rm.unsafeFinishLatestPauseAndSaveContext(in: r.recording)
		}
		try rm.unsafeFinishRecordingAndSaveContext(r.recording)
		
		status.recordingStatus = .stopped
		return r.recording
	}
	
	/** Call this to resume location tracking after the system paused it. */
	func resumeLocationTracking() {
		status.locationTrackingPaused = false
	}
	
	/* *********************************
	   MARK: - Location Manager Delegate
	   ********************************* */
	
	func locationManager(_ manager: CLLocationManager, didChangeAuthorization authStatus: CLAuthorizationStatus) {
		assert(Thread.isMainThread)
		/* Nothing to do here, because we use errors to show messages to the user. */
	}
	
	func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
		NSLog("%@", "Location manager error \(error)")
		
		let nserror = error as NSError
		guard nserror.domain != kCLErrorDomain || nserror.code != CLError.Code.locationUnknown.rawValue else {
			/* Doc says this error can be ignored. */
			return
		}
		
		currentLocationManagerError = nserror
		currentLocation = nil
		
		/* Doc says we should stop the location service in case we get a denied. */
	}
	
	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		assert(Thread.isMainThread)
		
		NSLog("%@", "Received new locations \(locations)")
		currentLocationManagerError = nil
		handleNewLocations(locations)
		
		/* We start deferred updates here because the doc recommends so. */
		if status.allowDeferredUpdates && !isDeferringUpdates {
			startDeferredLocationUpdates()
		}
	}
	
	func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
		status.locationTrackingPaused = true
		_ = try? pauseCurrentRecording()
		
		currentLocationManagerError = NSError(domain: LocationRecorder.errorDomain, code: LocationRecorder.errorCodeLocationManagerPausedUpdates, userInfo: nil)
		currentLocation = nil
	}
	
	func locationManager(_ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: Error?) {
		assert(Thread.isMainThread)
		
		/* Note: We do not set `gotFatalDeferredUpdatesError` directly to the
		 * value of the test below because I want to be certain the status does
		 * not changes if it does not have to. */
		if let e = error, ((e as? CLError)?.code != .deferredCanceled) {
			/* For now (and probably forever), any error is a fatal error for
			 * deferred location updates, except the cancellation error.
			 * The “accuracy is not big enough” error is handled somewhere else and
			 * should not happen, we do not have a distance filter on the location
			 * manager so we should not get the distance filter error and all other
			 * errors are fatal (AFAIK). */
			status.gotFatalDeferredUpdatesError = true
		} else {
			/* Technically this should never be reached because we prevent deferred
			 * updates once we got a fatal error. */
			status.gotFatalDeferredUpdatesError = false
		}
		
		isDeferringUpdates = false
		
		/* Restart deferred updates if we still need them. */
		if status.allowDeferredUpdates {
			startDeferredLocationUpdates()
		}
	}
	
	func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
		assert(Thread.isMainThread)
		
		if newHeading.headingAccuracy.sign == .plus {currentHeading = newHeading}
		else                                        {currentHeading = nil}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/** Contains a reference to the resolved CoreData Recording object. Currenlty
	this struct is a bit of an overkill, but used to contain a FileHandle and a
	GPXgpxType object. */
	private struct RecordingWriteObjects {
		
		let recordingRef: URL
		let recording: Recording
		
		init(recordingRef rr: URL, recordingsManager: RecordingsManager) throws {
			assert(Thread.isMainThread)
			
			guard let r = recordingsManager.unsafeRecording(from: rr) else {
				throw NSError(domain: LocationRecorder.errorDomain, code: LocationRecorder.errorCodeUnknown, userInfo: [NSLocalizedDescriptionKey: "Cannot retrieve the given recording when instantiating a RecordingWriteObjects."])
			}
			
			recordingRef = rr
			recording = r
		}
		
	}
	
	/** The recorder status. The location manager status is changed depending on
	the values of the properties of this struct, when this struct changes. */
	private struct Status {
		
		var recordingStatus: RecordingStatus
		
		/* Set to true when location manager pauses location tracking. Must be set
		 * to false to resume location tracking. */
		var locationTrackingPaused = false
		
		var nClientsRequiringLocTracking = 0
		var nClientsRequiringHeadingTracking = 0
		
		var appIsInBg = (UIApplication.shared.applicationState == .background)
		
		var appSettingBestAccuracy: Bool
		
		/* We block all further location update deferring once we get an error. */
		var gotFatalDeferredUpdatesError = false
		
		var isRecording: Bool {
			return recordingStatus.isRecording
		}
		
		var needsAlwaysAuth: Bool {
			/* When we need the tracking, we ask for the permissions. If we’re
			 * recording a trip it might better to have the always permission
			 * (though apparently not really needed; it seems to only rid of the
			 * blue bar telling an app is actively using one’s position; we must
			 * test this fully and maybe drop the always). */
			return isRecording
		}
		
		var needsSignificantLocationChangesTracking: Bool {
			return isRecording
		}
		
		var needsBackgroundLocationUpdates: Bool {
			/* We allow background location updates when recording a trip. */
			return isRecording
		}
		
		var requiresLocationTrackingForClients: Bool {
			return nClientsRequiringLocTracking > 0
		}
		
		var requiresHeadingTrackingForClients: Bool {
			return nClientsRequiringHeadingTracking > 0
		}
		
		var needsLocationTracking: Bool {
			return !locationTrackingPaused && (isRecording || (requiresLocationTrackingForClients && !appIsInBg))
		}
		
		var needsHeadingTracking: Bool {
			/* Only clients use the heading; we don’t use it while recording a trip */
			return requiresHeadingTrackingForClients && !appIsInBg
		}
		
		var desiredAccuracy: CLLocationAccuracy {
			return ((isRecording && appSettingBestAccuracy) ? kCLLocationAccuracyBest : kCLLocationAccuracyNearestTenMeters)
		}
		
		var allowDeferredUpdates: Bool {
			guard !gotFatalDeferredUpdatesError else {return false}
			guard CLLocationManager.deferredLocationUpdatesAvailable() else {return false}
			
			/* When the app is in the fg the location updates are not deferred (doc
			 * says), so we do not check whether the app is in the bg.
			 * If the desired accuracy is not enough, the system will not allow
			 * deferred updates, so we check for desired accuracy first. */
			let hasSufficientAccuracy = (desiredAccuracy == kCLLocationAccuracyBest || desiredAccuracy == kCLLocationAccuracyBestForNavigation)
			return isRecording && hasSufficientAccuracy
		}
		
	}
	
	private struct RecordingStatusHistoryEntry : Codable {
		
		var date: Date
		var status: RecordingStatus
		
	}
	
	private var status: Status {
		willSet {
			if status.recordingStatus != newValue.recordingStatus {
				willChangeValue(for: \.objc_recStatus)
			}
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
			 *             stay the same forever though…
			 *             @jckarter says yes it is the expected behavior:
			 *             https://twitter.com/jckarter/status/1255509948127215616 */
			handleStatusChange(from: oldValue, to: status)
			
			if oldValue.recordingStatus != status.recordingStatus {
				didChangeValue(for: \.objc_recStatus)
			}
		}
	}
	/* **NOT** in the status because change. We want to avoid triggering a status
	 * change handling when we modify this property (among other things, we can
	 * modify this property from within a status change handling). */
	private var isDeferringUpdates = false
	
	/**
	The history of recording statuses w/ the date of change.
	
	We need this because we can receive delayed location events, so we need to
	know what _was_ our recording status at the event date. */
	private var recStatusesHistory: [RecordingStatusHistoryEntry]
	
	private var cachedRecordingWriteObjects: RecordingWriteObjects?
	
	/** The locations that couldn’t be saved, with the save error.
	Currently unused; see issue https://github.com/frostland/GPS-Stone/issues/1 */
	private var saveFailedLocations = [(location: CLLocation, error: Error)]()
	
	private var notificationObservers = [NSObjectProtocol]()
	
	/* *** Dependencies *** */
	
	private let c: Constants
	private let s: AppSettings
	private let dh: DataHandler
	private let lm: CLLocationManager
	private let rm: RecordingsManager
	private let nc: NotificationCenter
	
	/**
	Returns the recording status at the given date.
	
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
		
		var changedContext = false
		var numberOfPointsFailed = 0
		for newLocation in locations {
			let checkedRecStatus = recStatus(at: newLocation.timestamp)
			guard case .recording(let recordingRef, let segmentID) = checkedRecStatus else {continue}
			
			do {
				let writeObjects = try recordingWriteObjects(for: recordingRef)
				
				let distance: CLLocationDistance
				if let previousPoint = try writeObjects.recording.latestPoint(before: newLocation.timestamp),
					let previousPointLocation = previousPoint.location
				{
					distance = newLocation.distance(from: previousPointLocation)
					/* I’m aware of the distance filter property of the location
					 * manager, however it’s not really a good fit for us:
					 *    - If the client requires location tracking (the users is
					 *      looking at the map or the GPS info), we must not apply a
					 *      distance filter. In itself, this is not enough to justify
					 *      dropping the system’s, however,
					 *    - When we don’t apply a distance filter, we still have to
					 *      apply the distance filter to the recording of the points,
					 *      so we have to implement the distance filter ourself
					 *      anyway, AND check we’re indeed not filtering with the
					 *      system to apply our own filter (or we could drop points
					 *      because of a desynchronisation between our latest
					 *      recorded point and the one the system knows about, or
					 *      algorithmic differences between our filter and the
					 *      system’s);
					 *    - Which also means we should know for points from the past
					 *      (deferred updates) whether the distance filter was on or
					 *      not! Which is currently not possible because we save the
					 *      recording status history but not the location recorder
					 *      status history. (Although doc says we should only receive
					 *      deferred location update when the app is in the bg, time
					 *      during which the distance filter status should not
					 *      change.)
					 *    - Finally, I don’t see any gain that would oppose to the
					 *      arguments above for using the distance filter. We should
					 *      measure it to be certain, but there is in theory no
					 *      battery gain when using the distance filter… (Doc does
					 *      not say there is at least.)
					 * Another note about the distance filter: We do not save the
					 * history of the distance filter value, which means if the user
					 * changes the distance filter, we can potentially receive an
					 * update from a point in time before the user has changed it,
					 * and thus have an incorrect distance filter value when we
					 * process the point.
					 * In practice we do not really care because:
					 *    - Deferred location updates should only happen in the bg,
					 *      in which case the user cannot change the distance filter
					 *      (at least from the time the deferred location updates API
					 *      was not deprecated, deferred location udpates could only
					 *      happen in the bg; now I think we cannot manually opt-in
					 *      to deferred location updates, but they happen anyway, and
					 *      I guess they would not do deferred location update when
					 *      the app in the fg. All of this remains to be proven, if
					 *      that is even possible…)
					 *    - A change in the distance filter will probably be a rare
					 *      event, and some missing or additional points recorded are
					 *      not, IMHO, such a big deal!
					 *
					 * One final distance filter note!
					 * After some thinking, maybe we could have two location
					 * managers; one for the UI, and one for the recordings. This way
					 * we would only configure the distance filter of the location
					 * manager for the recordings, and leave the other alone, which
					 * would solve all of the deferred updates problems, as well as
					 * some other issues. */
					guard distance >= s.distanceFilter else {continue}
				} else {
					distance = 0
				}
				
				rm.unsafeAddPoint(location: newLocation, addedDistance: distance, segmentID: segmentID, to: writeObjects.recording)
				changedContext = true
			} catch {
				/* Adding the location to the list of locations that couldn’t be
				 * saved… */
				numberOfPointsFailed += 1
				saveFailedLocations.append((location: newLocation, error: error))
			}
		}
		/* Not fully convinced checking whether we changed the context is useful
		 * before saving it (CoreData should be optimized so that it wouldn’t do
		 * anything at all if saving no modifications IMHO). */
		if changedContext {
			do {
				try dh.saveContextOrRollback()
			} catch {
				/* Adding ALL the locations to the list of locations that couldn’t
				 * be saved… */
				saveFailedLocations.removeLast(numberOfPointsFailed)
				saveFailedLocations.append(contentsOf: locations.map{ (location: $0, error: error) })
			}
		}
		
		if locations.last?.horizontalAccuracy.sign == .plus {currentLocation = locations.last}
		else                                                {currentLocation = nil}
	}
	
	private func handleStatusChange(from oldStatus: Status, to newStatus: Status) {
		assert(Thread.isMainThread)
		NSLog("%@", "Status change from \(oldStatus) to \(newStatus)")
		
		/* *** Let’s save the current status *** */
		if oldStatus.recordingStatus != newStatus.recordingStatus {
			recStatusesHistory.append(RecordingStatusHistoryEntry(date: Date(), status: newStatus.recordingStatus))
			_ = try? PropertyListEncoder().encode(recStatusesHistory).write(to: c.urlToCurrentRecordingInfo)
		}
		
		/* *** Get or clear the current RecordingWriteObjects *** */
		if oldStatus.recordingStatus.recordingRef == nil, let newRecordingRef = newStatus.recordingStatus.recordingRef {
			cachedRecordingWriteObjects = try? RecordingWriteObjects(recordingRef: newRecordingRef, recordingsManager: rm)
			guard cachedRecordingWriteObjects != nil else {
				/* If we cannot get a RecordingWriteObjects recording won’t work. We
				 * change our status to stopped.
				 * We should provide a way to retrieve the error… maybe move the get
				 * of this object in the start method? But there is the case of the
				 * app launching in a recording state, which will not call the start
				 * method… */
				status.recordingStatus = .stopped
				return
			}
		} else if oldStatus.recordingStatus.recordingRef != nil && newStatus.recordingStatus.recordingRef == nil {
			cachedRecordingWriteObjects = nil
		}
		
		let needsLocationTracking = newStatus.needsLocationTracking
		
		/* *** Ask for location authorization if needed *** */
		if needsLocationTracking {
			let needsAlwaysAuth = newStatus.needsAlwaysAuth
			if needsAlwaysAuth {lm.requestAlwaysAuthorization()}
			else               {lm.requestWhenInUseAuthorization()}
		}
		
		/* We disable deferred updates (if needed) before changing the desired
		 * accuracy because deferred updates depend on desired accuracy.
		 * Doc recommends enabling deferred updates when receiving a new location,
		 * so that’s what we do (and that’s why the deferred location updates are
		 * not started in this method). */
		if !newStatus.allowDeferredUpdates && isDeferringUpdates {
			lm.disallowDeferredLocationUpdates()
			#warning("Comment below")
			/* To be verified, but in theory the delegate method should still be
			 * called when manually stopping deferred location updates, so we do
			 * not set isDeferringUpdates to false here. */
		}
		
		/* *** Update location manager desired accuracy *** */
		let desiredAccuracy = newStatus.desiredAccuracy
		let prevDesiredAccuracy = oldStatus.desiredAccuracy
		if desiredAccuracy != prevDesiredAccuracy {lm.desiredAccuracy = desiredAccuracy}
		
		/* *** Start or stop significant location changes if needed *** */
		if CLLocationManager.significantLocationChangeMonitoringAvailable() {
			let needsSignificantLocationChangesTracking = newStatus.needsSignificantLocationChangesTracking
			let neededSignificantLocationChangesTracking = oldStatus.needsSignificantLocationChangesTracking
			if needsSignificantLocationChangesTracking && !neededSignificantLocationChangesTracking {
				/* This should launch the app when it gets a significant location
				 * changes even if the user has force quit it, if the background app
				 * refresh is on.
				 * After some testing, the app seems to be relaunched even with bg
				 * app refresh off! */
				lm.startMonitoringSignificantLocationChanges()
			} else if !needsSignificantLocationChangesTracking && neededSignificantLocationChangesTracking {
				lm.stopMonitoringSignificantLocationChanges()
			}
		}
		
		/* *** Start or stop location tracking if needed *** */
		let neededLocationTracking = oldStatus.needsLocationTracking
		if       needsLocationTracking && !neededLocationTracking {lm.startUpdatingLocation()}
		else if !needsLocationTracking &&  neededLocationTracking {lm.stopUpdatingLocation()}
		
		/* *** Start or stop heading tracking if needed *** */
		if CLLocationManager.headingAvailable() {
			let needsHeadingTracking = newStatus.needsHeadingTracking
			let neededHeadingTracking = oldStatus.needsHeadingTracking
			if       needsHeadingTracking && !neededHeadingTracking {lm.startUpdatingHeading()}
			else if !needsHeadingTracking &&  neededHeadingTracking {lm.stopUpdatingHeading()}
		}
		
		/* *** Enable/disable bg location udpates if needed *** */
		if #available(iOS 9.0, *) {
			let needsBackgroundLocationUpdates = newStatus.needsBackgroundLocationUpdates
			let neededBackgroundLocationUpdates = oldStatus.needsBackgroundLocationUpdates
			if needsBackgroundLocationUpdates != neededBackgroundLocationUpdates {
				lm.allowsBackgroundLocationUpdates = needsBackgroundLocationUpdates
			}
		}
	}
	
	private func appSettingsChanged() {
		if status.appSettingBestAccuracy != s.useBestGPSAccuracy {status.appSettingBestAccuracy = s.useBestGPSAccuracy}
	}
	
	private func appStateChanged() {
		status.appIsInBg = (UIApplication.shared.applicationState == .background)
		
		/* The comment below is the doc. It seems to be an outrageous lie (I have
		 * done some tests and got the app to receive significant location changes
		 * when bg app refresh was disabled), so we simply ignore modifications of
		 * the background app refresh status. */
		
		/* From https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/LocationAwarenessPG/CoreLocation/CoreLocation.html#//apple_ref/doc/uid/TP40009497-CH2-SW11
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
	}
	
	private func startDeferredLocationUpdates() {
		guard CLLocationManager.deferredLocationUpdatesAvailable() else {return}
		
		lm.allowDeferredLocationUpdates(untilTraveled: CLLocationDistanceMax, timeout: CLTimeIntervalMax)
		isDeferringUpdates = true
	}
	
}
