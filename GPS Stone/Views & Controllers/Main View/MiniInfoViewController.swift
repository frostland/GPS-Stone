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



protocol MiniInfoViewControllerDelegate : AnyObject {
	
	func showDetailedInfo()
	
}


class MiniInfoViewController : UIViewController {
	
	@IBOutlet var labelTotalDistance: UILabel!
	@IBOutlet var labelElapsedTime: UILabel!
	@IBOutlet var labelGPSWarning: UILabel!
	
	weak var delegate: MiniInfoViewControllerDelegate?
	
	struct Model {
		
		var isPaused: Bool
		
		var duration: TimeInterval
		var dateStartDurationDelta: Date?
		
		var totalDistance: CLLocationDistance
		
		init(recording: Recording) {
			isPaused = recording.latestPauseInTime()?.isOpen ?? false
			
			duration = recording.activeRecordingDuration
			dateStartDurationDelta = isPaused ? nil : Date()
			
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
						timerUpdateDuration = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { [weak self] _ in self?.updateDurationLabel() })
					} else {
						timerUpdateDuration = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(MiniInfoViewController.objc_updateDurationLabel(_:)), userInfo: nil, repeats: true)
					}
				}
			} else {
				timerUpdateDuration?.invalidate()
				timerUpdateDuration = nil
			}
		}
	}
	
	var currentLocationError: GPSStoneLocationError? {
		didSet {
			updateUI()
		}
	}
	
	deinit {
		timerUpdateDuration?.invalidate()
		timerUpdateDuration = nil
	}
	
	@IBAction func viewTapped(_ sender: Any) {
		delegate?.showDetailedInfo()
	}
	
	func updateUI() {
		assert(Thread.isMainThread)
		guard isViewLoaded else {return}
		guard let model = model else {return}
		
		labelTotalDistance.text = Utils.stringFrom(distance: model.totalDistance, useMetricSystem: useMetricSystem)
		
		let color: UIColor
		if model.isPaused {
			if #available(iOS 11.0, *) {color = UIColor(named: "LabelMiniInfoPausedRecording")!}
			else                       {color = #colorLiteral(red: 0.6899999976, green: 0.6899999976, blue: 0.6899999976, alpha: 1)}
		} else {
			color = UIColor.white
		}
		labelElapsedTime.textColor = color
		labelTotalDistance.textColor = color
		
		if let e = currentLocationError {
			labelGPSWarning.text = e.isLocationNotFoundYet ?
				NSLocalizedString("location not found error msg in mini info view", comment: "The “location not found” error message in the mini info view. Should be “…”.") :
				NSLocalizedString("location error msg in mini info view", comment: "The “location error” error message in the mini info view. Should be “⚠️”.")
			
			if labelGPSWarning.alpha < 0.5 {
				UIView.animate(withDuration: c.animTime, animations: {
					self.labelGPSWarning.alpha = 1
				})
			}
		} else {
			if labelGPSWarning.alpha > 0.5 {
				UIView.animate(withDuration: c.animTime, animations: {
					self.labelGPSWarning.alpha = 0
				})
			}
		}
	}
	
	func updateDurationLabel() {
		assert(Thread.isMainThread)
		guard isViewLoaded else {return}
		
		let duration = (model?.duration ?? 0) - (model?.dateStartDurationDelta?.timeIntervalSinceNow ?? 0)
		labelElapsedTime.text = Utils.stringFrom(timeInterval: duration)
	}
	
	private let c = S.sp.constants
	
	private var timerUpdateDuration: Timer?
	
	@objc
	private func objc_updateDurationLabel(_ timer: Timer) {
		updateDurationLabel()
	}
	
}
