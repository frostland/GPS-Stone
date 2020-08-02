/*
 * RecordingInfoViewController.swift
 * GPS Stone
 *
 * Created by François Lamboley on 2020/7/29.
 * Copyright © 2020 Frost Land. All rights reserved.
 */

import CoreLocation
import Foundation
import UIKit

import XibLoc



class RecordingInfoViewController : UIViewController {
	
	@IBOutlet var labelNumberOfPoints: UILabel!
	@IBOutlet var labelTotalDistance: UILabel!
	@IBOutlet var labelElapsedTime: UILabel!
	@IBOutlet var labelTrackName: UILabel!
	
	struct Model {
		
		var name: String
		
		var startSate: Date
		
		var numberOfRecordedPoints: Int
		var totalDistance: CLLocationDistance
		
		init(recording: Recording) {
			name = recording.name ?? ""
			
			/* If the recording is invalid (does not have a start date), let’s not
			 * crash but we show an incorrect duration for the recording… */
			startSate = recording.totalTimeSegment?.startDate ?? Date()
			
			numberOfRecordedPoints = recording.numberOfRecordedPoints
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
			if model != nil {
				if timerUpdateDuration == nil {
					if #available(iOS 10.0, *) {
						timerUpdateDuration = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true, block: { [weak self] _ in self?.updateDurationLabel() })
					} else {
						timerUpdateDuration = Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: #selector(RecordingInfoViewController.objc_updateDurationLabel(_:)), userInfo: nil, repeats: true)
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
		
		labelTrackName.text = model.name
		labelTotalDistance.text = Utils.stringFrom(distance: model.totalDistance, useMetricSystem: useMetricSystem)
		labelNumberOfPoints.text = XibLocNumber(model.numberOfRecordedPoints).localizedString
	}
	
	func updateDurationLabel() {
		let duration = -(model?.startSate.timeIntervalSinceNow ?? 0)
		labelElapsedTime.text = Utils.stringFrom(timeInterval: duration)
	}
	
	private var timerUpdateDuration: Timer?
	
	@objc
	private func objc_updateDurationLabel(_ timer: Timer) {
		updateDurationLabel()
	}
	
}
