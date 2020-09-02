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
	@IBOutlet var labelGPSStatus: UILabel!

	struct Model {
		
		var startSate: Date
		var totalDistance: CLLocationDistance
		
		init(recording: Recording) {
			/* If the recording is invalid (does not have a start date), let’s not
			 * crash but we show an incorrect duration for the recording… */
			startSate = recording.totalTimeSegment?.startDate ?? Date()
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
		
		let duration = -(model?.startSate.timeIntervalSinceNow ?? 0)
		labelElapsedTime.text = Utils.stringFrom(timeInterval: duration)
	}
	
	private var timerUpdateDuration: Timer?
	
	@objc
	private func objc_updateDurationLabel(_ timer: Timer) {
		updateDurationLabel()
	}
	
}
