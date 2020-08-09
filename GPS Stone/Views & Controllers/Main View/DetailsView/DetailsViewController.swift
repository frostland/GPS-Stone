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
	
	@IBOutlet var labelTitle: UILabel!
	
	@IBOutlet var viewGPSInfo: UIView!
	@IBOutlet var viewGPSError: UIView!
	@IBOutlet var viewRecordingInfo: UIView!
	
	@IBOutlet var buttonRecord: UIButton!
	
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .default
	}
	
	deinit {
		/* This removes the timer to refresh the duration shown of the recording,
		 * which needed before iOS 10 because the timer keeps a strong ref to the
		 * target until the timer is deallocated. */
		recordingInfoViewController?.model = nil
		
		if let o = settingsObserver {
			NotificationCenter.default.removeObserver(o)
			settingsObserver = nil
		}
		
		kvObserver.stopObservingEverything()
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		if #available(iOS 9, *) {} else {
			/* On iOS 8, I don’t know why, but the title font does not work… */
			labelTitle.font = UIFont.systemFont(ofSize: 27)
		}
		
		assert(settingsObserver == nil)
		settingsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main, using: { [weak self] _ in
			guard let self = self else {return}
			self.gpsInfoViewController?.useMetricSystem = self.appSettings.useMetricSystem
			self.updateRecordingUI()
			self.updateLocationUI()
		})
		self.gpsInfoViewController?.useMetricSystem = self.appSettings.useMetricSystem
		
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
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		switch segue.identifier {
		case "GPSInfoEmbed"?:
			gpsInfoViewController = (segue.destination as! GPSInfoViewController)
			gpsInfoViewController?.useMetricSystem = appSettings.useMetricSystem
			updateLocationUI() /* Calls updateHeadingUI() */
			
		case "GPSErrorEmbed"?:
			gpsErrorViewController = (segue.destination as! GPSErrorViewController)
			
		case "RecordingInfoEmbed"?:
			recordingInfoViewController = (segue.destination as! RecordingInfoViewController)
			
		default: (/*nop*/)
		}
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
	
	private var gpsInfoViewController: GPSInfoViewController?
	private var gpsErrorViewController: GPSErrorViewController?
	private var recordingInfoViewController: RecordingInfoViewController?
	
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
	
	private func updateLocationUI() {
		gpsInfoViewController?.locationModel = locationRecorder.currentLocation
		if locationRecorder.currentLocation != nil {
			/* We show the GPS Info controller and hide the GPS troubleshoot view. */
			if viewGPSInfo.alpha < 0.5 {
				assert(viewGPSError.alpha > 0.5)
				UIView.animate(withDuration: c.animTime, animations: {
					self.viewGPSInfo.alpha = 1
					self.viewGPSError.alpha = 0
				})
			}
		} else {
			/* We hide the GPS Info controller and show the GPS troubleshoot view. */
			gpsErrorViewController?.error = GPSStoneLocationError(error: locationRecorder.currentLocationManagerError)
			if viewGPSInfo.alpha > 0.5 {
				assert(viewGPSError.alpha < 0.5)
				UIView.animate(withDuration: c.animTime, animations: {
					self.viewGPSInfo.alpha = 0
					self.viewGPSError.alpha = 1
				})
			}
		}
		
		/* If the location has a heading but we do not receive heading updates
		 * (e.g. simulator), we still want to update the heading UI! */
		updateHeadingUI()
	}
	
	private func updateHeadingUI() {
		gpsInfoViewController?.headingModel = locationRecorder.currentHeading?.trueHeading ?? locationRecorder.currentLocation?.course
	}
	
	private func updateRecordingUI() {
		assert(Thread.isMainThread)
		
		recordingInfoViewController?.model = currentRecording.flatMap(RecordingInfoViewController.Model.init)
		if let r = currentRecording {
			/* We show the recording controller and hide the recording button. */
			if viewRecordingInfo.alpha < 0.5 {
				assert(buttonRecord.alpha > 0.5)
				UIView.animate(withDuration: c.animTime, animations: {
					self.viewRecordingInfo.alpha = 1
					self.buttonRecord.alpha = 0
				})
			}
			
			let d = r.activeRecordingDurationCappedToLatestPoint
			gpsInfoViewController?.recordingModel = .init(maxSpeed: CLLocationSpeed(r.maxSpeed), avgSpeed: (d > 0.5 ? Double(r.totalDistance) / d : nil))
		} else {
			/* We hide the recording controller and show the recording button. */
			if viewRecordingInfo.alpha > 0.5 {
				assert(buttonRecord.alpha < 0.5)
				UIView.animate(withDuration: c.animTime, animations: {
					self.viewRecordingInfo.alpha = 0
					self.buttonRecord.alpha = 1
				})
			}
			gpsInfoViewController?.recordingModel = nil
		}
	}
	
}
