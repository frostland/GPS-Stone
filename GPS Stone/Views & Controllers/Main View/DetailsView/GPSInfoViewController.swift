/*
 * GPSInfoViewController.swift
 * GPS Stone
 *
 * Created by François Lamboley on 2020/7/29.
 * Copyright © 2020 Frost Land. All rights reserved.
 */

import CoreLocation
import Foundation
import UIKit

import XibLoc



/* Not sure this needs to be a view controller; a view might’ve been enough. */
class GPSInfoViewController : UIViewController {
	
	/**
	 Technically should not be a part of the GPS info view controller, but our UI is made like so,
	  and I don’t have a better name for the controller. */
	struct RecordingModel {
		
		var maxSpeed: CLLocationSpeed
		var avgSpeed: CLLocationSpeed?
		
	}
	
	@IBOutlet var labelLat: UILabel!
	@IBOutlet var labelLong: UILabel!
	@IBOutlet var labelSpeed: UILabel!
	@IBOutlet var labelAverageSpeed: UILabel!
	@IBOutlet var labelMaxSpeed: UILabel!
	@IBOutlet var labelHorizontalAccuracy: UILabel!
	@IBOutlet var labelAltitude: UILabel!
	@IBOutlet var labelVerticalAccuracy: UILabel!
	
	@IBOutlet var labelKmph: UILabel!
	@IBOutlet var imageNorth: UIImageView!
	
	var useMetricSystem = true {
		didSet {
			updateUnitLabels()
			updateLocationUI()
			updateRecordingUI()
		}
	}
	
	/**
	 We didn’t go as far as wrapping the location property in a LocationModel struct…
	 but maybe, for the beauty of the model, we shoud have? */
	var locationModel: CLLocation? {
		didSet {
			updateLocationUI()
		}
	}
	
	/** Same note as for the location model. */
	var headingModel: CLLocationDegrees? {
		didSet {
			updateHeadingUI()
		}
	}
	
	var recordingModel: RecordingModel? {
		didSet {
			updateRecordingUI()
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		imageNorth.alpha = 0
		
		updateUnitLabels()
		updateLocationUI()
		updateRecordingUI()
		updateHeadingUI(animate: false)
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let c = S.sp.constants
	
	private var labelColor: UIColor {
		guard #available(iOS 13.0, *) else {
			return .black
		}
		return .label
	}
	
	private func updateUnitLabels() {
		assert(Thread.isMainThread)
		guard isViewLoaded else {return}
		
		labelKmph.text = Utils.speedSymbol(usingMetricSystem: useMetricSystem)
	}
	
	private func updateLocationUI() {
		assert(Thread.isMainThread)
		guard isViewLoaded else {return}
		guard let location = locationModel else {return}
		
		labelLat.text  = Utils.stringFrom(latitudeDegrees:  location.coordinate.latitude)
		labelLong.text = Utils.stringFrom(longitudeDegrees: location.coordinate.longitude)
		labelHorizontalAccuracy.text = Utils.stringFrom(distance: location.horizontalAccuracy, useMetricSystem: useMetricSystem)
		labelHorizontalAccuracy.textColor = (location.horizontalAccuracy > c.accuracyWarningThreshold ? .red : labelColor)
		
		if location.verticalAccuracy.sign == .plus {
			let numberFormatter = NumberFormatter()
			numberFormatter.numberStyle = .percent
			labelAltitude.text = Utils.stringFrom(altitude: location.altitude, useMetricSystem: useMetricSystem)
			labelVerticalAccuracy.text = abs(location.altitude) < 0.001 ? "" : NSLocalizedString("more or less #n percent#", comment: "")
				.applyingCommonTokens(number: XibLocNumber(location.verticalAccuracy/abs(location.altitude), formatter: numberFormatter))
		} else {
			labelAltitude.text = NSLocalizedString("nd", comment: "")
			labelVerticalAccuracy.text = ""
		}
		
		let speed = (location.speed.sign == .plus ? location.speed : 0)
		labelSpeed.text = Utils.stringFrom(speedValue: speed, useMetricSystem: useMetricSystem)
	}
	
	private func updateHeadingUI(animate: Bool = true) {
		assert(Thread.isMainThread)
		guard isViewLoaded else {return}
		guard let heading = headingModel else {return}
		
		let block: () -> Void
		if heading.sign == .plus {
			block = {
				self.imageNorth.alpha = 1
				self.imageNorth.transform = CGAffineTransform(rotationAngle: -2 * CGFloat.pi * CGFloat(heading/360))
			}
		} else {
			block = {
				self.imageNorth.alpha = 0
			}
		}
		
		if animate {UIView.animate(withDuration: c.animTime, animations: block)}
		else       {block()}
	}
	
	private func updateRecordingUI() {
		assert(Thread.isMainThread)
		guard isViewLoaded else {return}
		guard let recordingModel = recordingModel else {
			labelMaxSpeed.text     = NSLocalizedString("nd", comment: "")
			labelAverageSpeed.text = NSLocalizedString("nd", comment: "")
			return
		}
		
		labelMaxSpeed.text = Utils.stringFrom(speedValue: CLLocationSpeed(recordingModel.maxSpeed), useMetricSystem: useMetricSystem)
		if let s = recordingModel.avgSpeed {
			labelAverageSpeed.text = Utils.stringFrom(speedValue: s, useMetricSystem: useMetricSystem)
		} else {
			labelAverageSpeed.text = NSLocalizedString("nd", comment: "")
		}
	}
	
}
