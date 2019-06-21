/*
 * DetailsViewController.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 18/06/2019.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import Foundation
import UIKit

import KVObserver



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
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
//		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged:) name:c.ntfSettingsChanged object:nil];
		
		imageNorth.alpha = 0
		
//		if (!currentGPX) [viewWithTrackInfos setAlpha:0.];
//		else             [viewWithTrackInfos setAlpha:1.];
//		if ([[currentRecordingInfo valueForKey:c.recListRecordStateKey] unsignedIntValue] == VSORecordStateStopped) [buttonRecord setAlpha:1.];
//		else                                                                                                              [buttonRecord setAlpha:0.];
		
//		[self settingsChanged:nil];
		
		_ = kvObserver.observe(object: locationRecorder, keyPath: #keyPath(LocationRecorder.currentLocation), kvoOptions: [.initial], dispatchType: .asyncOnMainQueueDirectInitial, handler: { [weak self] _ in
			self?.updateLocationUI()
		})
		_ = kvObserver.observe(object: locationRecorder, keyPath: #keyPath(LocationRecorder.currentHeading), kvoOptions: [.initial], dispatchType: .asyncOnMainQueueDirectInitial, handler: { [weak self] _ in
			self?.updateHeadingUI()
		})
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		locationRecorder.retainTracking()
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		
		locationRecorder.releaseTracking()
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let c = S.sp.constants
	private let appSettings = S.sp.appSettings
	private let locationRecorder = S.sp.locationRecorder
	
	private let kvObserver = KVObserver()
	
	private func updateLocationUI() {
		labelLat.text = NSLocalizedString("getting loc", comment: "")
		labelLong.text = ""
		labelSpeed.text = NSStringFromSpeed(0, false, !appSettings.useMetricSystem)
		labelAltitude.text = NSLocalizedString("nd", comment: "")
		labelVerticalAccuracy.text = ""
		labelHorizontalAccuracy.text = NSLocalizedString("nd", comment: "")
		
		labelTrackName.text = NSLocalizedString("nd", comment: "")
		labelMaxSpeed.text = NSLocalizedString("nd", comment: "")
		labelAverageSpeed.text = NSLocalizedString("nd", comment: "")
		labelElapsedTime.text = "00:00:00"
		labelTotalDistance.text = NSLocalizedString("nd", comment: "")
		labelNumberOfPoints.text = NSLocalizedString("nd", comment: "")
		
		if let location = locationRecorder.currentLocation {
			labelLat.text  = NSStringFromDegrees(location.coordinate.latitude,  true)
			labelLong.text = NSStringFromDegrees(location.coordinate.longitude, false)
			labelHorizontalAccuracy.text = NSStringFromDistance(location.horizontalAccuracy, !appSettings.useMetricSystem)
			labelHorizontalAccuracy.textColor = (location.horizontalAccuracy > c.maxAccuracyToRecordPoint ? .red : .black)
			if location.verticalAccuracy.sign == .plus {
				labelAltitude.text = NSStringFromAltitude(location.altitude, !appSettings.useMetricSystem)
				#warning("TODO: Use XibLoc!")
				labelVerticalAccuracy.text = abs(location.altitude) < 0.001 ? "" : String(format: NSLocalizedString("plus minus n percent format", comment: ""), Int((location.verticalAccuracy/abs(location.altitude)) * 100))
			}
			if location.speed.sign == .plus {
				labelSpeed.text = NSStringFromSpeed(location.speed, false, !appSettings.useMetricSystem)
			}
		}
	}
	
	private func updateHeadingUI() {
		if let h = locationRecorder.currentLocation?.course ?? locationRecorder.currentHeading?.trueHeading, h.sign == .plus {
			UIView.animate(withDuration: c.animTime, animations: {
				self.imageNorth.alpha = 1
				self.imageNorth.transform = CGAffineTransform(rotationAngle: -2 * CGFloat.pi * CGFloat(h/360))
			})
		}
	}
	
}
