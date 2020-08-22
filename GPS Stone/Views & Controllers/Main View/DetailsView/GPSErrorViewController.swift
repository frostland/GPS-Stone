/*
 * GPSErrorViewController.swift
 * GPS Stone
 *
 * Created by François Lamboley on 2020/8/1.
 * Copyright © 2020 Frost Land. All rights reserved.
 */

import CoreLocation
import Foundation
import UIKit



class GPSErrorViewController : UIViewController {
	
	@IBOutlet var labelWarning: UILabel!
	@IBOutlet var labelReason: UILabel!
	
	@IBOutlet var buttonGoToSettings: UIButton!
	@IBOutlet var buttonResumeLocationUpdates: UIButton!
	
	@IBOutlet var constraintDescrToBottomView: NSLayoutConstraint!
	@IBOutlet var constraintButtonToBottomView: NSLayoutConstraint!
	
	var error = GPSStoneLocationError.locationNotFoundYet {
		didSet {
			assert(Thread.isMainThread)
			updateUI()
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		updateUI()
	}
	
	@IBAction func goToSettings(_ sender: Any) {
		guard let url = URL(string: UIApplication.openSettingsURLString) else {
			NSLog("%@", "Weird, the open settings URL string cannot be converted to a URL……… \(UIApplication.openSettingsURLString)")
			return
		}
		UIApplication.shared.openURL(url)
	}
	
	@IBAction func resumeLocationUpdates(_ sender: Any) {
		locationRecorder.resumeLocationTracking()
	}
	
	private let locationRecorder = S.sp.locationRecorder
	
	private func updateUI() {
		labelReason.text = error.localizedDescription
		
		labelWarning.isHidden = error.isLocationNotFoundYet
		buttonGoToSettings.isHidden = !error.isPermissionDeniedError
		buttonResumeLocationUpdates.isHidden = !error.isUpdatesPaused
		
		/* Layout Note: We use an if instead of directly setting the `isActive`
		 * property with the boolean value used in the if, because **the order in
		 * which we (de-)activate the constraints matters**! */
		if error.isPermissionDeniedError || error.isUpdatesPaused {
			constraintDescrToBottomView.isActive = false
			constraintButtonToBottomView.isActive = true
		} else {
			constraintButtonToBottomView.isActive = false
			constraintDescrToBottomView.isActive = true
		}
	}
	
}
