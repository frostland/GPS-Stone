/*
 * DetailsViewController.swift
 * GPS Stone
 *
 * Created by François Lamboley on 18/06/2019.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import CoreData
import CoreLocation
import Foundation
import UIKit

import KVObserver
import XibLoc



class DetailsViewController : UIViewController {
	
	@IBOutlet var labelLat: UILabel!
	@IBOutlet var labelLong: UILabel!
	@IBOutlet var labelSpeed: UILabel!
	@IBOutlet var labelAverageSpeed: UILabel!
	@IBOutlet var labelMaxSpeed: UILabel!
	@IBOutlet var labelHorizontalAccuracy: UILabel!
	@IBOutlet var labelAltitude: UILabel!
	@IBOutlet var labelVerticalAccuracy: UILabel!
	@IBOutlet var labelNumberOfPoints: UILabel!
	@IBOutlet var labelTotalDistance: UILabel!
	@IBOutlet var labelElapsedTime: UILabel!
	@IBOutlet var labelTrackName: UILabel!
	@IBOutlet var labelKmph: UILabel!
	@IBOutlet var imageNorth: UIImageView!
	
	@IBOutlet var viewWithTrackInfos: UIView!
	
	@IBOutlet var buttonRecord: UIButton!
	
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .default
	}
	
	deinit {
		timerUpdateTimeUI?.invalidate()
		timerUpdateTimeUI = nil
		
		if let o = settingsObserver {
			NotificationCenter.default.removeObserver(o)
			settingsObserver = nil
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		imageNorth.alpha = 0
		
		assert(settingsObserver == nil)
		settingsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main, using: { [weak self] _ in
			guard let self = self else {return}
			self.updateUnitsLabels()
			self.updateRecordingUI()
			self.updateLocationUI()
		})
		updateUnitsLabels()
		
		_ = kvObserver.observe(object: locationRecorder, keyPath: #keyPath(LocationRecorder.objc_recStatus), kvoOptions: [.initial], dispatchType: .asyncOnMainQueueDirectInitial, handler: { [weak self] _ in
			guard let self = self else {return}
			self.currentRecording = self.locationRecorder.recStatus.recordingRef.flatMap{ self.recordingsManager.unsafeRecording(from: $0) }
			self.updateRecordingUI()
		})
		_ = kvObserver.observe(object: locationRecorder, keyPath: #keyPath(LocationRecorder.currentLocation), kvoOptions: [.initial], dispatchType: .asyncOnMainQueueDirectInitial, handler: { [weak self] _ in
			self?.updateLocationUI()
		})
		_ = kvObserver.observe(object: locationRecorder, keyPath: #keyPath(LocationRecorder.currentHeading), kvoOptions: [.initial], dispatchType: .asyncOnMainQueueDirectInitial, handler: { [weak self] _ in
			self?.updateHeadingUI()
		})
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		locationRecorder.retainLocationTracking()
		locationRecorder.retainHeadingTracking()
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		
		locationRecorder.releaseHeadingTracking()
		locationRecorder.releaseLocationTracking()
	}
	
	@IBAction func startRecording(_ sender: Any) {
		#warning("TODO: Handle the error if any")
		try? locationRecorder.startNewRecording()
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let c = S.sp.constants
	private let appSettings = S.sp.appSettings
	private let locationRecorder = S.sp.locationRecorder
	private let recordingsManager = S.sp.recordingsManager
	
	private let kvObserver = KVObserver()
	private var settingsObserver: NSObjectProtocol?
	
	private var timerUpdateTimeUI: Timer?
	private var currentRecordingObservationId: NSObjectProtocol?
	private var currentRecording: Recording? {
		willSet {
			currentRecordingObservationId.flatMap{ NotificationCenter.default.removeObserver($0) }
			currentRecordingObservationId = nil
		}
		didSet  {
			guard let r = currentRecording, let c = r.managedObjectContext else {return}
			currentRecordingObservationId = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextObjectsDidChange, object: c, queue: .main, using: { [weak self] notif in
				guard let updatedObjects = notif.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> else {return}
				guard updatedObjects.contains(r) else {return}
				self?.updateRecordingUI()
			})
		}
	}
	
	private var labelColor: UIColor {
		guard #available(iOS 13.0, *) else {
			return .black
		}
		return .label
	}
	
	private func updateUnitsLabels() {
		labelKmph.text = Utils.speedSymbol(usingMetricSystem: appSettings.useMetricSystem)
	}
	
	private func updateLocationUI() {
		labelLat.text = NSLocalizedString("getting loc", comment: "")
		labelLong.text = ""
		labelSpeed.text = Utils.stringFrom(speedValue: 0, useMetricSystem: appSettings.useMetricSystem)
		labelAltitude.text = NSLocalizedString("nd", comment: "")
		labelVerticalAccuracy.text = ""
		labelHorizontalAccuracy.text = NSLocalizedString("nd", comment: "")
		
		if let location = locationRecorder.currentLocation {
			labelLat.text  = Utils.stringFrom(latitudeDegrees:  location.coordinate.latitude)
			labelLong.text = Utils.stringFrom(longitudeDegrees: location.coordinate.longitude)
			labelHorizontalAccuracy.text = Utils.stringFrom(distance: location.horizontalAccuracy, useMetricSystem: appSettings.useMetricSystem)
			labelHorizontalAccuracy.textColor = (location.horizontalAccuracy > c.accuracyWarningThreshold ? .red : labelColor)
			if location.verticalAccuracy.sign == .plus {
				labelAltitude.text = Utils.stringFrom(altitude: location.altitude, useMetricSystem: appSettings.useMetricSystem)
				labelVerticalAccuracy.text = abs(location.altitude) < 0.001 ? "" : NSLocalizedString("more or less #n# percent", comment: "").applyingCommonTokens(number: XibLocNumber(Int((location.verticalAccuracy/abs(location.altitude)) * 100)))
			}
			if location.speed.sign == .plus {
				labelSpeed.text = Utils.stringFrom(speedValue: location.speed, useMetricSystem: appSettings.useMetricSystem)
			}
		}
		/* If the location has a heading but we do not receive heading updates
		 * (e.g. simulator), we still want to update the heading UI! */
		updateHeadingUI()
	}
	
	private func updateHeadingUI() {
		if let h = locationRecorder.currentHeading?.trueHeading ?? locationRecorder.currentLocation?.course, h.sign == .plus {
			UIView.animate(withDuration: c.animTime, animations: {
				self.imageNorth.alpha = 1
				self.imageNorth.transform = CGAffineTransform(rotationAngle: -2 * CGFloat.pi * CGFloat(h/360))
			})
		} else if imageNorth.alpha > 0.5 {
			UIView.animate(withDuration: c.animTime, animations: {
				self.imageNorth.alpha = 0
			})
		}
	}
	
	private func updateRecordingUI() {
		assert(Thread.isMainThread)
		
		if let recording = currentRecording {
			labelTrackName.text = recording.name
			labelMaxSpeed.text = Utils.stringFrom(speedValue: CLLocationSpeed(recording.maxSpeed), useMetricSystem: appSettings.useMetricSystem)
			labelTotalDistance.text = Utils.stringFrom(distance: Double(recording.totalDistance), useMetricSystem: appSettings.useMetricSystem)
			labelNumberOfPoints.text = XibLocNumber(recording.numberOfRecordedPoints).localizedString
			
			buttonRecord.isHidden = true
			viewWithTrackInfos.isHidden = false
			
			/* Not very beautiful putting this here… */
			if timerUpdateTimeUI == nil {
				timerUpdateTimeUI = Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: #selector(updateTimeUI(_:)), userInfo: nil, repeats: true)
			}
		} else {
			labelTrackName.text = NSLocalizedString("nd", comment: "")
			labelMaxSpeed.text = NSLocalizedString("nd", comment: "")
			labelTotalDistance.text = NSLocalizedString("nd", comment: "")
			labelNumberOfPoints.text = NSLocalizedString("nd", comment: "")
			
			labelAverageSpeed.text = NSLocalizedString("nd", comment: "")
			labelElapsedTime.text = Utils.stringFrom(timeInterval: 0)
			
			buttonRecord.isHidden = false
			viewWithTrackInfos.isHidden = true
			
			timerUpdateTimeUI?.invalidate()
			timerUpdateTimeUI = nil
		}
	}
	
	@objc
	private func updateTimeUI(_ timer: Timer?) {
		assert(Thread.isMainThread)
		guard let recording = currentRecording else {return}
		
		/* We cheat on the time (the record is not updated all the time) */
		var duration = -(recording.totalTimeSegment?.startDate?.timeIntervalSinceNow ?? 0)
		labelElapsedTime.text = Utils.stringFrom(timeInterval: duration)
		
		if let latestPointDate = try? recording.latestPointInTime()?.date {
			/* We cheat the time twice (to avoid having the average speed that
			 * moves all the time). */
			duration = -(recording.totalTimeSegment?.startDate?.timeIntervalSince(latestPointDate) ?? 0)
		}
		guard duration > 0.5 else {return}
		
		labelAverageSpeed.text = Utils.stringFrom(speedValue: Double(recording.totalDistance)/duration, useMetricSystem: appSettings.useMetricSystem)
	}
	
}
