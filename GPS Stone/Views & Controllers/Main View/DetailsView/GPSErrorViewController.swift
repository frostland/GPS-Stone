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
	
	var error: Error? {
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
	
	private func updateUI() {
		let reasonText: String
		let isDeniedError: Bool
		if let error = error as NSError? {
			switch (error.domain, CLError.Code(rawValue: error.code)) {
			case (kCLErrorDomain, .denied): isDeniedError = true;  reasonText = NSLocalizedString("error getting location: denied", comment: "The message shown to the user when no GPS info because the permission was denied.")
			default:                        isDeniedError = false; reasonText = NSLocalizedString("unknown error getting location", comment: "The message shown to the user when no GPS info because of an unknown error.").applyingCommonTokens(simpleReplacement1: error.localizedDescription)
			}
		} else {
			isDeniedError = false
			reasonText = NSLocalizedString("getting loc", comment: "The message shown to the user when no GPS info are available yet, but there are no errors getting the user’s position.")
		}
		
		labelWarning.isHidden = (error == nil)
		labelReason.text = reasonText
		
		buttonGoToSettings.isHidden = !isDeniedError
	}
	
}
