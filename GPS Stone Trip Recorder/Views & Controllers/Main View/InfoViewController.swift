/*
 * InfoViewController.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 18/06/2019.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import Foundation
import UIKit



class InfoViewController : UIViewController {
	
	@IBOutlet var constraintMarginTopTitle: NSLayoutConstraint!
	@IBOutlet var buttonRecord: UIButton!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		if isDeviceScreenTallerThanOriginalIPhone() {
			constraintMarginTopTitle.constant = 25
		}
	}
	
	@IBAction func showDetailedInfos(_ sender: Any) {
	}
	
	@IBAction func showPositionOnMap(_ sender: Any) {
	}
	
	@IBAction func startRecording(_ sender: Any) {
	}
	
}
