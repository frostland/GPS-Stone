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
					timerUpdateDuration = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { [weak self] _ in self?.updateDurationLabel() })
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
		if model.isPaused {color = UIColor(resource: .labelMiniInfoPausedRecording)}
		else              {color = UIColor.white}
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
	
}
