/*
 * MiniInfoViewController.swift
 * GPS Stone
 *
 * Created by François Lamboley on 02/09/2020.
 * Copyright © 2020 Frost Land. All rights reserved.
 */

import CoreLocation
import Foundation
import UIKit

import XibLoc



class MiniInfoViewController : UIViewController {
	
	@IBOutlet var labelTotalDistance: UILabel!
	@IBOutlet var labelElapsedTime: UILabel!
	#warning("TODO?")
	@IBOutlet var labelGPSStatus: UILabel!

	struct Model {
		
		var duration: TimeInterval
		var dateStartDurationDelta: Date?
		
		var totalDistance: CLLocationDistance
		
		init(recording: Recording) {
			duration = recording.activeRecordingDuration
			if let p = recording.latestPauseInTime(), p.isOpen {dateStartDurationDelta = nil}
			else                                               {dateStartDurationDelta = Date()}
			
			totalDistance = CLLocationDistance(recording.totalDistance)
		}
		
	}
	
	var useMetricSystem = true {
		didSet {
			updateUI()
		}
	}
	
	var model: Model? {
		didSet {
			updateUI()
			updateDurationLabel()
			if model != nil {
				if timerUpdateDuration == nil {
					if #available(iOS 10.0, *) {
						timerUpdateDuration = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true, block: { [weak self] _ in self?.updateDurationLabel() })
					} else {
						timerUpdateDuration = Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: #selector(MiniInfoViewController.objc_updateDurationLabel(_:)), userInfo: nil, repeats: true)
					}
				}
			} else {
				timerUpdateDuration?.invalidate()
				timerUpdateDuration = nil
			}
		}
	}
	
	deinit {
		timerUpdateDuration?.invalidate()
		timerUpdateDuration = nil
	}
	
	func updateUI() {
		assert(Thread.isMainThread)
		guard isViewLoaded else {return}
		guard let model = model else {return}
		
		labelTotalDistance.text = Utils.stringFrom(distance: model.totalDistance, useMetricSystem: useMetricSystem)
	}
	
	func updateDurationLabel() {
		assert(Thread.isMainThread)
		guard isViewLoaded else {return}
		
		let duration = (model?.duration ?? 0) - (model?.dateStartDurationDelta?.timeIntervalSinceNow ?? 0)
		labelElapsedTime.text = Utils.stringFrom(timeInterval: duration)
	}
	
	private var timerUpdateDuration: Timer?
	
	@objc
	private func objc_updateDurationLabel(_ timer: Timer) {
		updateDurationLabel()
	}
	
}
